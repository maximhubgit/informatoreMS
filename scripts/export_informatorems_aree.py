"""Script per esportare le aree da export_informatorems_aree.xlsx e aggiornare la tabella fasceOrarie in Firebase Firestore.

Workflow:
1. Legge il file Excel export_informatorems_aree.xlsx.
2. Estrae da ogni riga:
   - idArea  (colonna U, codArea)
   - Area    (colonna V, NomeArea)
3. Aggiorna la collection fasceOrarie in Firebase:
   - Ogni fascia e' identificata da idFascia (colonna A).
   - Viene aggiunto/aggiornato il campo idArea nella documenta Firestore.
"""
from __future__ import annotations

import os
import sys

import openpyxl
from firebase_admin import credentials
from firebase_admin import firestore


SERVICE_ACCOUNT_PATH = os.environ.get(
    "GOOGLE_APPLICATION_CREDENTIALS",
    "scripts/serviceAccountKey.json",
)
PROJECT_ID = "informatorems-784a1"

FASCIA_COLLECTION = "fasceOrarie"

# Mappatura colonna Excel (1-based) -> campo Firestore
# Colonna A (1) = IdFascia
# Colonne U (21) = codArea -> idArea
# Colonne V (22) = NomeArea -> Area
# Le altre colonne (2-20) corrispondono ai campi esistenti di fasceOrarie
EXCEL_FIELD_MAP = {
    1: "idFascia",
    3: "idMedico",
    4: "asl",
    5: "distretto",
    6: "nrDistretto",
    7: "medico",
    8: "specializzazione",
    9: "indirizzo",
    10: "struttura",
    11: "zona",
    12: "giorno",
    13: "orarioInizio",
    14: "orarioFine",
    15: "telefono",
    16: "prodotti",
    17: "annotazioni",
    18: "latitudine",
    19: "longitudine",
    20: "queryGeocoding",
    21: "codArea",
    22: "nomeArea",
    23: "ordinePercorso",
    24: "distKmCumulativa",
}


def load_workbook(path: str) -> openpyxl.Workbook:
    """Carica il workbook Excel restituendo l'istanza openpyxl."""
    return openpyxl.load_workbook(path, read_only=True)


def get_header_row(ws: openpyxl.worksheet.worksheet.Worksheet) -> list[str]:
    """Restituisce l'header della prima riga (riga 1, 1-based)."""
    return [cell.value for cell in ws[1]]


def get_fascia_id(ws: openpyxl.worksheet.Worksheet, row_idx: int) -> str | None:
    """Restituisce idFascia (colonna A, 1-based) della riga."""
    val = ws.cell(row=row_idx, column=1).value
    return str(val) if val is not None else None


def get_id_area(ws: openpyxl.worksheet.Worksheet, row_idx: int) -> str | None:
    """Restituisce idArea (colonna U, 1-based) della riga."""
    val = ws.cell(row=row_idx, column=21).value
    return str(val) if val is not None else None


def get_area(ws: openpyxl.worksheet.Worksheet, row_idx: int) -> str | None:
    """Restituisce Area (colonna V, 1-based) della riga."""
    val = ws.cell(row=row_idx, column=22).value
    return str(val) if val is not None else None


def main() -> int:
    """Funzione principale: carica l'Excel e aggiorna le fasceOrarie in Firebase."""
    excel_path = os.environ.get(
        "EXPORT_AREAS_EXCEL", "scripts/export_informatorems_aree.xlsx"
    )

    if not os.path.exists(excel_path):
        print(f"ERRORE: file non trovato: {excel_path}")
        return 1

    print(f"Lettura file Excel: {excel_path}")
    wb = load_workbook(excel_path)
    ws = wb["Dati"]

    headers = get_header_row(ws)
    print(f"\nHeader trovati ({len(headers)} colonne):")
    for h in headers:
        print(f"  {h}")

    # Colonna A = idFascia, colonna U = codArea (idArea), colonna V = NomeArea (Area)
    # I dati della riga sono 0-based, ws.cell(r, c) usa 1-based

    # Per prima cosa estrai i dati di tutte le righe
    rows_data = []
    for row_idx in range(2, ws.max_row + 1):
        fascia_id = get_fascia_id(ws, row_idx)
        id_area = get_id_area(ws, row_idx)
        area = get_area(ws, row_idx)

        if not fascia_id:
            continue

        rows_data.append({
            "idFascia": fascia_id,
            "idArea": id_area,
            "Area": area,
            "row": row_idx,
        })

    print(f"\nRighe trovate: {len(rows_data)}")

    # Filtra le righe con idArea non nullo
    rows_with_area = [r for r in rows_data if r["idArea"] is not None]
    print(f"Righe con idArea popolato: {len(rows_with_area)}")

    # Connettiti a Firebase
    print(f"\nConnessione a Firebase...")
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred, {"projectId": PROJECT_ID})
    except Exception as e:
        print(f"ERRORE durante l'inizializzazione Firebase: {e}")
        return 1

    db = firestore.client()

    # Per ogni fascia, aggiorna il documento in fasceOrarie
    print(f"\nAggiornamento fasceOrarie in Firebase...")
    aggiornati = 0
    non_trovati = 0

    for row in rows_with_area:
        fascia_id = row["idFascia"]
        id_area = row["idArea"]
        area = row["Area"]

        doc_ref = db.collection(FASCIA_COLLECTION).document(fascia_id)
        doc_snapshot = doc_ref.get()

        if not doc_snapshot.exists:
            print(f"  [WARNING] Fascia non trovata in Firebase: {fascia_id}")
            non_trovati += 1
            continue

        existing = doc_snapshot.to_dict()
        updated = {**existing, "idArea": id_area, "area": area}

        doc_ref.update(updated)
        aggiornati += 1

        if aggiornati % 20 == 0 or aggiornati == len(rows_with_area):
            print(f"  Aggiornato {aggiornati}/{len(rows_with_area)} fascie...")

    print(f"\nRisultati:")
    print(f"  Fasce aggiornate: {aggiornati}")
    print(f"  Non trovate: {non_trovati}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
