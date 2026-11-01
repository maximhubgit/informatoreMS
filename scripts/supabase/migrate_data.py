"""Copia i dati da Firebase Firestore alle tabelle Supabase.

Uso:
    cd scripts/supabase
    python migrate_data.py            # svuota le tabelle e reinserisce
    python migrate_data.py --dry-run  # legge Firebase e mostra solo i conteggi

Prerequisiti:
    - avere eseguito create_tables.py
    - scripts/supabase/.env con SUPABASE_DB_URL
    - scripts/serviceAccountKey.json (oppure FIREBASE_CREDENTIAL_PATH nel .env)

L'intera operazione (wipe + insert + verifica) avviene in un'unica
transazione: se un controllo fallisce, nessuna modifica viene confermata.
"""
from __future__ import annotations

import argparse
from datetime import date, datetime
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore

from config import (
    BASE_DIR,
    FIREBASE_CREDENTIAL_PATH,
    FIREBASE_PROJECT_ID,
    SUPABASE_DB_URL,
    describe_db_url,
    get_connection,
)

# ---------------------------------------------------------------------------
# Schema atteso: ordine di importazione e colonne delle tabelle
# ---------------------------------------------------------------------------

ORDER = [
    "asl",
    "distretti",
    "zone",
    "specializzazioni",
    "aree",
    "medici",
    "fasceOrarie",
    "calendario_appuntamenti",
    "appuntamenti",
    "storico_appuntamenti",
]

COLUMNS = {
    "asl": ["codice", "descrizione"],
    "distretti": ["codice", "nrDistretto", "descrizione", "codiceAsl"],
    "zone": ["id", "nome", "coloreHex"],
    "specializzazioni": ["id", "nome", "icona"],
    "aree": ["id", "Area"],
    "medici": [
        "id",
        "nome",
        "specializzazioneId",
        "periodicitaGiorni",
        "calendarioAppuntamentoId",
        "annotazioni",
        "telefono",
        "prodotti",
    ],
    "fasceOrarie": [
        "id",
        "idMedico",
        "nr",
        "minutiInizio",
        "minutiFine",
        "slotDisponibili",
        "giorniSettimana",
        "distrettoId",
        "zonaId",
        "struttura",
        "indirizzo",
        "tempoVisitaMinuti",
        "deleted",
        "isFittizia",
        "idArea",
    ],
    "calendario_appuntamenti": [
        "id",
        "medicoId",
        "data",
        "note",
        "stato",
        "dataCreazione",
        "fasciaNumero",
        "fasciaOrariaId",
    ],
    "appuntamenti": [
        "id",
        "medicoId",
        "dataOraInizio",
        "dataOraFine",
        "stato",
        "note",
    ],
    "storico_appuntamenti": [
        "id",
        "medicoId",
        "appuntamentoId",
        "dataEseguita",
        "stato",
        "timestamp",
    ],
}

VALID_STATI_CALENDARIO = {
    "proposto",
    "confermato",
    "concordato",
    "fatto",
    "annullato",
}


# ---------------------------------------------------------------------------
# Conversioni difensive
# ---------------------------------------------------------------------------

def as_text(value, default=None):
    if value is None:
        return default
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return str(value)


def as_int(value, default=None):
    if value is None or value == "":
        return default
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return default


def as_bool(value, default=False):
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"true", "1", "si", "sì", "yes"}
    return bool(value)


def as_str_list(value):
    if value is None:
        return None
    if isinstance(value, (list, tuple)):
        return [str(item) for item in value]
    return None


# ---------------------------------------------------------------------------
# Normalizzazione documento Firestore -> riga Postgres
# ---------------------------------------------------------------------------

