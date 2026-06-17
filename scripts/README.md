# Scripts Import/Export per InformatorEMS

Script Python per popolare il database Firebase leggendo il foglio Excel
`Elenco dottori 2025.xlsx` e per esportare il DB in un Excel strutturato.

## Struttura

```
scripts/
├── README.md                  # Questo file
├── requirements.txt           # Dipendenze Python
├── .gitignore                 # Esclude serviceAccountKey.json
├── serviceAccountKey.json     # ⚠️ DA GENERARE, NON committare
│
├── excel_time_utils.py        # Parsing celle orario (mattina, 8,30-13,00, ...)
├── phone_extractor.py         # Estrazione telefoni con regex italiana
├── excel_parser.py            # Parser Excel → record strutturati
├── firebase_client.py         # Wrapper Firestore (wipe, batch insert, get all)
│
├── import_excel.py            # ★ Entry point: Excel → Firebase
└── export_excel.py            # ★ Entry point: Firebase → Excel
```

## Setup

### 1. Dipendenze Python

```bash
cd scripts
pip install -r requirements.txt
```

Dipendenze: `openpyxl`, `firebase-admin`.

### 2. Service Account Key

Lo script richiede un service account JSON di Firebase per accedere a Firestore
in modalità amministrativa (bypassa le regole di sicurezza).

**Procedura:**

