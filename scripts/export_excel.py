"""Entry point: esporta i dati Firebase in un file Excel long-format.

Una riga = una fascia oraria di un medico, in un giorno specifico.

Colonne prodotte:
- ASL | Distretto | NrDistretto | Medico | Specializzazione |
  Indirizzo | Struttura | Zona | Giorno | OrarioInizio | OrarioFine |
  Telefono | Prodotti | Annotazioni
"""
from __future__ import annotations

import os
import sys
from datetime import datetime

import openpyxl
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

from firebase_client import FirebaseClient


EXPORT_FILENAME_PREFIX = "export_informatorems_"
EXPORT_FILENAME_SUFFIX = ".xlsx"


HEADERS = [
    "ASL",
    "Distretto",
    "NrDistretto",
    "Medico",
    "Specializzazione",
    "Indirizzo",
    "Struttura",
    "Zona",
    "Giorno",
    "OrarioInizio",
    "OrarioFine",
    "Telefono",
    "Prodotti",
    "Annotazioni",
]

DAY_LABELS = {
    "lunedi": "Lunedì",
    "martedi": "Martedì",
    "mercoledi": "Mercoledì",
    "giovedi": "Giovedì",
    "venerdi": "Venerdì",
    "sabato": "Sabato",
    "domenica": "Domenica",
}


def minutes_to_hhmm(minutes: int) -> str:
    h = minutes // 60
    m = minutes % 60
    return f"{h:02d}:{m:02d}"