def normalize(table: str, doc_id: str, data: dict, ctx: dict):
    """Restituisce un dict con esattamente le colonne di COLUMNS[table].

    None significa "riga non importabile" (viene saltata e segnalata).
    """
    if table == "asl":
        codice = as_int(data.get("codice"), as_int(doc_id))
        if codice is None:
            return None
        return {
            "codice": codice,
            "descrizione": as_text(data.get("descrizione"), "") or "",
        }

    if table == "distretti":
        codice = as_int(data.get("codice"), as_int(doc_id))
        if codice is None:
            return None
        return {
            "codice": codice,
            "nrDistretto": as_int(data.get("nrDistretto"), codice),
            "descrizione": as_text(data.get("descrizione"), "") or "",
            "codiceAsl": as_int(data.get("codiceAsl"), 0),
        }

    if table == "zone":
        return {
            "id": doc_id,
            "nome": as_text(data.get("nome"), "") or "",
            "coloreHex": as_text(data.get("coloreHex"), "#4ECDC4") or "#4ECDC4",
        }

    if table == "specializzazioni":
        return {
            "id": doc_id,
            "nome": as_text(data.get("nome"), "") or "",
            "icona": as_text(data.get("icona")),
        }

    if table == "aree":
        nome = as_text(data.get("Area")) or as_text(data.get("nome")) or ""
        return {"id": doc_id, "Area": nome}

    if table == "medici":
        # Compatibilità con i vecchi documenti che avevano il nome della
        # specializzazione invece della sua chiave.
        spec_id = as_text(data.get("specializzazioneId"))
        if not spec_id and data.get("specializzazione"):
            spec_id = ctx["spec_by_name"].get(str(data["specializzazione"]))
        return {
            "id": doc_id,
            "nome": as_text(data.get("nome"), "") or "",
            "specializzazioneId": spec_id,
            "periodicitaGiorni": as_int(data.get("periodicitaGiorni"), 30),
            "calendarioAppuntamentoId": as_text(
                data.get("calendarioAppuntamentoId")
            ),
            "annotazioni": as_text(data.get("annotazioni")),
            "telefono": as_text(data.get("telefono")),
            "prodotti": as_text(data.get("prodotti")),
        }

    if table == "fasceOrarie":
        distretto_id = data.get("distrettoId")
        if distretto_id is None:
            distretto_id = data.get("idDistretto", 1)
        return {
            "id": doc_id,
            "idMedico": as_text(data.get("idMedico"), "") or "",
            "nr": as_int(data.get("nr"), 0),
            "minutiInizio": as_int(data.get("minutiInizio"), 0),
            "minutiFine": as_int(data.get("minutiFine"), 0),
            "slotDisponibili": as_int(data.get("slotDisponibili"), 1),
            "giorniSettimana": as_str_list(data.get("giorniSettimana")),
            "distrettoId": as_int(distretto_id, 1),
            "zonaId": (
                as_text(data.get("zonaId"))
                or as_text(data.get("zonaIdEsteso"))
                or ""
            ),
            "struttura": as_text(data.get("struttura"))
            or as_text(data.get("strutturaEstesa")),
            "indirizzo": as_text(data.get("indirizzo"))
            or as_text(data.get("indirizzoEsteso")),
            "tempoVisitaMinuti": as_int(data.get("tempoVisitaMinuti")),
            "deleted": as_bool(data.get("deleted"), False),
            "isFittizia": as_bool(data.get("isFittizia"), False),
            "idArea": as_text(data.get("idArea")),
        }

    if table == "calendario_appuntamenti":
        data_value = data.get("data")
        if data_value is None:
            return None
        stato = as_text(data.get("stato"), "proposto") or "proposto"
        if stato not in VALID_STATI_CALENDARIO:
            print(
                f"  ATTENZIONE: stato non riconosciuto '{stato}' "
                f"nel calendario '{doc_id}' (valore copiato così com'è)"
            )
        return {
            "id": doc_id,
            "medicoId": as_text(data.get("medicoId")),
            "data": as_text(data_value),
            "note": as_text(data.get("note")),
            "stato": stato,
            "dataCreazione": as_text(data.get("dataCreazione")),
            "fasciaNumero": as_int(data.get("fasciaNumero")),
            "fasciaOrariaId": as_text(data.get("fasciaOrariaId")),
        }

    if table == "appuntamenti":
        return {
            "id": doc_id,
            "medicoId": as_text(data.get("medicoId")),
            "dataOraInizio": as_text(data.get("dataOraInizio")),
            "dataOraFine": as_text(data.get("dataOraFine")),
            "stato": as_text(data.get("stato")),
            "note": as_text(data.get("note")),
        }

    if table == "storico_appuntamenti":
        return {
            "id": doc_id,
            "medicoId": as_text(data.get("medicoId")),
            "appuntamentoId": as_text(data.get("appuntamentoId")),
            "dataEseguita": as_text(data.get("dataEseguita")),
            "stato": as_text(data.get("stato")),
            "timestamp": as_text(data.get("timestamp")),
        }

    raise ValueError(f"Tabella non gestita: {table}")


# ---------------------------------------------------------------------------
# Firebase
# ---------------------------------------------------------------------------

def get_firestore():
    cred_path = Path(FIREBASE_CREDENTIAL_PATH).expanduser()
    if not cred_path.is_absolute():
        cred_path = (BASE_DIR / cred_path).resolve()

    if not cred_path.exists():
        raise SystemExit(f"Credenziale Firebase non trovata: {cred_path}")

    if not firebase_admin._apps:
        cred = credentials.Certificate(str(cred_path))
        firebase_admin.initialize_app(cred, {"projectId": FIREBASE_PROJECT_ID})

    print(f"Firebase: progetto {FIREBASE_PROJECT_ID} ({cred_path.name})")
    return firestore.client()