1. Apri la [Firebase Console](https://console.firebase.google.com/)
2. Seleziona il progetto `informatorems-784a1`
3. Vai su **Project settings** (icona ingranaggio) → tab **Service accounts**
4. Clicca **Generate new private key** → conferma → verrà scaricato un file JSON
5. Rinomina il file in `serviceAccountKey.json`
6. Salvalo in `scripts/serviceAccountKey.json` (accanto a questo README)

⚠️ **NON committare mai** `serviceAccountKey.json` su git (è già escluso
da `.gitignore`). Questo file dà accesso completo al tuo progetto Firebase.

### 3. File Excel di input

Per default lo script cerca `../Elenco dottori 2025.xlsx` (nella root del
progetto Flutter). Puoi specificare un altro path con la variabile d'ambiente:

```bash
# Windows PowerShell
$env:EXCEL_PATH="C:\percorso\del\mio\foglio.xlsx"
python import_excel.py
```

## Utilizzo

### Import (Excel → Firebase)

```bash
cd scripts
python import_excel.py
```

Lo script:

1. Si connette a Firebase.
2. Carica le specializzazioni esistenti (deve essere presente `Dermatologia`).
3. Parsa il file Excel.
4. **Cancella** le collection `asl`, `distretti`, `zone`, `medici`, `fasceOrarie`
   (le `specializzazioni` NON vengono toccate).
5. Inserisce i nuovi dati.
6. Stampa un report con conteggi e warning.

**Output esempio:**

```
[1/6] Inizializzazione Firebase...      OK
[2/6] Caricamento specializzazioni...   Trovate 7 specializzazioni
[3/6] Parsing Excel: ../Elenco dottori 2025.xlsx
      ASL: 4
      Distretti: 46
      Zone: 68
      Medici: 204
      Fasce orarie: 1633
[4/6] Wipe collection...
      fasceOrarie: 0 documenti cancellati
      ...
[5/6] Inserimento dati...
      ASL: 4... OK
      ...
```

### Export (Firebase → Excel)

```bash
cd scripts
python export_excel.py
```

Lo script:

1. Si connette a Firebase.
2. Carica tutte le collection.
3. Genera un Excel con **1 riga per fascia oraria** (formato long).
4. Salva in `scripts/export_informatorems_YYYYMMDD_HHMMSS.xlsx`.

**Colonne dell'Excel esportato:**

| Colonna | Descrizione |
|---|---|
| ASL | Descrizione ASL (es. "ASL NAPOLI 2 Nord") |
| Distretto | Descrizione distretto |
| NrDistretto | Numero del distretto |
| Medico | Nome completo |
| Specializzazione | Nome specializzazione |
| Indirizzo | Indirizzo dello studio |
| Struttura | Struttura/ente |
| Zona | Nome zona |
| Giorno | Lunedì, Martedì, ... |
| OrarioInizio | HH:MM |
| OrarioFine | HH:MM |
| Telefono | Numeri di telefono concatenati con " \| " |
| Prodotti | Lista prodotti |
| Annotazioni | Note libere (filtrate) |

## Logiche di parsing (riepilogo)

### Rilevamento tipo riga

Per ogni riga del foglio, la colonna 1 determina se è:

- **ASL**: inizia con `ASL`/`Asl`/`asl` (es. `ASL NAPOLI 2 Nord`)
- **Distretto**: inizia con `distretto`/`Distretto`/`DISTRETTO`/`Dstretto` (typo)
- **Medico**: tutto il resto

### Codici ASL

I codici ASL sono mappati al codice SSN reale:

| Descrizione Excel | Codice |
|---|---|
| ASL 1 NAPOLI Centro | 201 |
| ASL NAPOLI 2 Nord | 202 |
| ASL NAPOLI 3 Sud | 203 |
| ASL CASERTA | 101 |

### Distretti

- Codice = numero estratto dalla riga (es. `24`, `25`, `12`).
- Descrizione = testo dopo il numero (es. `ZONA CHIAIA - POSILLIPO - SAN FERDINANDO`).
- Collegati all'ultima ASL incontrata durante la scansione.

### Specializzazioni

- Match per nome (lowercase) contro la collection Firebase `specializzazioni`.
- Se non riconosciuta, default = **Dermatologia**.
- Se la cella contiene più valori (es. `Dermatologia | Medico Generale`),
  viene preso il primo riconoscibile.

### Orari

| Testo | Conversione |
|---|---|
| `mattina` | 08:00 – 12:00 |
| `pomeriggio` | 15:00 – 18:00 |
| `tutto il giorno` | 08:00 – 18:00 |
| `11,00 - 12,30\n15,00 - 17,00` | 11:00 – 17:00 (concatenato) |
| `12-14; 15-18` | 12:00 – 18:00 (concatenato) |
| vuoto / `si` / `?` / `14` | ignorato |

Più intervalli nella stessa cella vengono **concatenati** in un'unica fascia
(min start, max end), per scelta dell'utente.

### Indirizzi × zone × strutture × giorni

Per ogni riga medico, le fasce orarie sono generate come **prodotto cartesiano**
tra:

- lista indirizzi (colonna 2, splittata per `\n` o `|`)
- lista strutture (colonna 10)
- lista zone (colonna 11)
- giorni con orario valido (colonne 3-7)

Giorni con stesso (inizio, fine) vengono raggruppati in un'unica fascia
con `giorniSettimana = [lista_giorni]`.

### Telefono

I numeri di telefono sono estratti da colonne 1, 2, 8 con regex italiana
(`3xx cellulari`, `0xx fissi`, opzionale `+39`). I duplicati sono deduplicati
per sequenza di cifre; il risultato è concatenato con ` | `.

### Note (colonna 8)

Sono filtrate per rimuovere:
- nomi propri noti (`DANIELE`, `P.A.`)
- numeri isolati (telefono già estratto)
- keyword telefoniche residue

Il testo rimanente va nel campo `annotazioni` del medico.

## Casi edge documentati

| Riga | Caso | Gestione |
|---|---|---|
| R5 GRIMALDI | 2 indirizzi × orari diversi | cartesiano → multiple fasce |
| R7 IZZO | telefono nel nome `(cell 389 94 05 839)` | estratto da regex |
| R20 ESPOSITO | spec `Dermatologia \| Medico Generale` | match prima valida |
| R21 Dstretto | typo "Dstretto" | regex case-insensitive |
| R29 BORDONE | spec "ASL Soccavo" (errata) | default = Dermatologia |
| R38 SAMMARCO | 5×5×5 indirizzi × zone × strutture × orari | cartesiano |
| R151 MONTONE | spec "7" (errata) | default = Dermatologia |
| R158 GAGLIARDI | spec "Dermoestetica" | default = Dermatologia |
| R69-R116 | ~50 medici Policlinico SUN senza orari | importati senza fasce |

## Troubleshooting

### `ModuleNotFoundError: No module named 'firebase_admin'`

Installa le dipendenze: `pip install -r requirements.txt`.

### `FileNotFoundError: serviceAccountKey.json`

Scarica la chiave dalla Firebase Console come descritto nella sezione Setup.

### `ModuleNotFoundError: No module named 'openpyxl'`

Stessa soluzione: `pip install -r requirements.txt`.

### `specializzazione 'dermatologia' non trovata`

Aggiungi manualmente `Dermatologia` nella collection `specializzazioni`
dalla Firebase Console prima di importare.

### Import lento o timeout

L'inserimento di 200+ medici con 1600+ fasce può richiedere 1-2 minuti.
Lo script fa commit a batch da 450 documenti per rispettare i limiti Firestore.

## Note di sicurezza

- `serviceAccountKey.json` è in `.gitignore`. **Non committarlo mai**.
- Lo script esegue `wipe_collections` senza conferma. Ricontrolla il path
  dell'Excel e la presenza del service account prima di lanciarlo.
- Per ambienti di test, modifica temporaneamente `PROJECT_ID` in
  `firebase_client.py` per puntare a un progetto Firebase di sviluppo.