def main() -> int:
    print("=" * 70)
    print("ESPORTAZIONE FIREBASE → EXCEL")
    print("=" * 70)

    # 1) Inizializza Firebase
    print("\n[1/4] Inizializzazione Firebase...")
    try:
        client = FirebaseClient()
        _ = client.db
        print("      OK")
    except Exception as e:
        print(f"      ERRORE: {e}")
        return 1

    # 2) Carica tutte le collection
    print("\n[2/4] Caricamento dati...")
    asl_docs = client.get_all("asl")
    distretti_docs = client.get_all("distretti")
    zone_docs = client.get_all("zone")
    spec_docs = client.get_all("specializzazioni")
    medico_docs = client.get_all("medici")
    fasce_docs = client.get_all("fasceOrarie")

    print(f"      ASL: {len(asl_docs)}")
    print(f"      Distretti: {len(distretti_docs)}")
    print(f"      Zone: {len(zone_docs)}")
    print(f"      Specializzazioni: {len(spec_docs)}")
    print(f"      Medici: {len(medico_docs)}")
    print(f"      Fasce orarie: {len(fasce_docs)}")

    # 3) Costruisci lookup dict
    asl_by_codice = {a["codice"]: a["descrizione"] for a in asl_docs}
    distretti_by_codice = {
        d["codice"]: d for d in distretti_docs
    }
    zone_by_id = {z["_docId"]: z["nome"] for z in zone_docs}
    spec_by_id = {s["_docId"]: s["nome"] for s in spec_docs}

    # Raggruppa fasce per medico
    fasce_by_medico: dict[str, list[dict]] = {}
    for f in fasce_docs:
        if f.get("deleted"):
            continue
        mid = f.get("idMedico", "")
        fasce_by_medico.setdefault(mid, []).append(f)

    # 4) Scrivi Excel
    print("\n[3/4] Generazione Excel...")
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Esportazione"

    # Header con stile
    header_font = Font(bold=True, color="FFFFFF")
    header_fill = PatternFill("solid", fgColor="4472C4")
    header_align = Alignment(horizontal="center", vertical="center", wrap_text=True)

    for col_idx, header in enumerate(HEADERS, start=1):
        cell = ws.cell(row=1, column=col_idx, value=header)
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = header_align

    # Righe
    row_idx = 2
    for m in medico_docs:
        mid = m["_docId"]
        medico_nome = m.get("nome", "")
        spec_id = m.get("specializzazioneId", "")
        spec_nome = spec_by_id.get(spec_id, "")
        telefono = m.get("telefono", "") or ""
        prodotti = m.get("prodotti", "") or ""
        annotazioni = m.get("annotazioni", "") or ""

        fasce = fasce_by_medico.get(mid, [])
        # Ordina le fasce per nr
        fasce.sort(key=lambda f: f.get("nr", 0))

        if not fasce:
            # Medico senza fasce: scrivi comunque una riga con dati minimi
            ws.cell(row_idx, 4, medico_nome)
            ws.cell(row_idx, 5, spec_nome)
            ws.cell(row_idx, 12, telefono)
            ws.cell(row_idx, 13, prodotti)
            ws.cell(row_idx, 14, annotazioni)
            row_idx += 1
            # Riga vuota di separazione
            row_idx += 1
            continue

        for fascia in fasce:
            distretto_id = fascia.get("distrettoId")
            distretto = distretti_by_codice.get(distretto_id, {})
            asl_desc = ""
            nr_distretto = ""
            distretto_desc = ""
            if distretto:
                nr_distretto = distretto.get("nrDistretto", "")
                distretto_desc = distretto.get("descrizione", "")
                asl_codice = distretto.get("codiceAsl")
                asl_desc = asl_by_codice.get(asl_codice, "")

            zona_id = fascia.get("zonaId", "")
            zona_nome = zone_by_id.get(zona_id, "")

            giorni = fascia.get("giorniSettimana") or []
            # Se giorni e' vuoto o null, espandiamo in tutti i 7 giorni
            if not giorni:
                giorno_str = "Tutti i giorni"
            else:
                # Uniamo i giorni in un'unica cella separati da "-"
                # (es. "Lunedì-Martedì-Giovedì"). L'utente vuole che una
                # stessa fascia che si ripete su piu' giorni sia riportata
                # in un'unica riga.
                giorno_str = "-".join(DAY_LABELS.get(g, g) for g in giorni)

            min_inizio = fascia.get("minutiInizio", 0)
            min_fine = fascia.get("minutiFine", 0)

            ws.cell(row_idx, 1, asl_desc)
            ws.cell(row_idx, 2, distretto_desc)
            ws.cell(row_idx, 3, nr_distretto)
            ws.cell(row_idx, 4, medico_nome)
            ws.cell(row_idx, 5, spec_nome)
            ws.cell(row_idx, 6, fascia.get("indirizzo", "") or "")
            ws.cell(row_idx, 7, fascia.get("struttura", "") or "")
            ws.cell(row_idx, 8, zona_nome)
            ws.cell(row_idx, 9, giorno_str)
            ws.cell(row_idx, 10, minutes_to_hhmm(min_inizio))
            ws.cell(row_idx, 11, minutes_to_hhmm(min_fine))
            ws.cell(row_idx, 12, telefono)
            ws.cell(row_idx, 13, prodotti)
            ws.cell(row_idx, 14, annotazioni)
            row_idx += 1

        # Riga vuota di separazione al cambio medico
        row_idx += 1

    # Larghezze colonne
    widths = {
        1: 25,  # ASL
        2: 40,  # Distretto
        3: 8,   # NrDistretto
        4: 30,  # Medico
        5: 18,  # Specializzazione
        6: 35,  # Indirizzo
        7: 30,  # Struttura
        8: 18,  # Zona
        9: 12,  # Giorno
        10: 12, # OrarioInizio
        11: 12, # OrarioFine
        12: 30, # Telefono
        13: 35, # Prodotti
        14: 35, # Annotazioni
    }
    for col, width in widths.items():
        ws.column_dimensions[get_column_letter(col)].width = width

    # Filtri automatici sull'header
    ws.auto_filter.ref = f"A1:{get_column_letter(len(HEADERS))}{row_idx - 1}"

    # Salva
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = os.environ.get(
        "EXPORT_PATH",
        f"{EXPORT_FILENAME_PREFIX}{timestamp}{EXPORT_FILENAME_SUFFIX}",
    )
    wb.save(output_path)
    print(f"      File salvato: {output_path}")
    print(f"      Righe scritte: {row_idx - 2} (escluso header)")

    print("\n[4/4] Esportazione completata.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