def read_collections(db):
    docs_by_table: dict[str, list[tuple[str, dict]]] = {}
    spec_by_name: dict[str, str] = {}

    for table in ORDER:
        rows: list[tuple[str, dict]] = []
        for doc in db.collection(table).stream():
            rows.append((doc.id, doc.to_dict() or {}))
        docs_by_table[table] = rows

        if table == "specializzazioni":
            spec_by_name = {
                str(data.get("nome")): doc_id
                for doc_id, data in rows
                if data.get("nome")
            }

        print(f"  {table}: {len(rows)} documenti")

    return docs_by_table, spec_by_name


def dedupe(table: str, rows: list[dict]):
    """Evita violazioni di primary key mantenendo l'ultima occorrenza."""
    pk = "codice" if table in {"asl", "distretti"} else "id"
    unique: dict = {}
    duplicates = 0
    for row in rows:
        if row[pk] in unique:
            duplicates += 1
        unique[row[pk]] = row
    return list(unique.values()), duplicates


# ---------------------------------------------------------------------------
# Postgres
# ---------------------------------------------------------------------------

def quote_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def wipe_tables(conn) -> None:
    tables = ", ".join(f"public.{quote_ident(table)}" for table in ORDER)
    conn.execute(f"truncate table {tables} cascade")


def insert_rows(conn, table: str, rows: list[dict]) -> None:
    if not rows:
        return
    columns = COLUMNS[table]
    column_sql = ", ".join(quote_ident(column) for column in columns)
    placeholders = ", ".join(["%s"] * len(columns))
    sql = (
        f"insert into public.{quote_ident(table)} "
        f"({column_sql}) values ({placeholders})"
    )
    values = [tuple(row[column] for column in columns) for row in rows]
    with conn.cursor() as cursor:
        cursor.executemany(sql, values)


def count_rows(conn, table: str) -> int:
    cursor = conn.execute(
        f"select count(*) from public.{quote_ident(table)}"
    )
    return cursor.fetchone()[0]


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Copia i dati da Firestore a Supabase (wipe + reinserimento)."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="legge Firebase e mostra i conteggi senza toccare Supabase",
    )
    args = parser.parse_args()

    print("Lettura dati da Firebase Firestore...")
    db = get_firestore()
    docs_by_table, spec_by_name = read_collections(db)

    ctx = {"spec_by_name": spec_by_name}
    normalized: dict[str, list[dict]] = {}
    skipped: dict[str, list[str]] = {}

    print("\nNormalizzazione...")
    for table in ORDER:
        rows: list[dict] = []
        skipped_rows: list[str] = []
        for doc_id, data in docs_by_table[table]:
            row = normalize(table, doc_id, data, ctx)
            if row is None:
                skipped_rows.append(doc_id)
            else:
                rows.append(row)

        rows, duplicates = dedupe(table, rows)
        normalized[table] = rows
        skipped[table] = skipped_rows

        message = f"  {table}: {len(rows)} righe pronte"
        if skipped_rows:
            message += f", {len(skipped_rows)} saltate"
        if duplicates:
            message += f", {duplicates} duplicati ignorati"
        print(message)

    if args.dry_run:
        print("\n--dry-run: nessuna modifica applicata a Supabase.")
        return

    print(f"\nConnessione a Supabase ({describe_db_url(SUPABASE_DB_URL)})...")
    with get_connection() as conn:
        print("Svuotamento tabelle (wipe + cascade)...")
        wipe_tables(conn)

        print("Inserimento dati...")
        for table in ORDER:
            insert_rows(conn, table, normalized[table])
            print(f"  {table}: {len(normalized[table])} righe inserite")

        print("\nVerifica conteggi...")
        mismatches = []
        for table in ORDER:
            expected = len(normalized[table])
            actual = count_rows(conn, table)
            status = "OK" if expected == actual else "MISMATCH"
            print(f"  {table}: attese {expected}, trovate {actual} [{status}]")
            if expected != actual:
                mismatches.append((table, expected, actual))

        if mismatches:
            raise RuntimeError(
                "Verifica fallita, transazione annullata: "
                + ", ".join(
                    f"{table} ({expected}!={actual})"
                    for table, expected, actual in mismatches
                )
            )

    print("\nMigrazione completata e confermata.")


if __name__ == "__main__":
    main()
