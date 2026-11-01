"""Crea/aggiorna lo schema Supabase (Postgres) per informatoreMS.

Uso:
    cd scripts/supabase
    python create_tables.py

Legge la connection string da scripts/supabase/.env (SUPABASE_DB_URL).
Lo script è idempotente: usa `create table if not exists`, `create index
if not exists` e ricrea le policy RLS.

Nota: i nomi delle colonne sono identici ai campi Firestore (camelCase,
incluso "Area" maiuscolo), quindi vanno sempre quotati tra doppi apici.
"""
from __future__ import annotations

from config import SUPABASE_DB_URL, describe_db_url, get_connection

# ---------------------------------------------------------------------------
# DDL
# ---------------------------------------------------------------------------

CREATE_STATEMENTS = [
    # ---------------- Anagrafica ----------------
    """
    create table if not exists public.asl (
      "codice"      integer primary key,
      "descrizione" text not null
    )
    """,
    """
    create table if not exists public.distretti (
      "codice"      integer primary key,
      "nrDistretto" integer not null,
      "descrizione" text not null,
      "codiceAsl"   integer not null
    )
    """,
    """
    create table if not exists public.zone (
      "id"        text primary key,
      "nome"      text not null,
      "coloreHex" text not null default '#4ECDC4'
    )
    """,
    """
    create table if not exists public.specializzazioni (
      "id"    text primary key,
      "nome"  text not null,
      "icona" text
    )
    """,
    """
    create table if not exists public.aree (
      "id"   text primary key,
      "Area" text not null
    )
    """,
    """
    create table if not exists public.medici (
      "id"                        text primary key,
      "nome"                      text not null,
      "specializzazioneId"        text,
      "periodicitaGiorni"         integer not null default 30,
      "calendarioAppuntamentoId"  text,
      "annotazioni"               text,
      "telefono"                  text,
      "prodotti"                  text
    )
    """,
    # ---------------- Fasce orarie ----------------
    """
    create table if not exists public."fasceOrarie" (
      "id"                text primary key,
      "idMedico"          text not null,
      "nr"                integer not null default 0,
      "minutiInizio"      integer not null default 0,
      "minutiFine"        integer not null default 0,
      "slotDisponibili"   integer not null default 1,
      "giorniSettimana"   text[],
      "distrettoId"       integer,
      "zonaId"            text,
      "struttura"         text,
      "indirizzo"         text,
      "tempoVisitaMinuti" integer,
      "deleted"           boolean not null default false,
      "isFittizia"        boolean not null default false,
      "idArea"            text
    )
    """,
    """
    create index if not exists idx_fasce_idmedico
      on public."fasceOrarie" ("idMedico")
    """,
    """
    create index if not exists idx_fasce_deleted
      on public."fasceOrarie" ("deleted")
    """,
    # ---------------- Appuntamenti ----------------
    """
    create table if not exists public.calendario_appuntamenti (
      "id"              text primary key,
      "medicoId"        text,
      "data"            text not null,
      "note"            text,
      "stato"           text not null default 'proposto',
      "dataCreazione"   text,
      "fasciaNumero"    integer,
      "fasciaOrariaId"  text
    )
    """,
    """
    create index if not exists idx_calendario_medico
      on public.calendario_appuntamenti ("medicoId")
    """,
    """
    create table if not exists public.appuntamenti (
      "id"            text primary key,
      "medicoId"      text,
      "dataOraInizio" text,
      "dataOraFine"   text,
      "stato"         text,
      "note"          text
    )
    """,
    """
    create table if not exists public.storico_appuntamenti (
      "id"             text primary key,
      "medicoId"       text,
      "appuntamentoId" text,
      "dataEseguita"   text,
      "stato"          text,
      "timestamp"      text
    )
    """,
]

TABLE_NAMES = [
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


def quote_ident(name: str) -> str:
    """Quota un identificatore Postgres mantenendo maiuscole/minuscole."""
    return '"' + name.replace('"', '""') + '"'


def rls_statements() -> list[str]:
    statements: list[str] = []
    for table in TABLE_NAMES:
        target = f"public.{quote_ident(table)}"
        statements.append(f"alter table {target} enable row level security")
        statements.append(
            f'drop policy if exists "authenticated_all" on {target}'
        )
        statements.append(
            f'create policy "authenticated_all" on {target} '
            "for all to authenticated using (true) with check (true)"
        )
    return statements


GRANT_STATEMENTS = [
    "grant usage on schema public to anon, authenticated, service_role",
    "grant all on all tables in schema public to authenticated, service_role",
    "grant all on all sequences in schema public to authenticated, service_role",
]

# PostgREST memorizza in cache lo schema: forziamo il reload dopo il DDL.
RELOAD_SCHEMA = "notify pgrst, 'reload schema'"


def main() -> None:
    statements = CREATE_STATEMENTS + rls_statements() + GRANT_STATEMENTS

    print("Connessione a Supabase...")
    with get_connection() as conn:
        print(f"Connesso a {describe_db_url(SUPABASE_DB_URL)}")

        for statement in statements:
            conn.execute(statement)

        conn.execute(RELOAD_SCHEMA)

    print("Schema creato/aggiornato correttamente.")
    print("Tabelle:", ", ".join(TABLE_NAMES))
    print("RLS: policy 'authenticated_all' applicata a tutte le tabelle.")


if __name__ == "__main__":
    main()
