"""Entry point: importa il foglio Excel in Firebase Firestore.

Workflow:
1. Inizializza Firebase (service account key).
2. Carica le specializzazioni esistenti da Firebase.
3. Verifica che esista 'Dermatologia' (la spec di default).
4. Parsa il file Excel.
5. Wipe le collection gestite (asl, distretti, zone, medici, fasceOrarie).
6. Insert in ordine FK-safe (asl -> distretti -> zone -> medici -> fasceOrarie).
7. Stampa report finale con conteggi e warning.
"""
from __future__ import annotations

import os
import sys
import time

from excel_parser import parse_excel
from firebase_client import FirebaseClient


DEFAULT_EXCEL = "../Elenco dottori 2025.xlsx"
COLLECTIONS_TO_WIPE = ["fasceOrarie", "medici", "zone", "distretti", "asl"]


def main() -> int:
    print("=" * 70)
    print("IMPORTAZIONE EXCEL → FIREBASE")
    print("=" * 70)

    # 1) Inizializza Firebase
    print("\n[1/6] Inizializzazione Firebase...")
    try:
        client = FirebaseClient()
        # Trigger connessione
        _ = client.db
        print("      OK")
    except Exception as e:
        print(f"      ERRORE: {e}")
        return 1

    # 2) Carica specializzazioni
    print("\n[2/6] Caricamento specializzazioni esistenti...")
    spec_lookup = client.get_specializzazioni_lookup()
    print(f"      Trovate {len(spec_lookup)} specializzazioni:")
    for nome, sid in sorted(spec_lookup.items()):
        print(f"        - {nome} (id={sid[:8]}...)")
    
    # 3) Verifica Dermatologia
    if "dermatologia" not in spec_lookup:
        print("\n      ERRORE: specializzazione 'dermatologia' non trovata in Firebase.")
        print("      Aggiungila manualmente nella collection 'specializzazioni' prima di importare.")
        return 2
    default_spec_id = spec_lookup["dermatologia"]
    print(f"      Default per spec anomale: dermatologia (id={default_spec_id[:8]}...)")

    # 4) Parsing Excel
    excel_path = os.environ.get("EXCEL_PATH", DEFAULT_EXCEL)
    print(f"\n[3/6] Parsing Excel: {excel_path}")
    if not os.path.exists(excel_path):
        print(f"      ERRORE: file non trovato: {excel_path}")
        print("      Imposta la variabile EXCEL_PATH o copia il file nella root del progetto.")
        return 3
    result = parse_excel(excel_path, spec_lookup, default_spec_id)
    print(f"      ASL: {len(result.asl)}")
    print(f"      Distretti: {len(result.distretti)}")
    print(f"      Zone: {len(result.zone)}")
    print(f"      Medici: {len(result.medici)}")
    total_fasce = sum(len(m.fasce) for m in result.medici)
    print(f"      Fasce orarie: {total_fasce}")

    if not result.medici:
        print("      ATTENZIONE: nessun medico trovato. Importazione annullata.")
        return 4

    # 5) Wipe collection (in ordine FK-safe)
    print(f"\n[4/6] Wipe collection: {', '.join(COLLECTIONS_TO_WIPE)}")
    counts = client.wipe_collections(COLLECTIONS_TO_WIPE)
    for coll, n in counts.items():
        print(f"      {coll}: {n} documenti cancellati")
    
    # 6) Insert in ordine
    print("\n[5/6] Inserimento dati...")
    t0 = time.time()

    print(f"      ASL: {len(result.asl)}...", end=" ", flush=True)
    client.insert_asl(result.asl)
    print("OK")
    
    print(f"      Distretti: {len(result.distretti)}...", end=" ", flush=True)
    client.insert_distretti(result.distretti)
    print("OK")

    print(f"      Zone: {len(result.zone)}...", end=" ", flush=True)
    zone_ids = client.insert_zone(result.zone)
    print(f"OK ({len(zone_ids)} id generati)")

    print(f"      Medici: {len(result.medici)}...", end=" ", flush=True)
    medico_ids = client.insert_medici_batch(result.medici)
    print(f"OK ({len(medico_ids)} id generati)")

    print(f"      Fasce orarie: {total_fasce}...", end=" ", flush=True)
    fasce_per_medico = [m.fasce for m in result.medici]
    n_fasce = client.insert_fasce_batch(fasce_per_medico, medico_ids, zone_ids)
    print(f"OK ({n_fasce} inserite)")

    elapsed = time.time() - t0
    print(f"\n[6/6] Importazione completata in {elapsed:.1f}s")

    # Report warning
    if result.warnings:
        print("\n" + "=" * 70)
        print(f"WARNING ({len(result.warnings)}):")
        print("=" * 70)
        for w in result.warnings:
            print(f"  - {w}")

    print("\n" + "=" * 70)
    print("RIEPILOGO FINALE")
    print("=" * 70)
    print(f"  ASL inserite:           {len(result.asl)}")
    print(f"  Distretti inseriti:     {len(result.distretti)}")
    print(f"  Zone inserite:          {len(result.zone)}")
    print(f"  Medici inseriti:        {len(result.medici)}")
    print(f"  Fasce orarie inserite:  {n_fasce}")
    print(f"  Warning:                {len(result.warnings)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
