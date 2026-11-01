# Migrazione Firebase → Supabase (script Python)

Questa cartella contiene i due script per:

1. **creare/inizializzare le tabelle** su Supabase/Postgres;
2. **copiare tutti i dati** da Firebase Firestore alle nuove tabelle.

> Questa fase **non modifica l'app Flutter**. Gli script sono autonomi e usano
> `psycopg` + `firebase-admin`.

## Contenuto

| File | Scopo |
|---|---|
| `create_tables.py` | Crea tabelle, indici, RLS e grants. Idempotente. |
| `migrate_data.py` | Svuota le tabelle e reinserisce tutti i dati da Firestore. |
| `config.py` | Lettura `.env` e connessione condivisa. |
| `.env.example` | Modello dei parametri di connessione. |
| `.gitignore` | Esclude `.env`, venv e cache. |
| `requirements.txt` | Dipendenze Python. |

## 1. Preparazione

```powershell
cd scripts/supabase

python -m venv .venv
.\.venv\Scripts\Activate.ps1

pip install -r requirements.txt

copy .env.example .env
```

Poi apri `scripts/supabase/.env` e compila:

```ini
SUPABASE_DB_URL=postgresql://postgres.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres
FIREBASE_CREDENTIAL_PATH=../serviceAccountKey.json
FIREBASE_PROJECT_ID=informatorems-784a1
```

La connection string si trova in **Supabase Dashboard → Connect → Session pooler
(porta 5432)**. Se la password contiene `@`, `#`, `:`, `/` o `?`, va codificata
come URL (es. `p@ss` → `p%40ss`).

Il service account Firebase è già presente in `scripts/serviceAccountKey.json`
(è ignorato da git). Non committare né il file né `.env`.

## 2. Creazione tabelle

```powershell
python create_tables.py
```

Crea (o aggiorna) queste tabelle:

`asl`, `distretti`, `zone`, `specializzazioni`, `aree`, `medici`,
`fasceOrarie`, `calendario_appuntamenti`, `appuntamenti`,
`storico_appuntamenti`.

Le colonne mantengono **gli stessi nomi dei campi Firestore** (camelCase,
compreso `"Area"`), così l'app Flutter potrà usare i model esistenti senza
modifiche. Le date sono `text` in formato ISO-8601.

Viene abilitata la RLS con una policy `authenticated_all` per il ruolo
`authenticated` (l'utente anonimo Supabase dopo `signInAnonymously()` ha quel
ruolo). È lo stesso livello di apertura che aveva Firebase.

## 3. Verifica senza scrivere (consigliata)

```powershell
python migrate_data.py --dry-run
```

Legge Firestore, normalizza i documenti e stampa il numero di righe per
collection, senza toccare Supabase.

## 4. Migrazione dati

```powershell
python migrate_data.py
```

Comportamento:

- legge tutte le collection da Firestore;
- normalizza i campi legacy (`idDistretto`, `zonaIdEsteso`, `strutturaEstesa`,
  `indirizzoEsteso`, `specializzazione` per nome, date/datetime, booleani);
- **svuota tutte le tabelle** (`truncate ... cascade`) e reinserisce;
- usa una **singola transazione**: in caso di errore o conteggi non coerenti
  esegue il rollback e non lascia dati a metà;
- al termine confronta, per ogni tabella, righe attese e righe presenti,
  fallendo se non coincidono.

Ordine di importazione (FK-safe):

```
asl → distretti → zone → specializzazioni → aree → medici → fasceOrarie
→ calendario_appuntamenti → appuntamenti → storico_appuntamenti
```

## Note e limiti

- **Doppia esecuzione**: `migrate_data.py` è distruttivo per scelta (wipe +
  reinserimento). Rieseguirlo riporta Supabase all'istantanea attuale di
  Firebase, cancellando modifiche fatte nel frattempo su Supabase.
- **Backup**: esegui un export Firestore prima della prima migrazione e non
  spegnere il progetto Firebase finché l'app non è stata validata su Supabase.
- **Foreign key**: non vengono create. Firestore non le aveva e i dati
  esistenti possono contenere riferimenti orfani; si potranno aggiungere dopo
  una validazione dei dati.
- **Id**: i document id Firestore sono conservati come PK `text`; i nuovi
  record creati dall'app useranno UUID v4.
- **RLS**: le policy sono volutamente permissive (equivalenti allo stato
  attuale). Se servirà isolamento per utente, andrà aggiunta una colonna
  `user_id` e policy dedicate.
- **Chiavi**: la `SUPABASE_DB_URL` include la password del database. Va tenuta
  solo in `.env` locale o in variabili d'ambiente, mai nel repository.
