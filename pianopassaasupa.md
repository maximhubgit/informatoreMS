# Piano di migrazione Firebase → Supabase

Data: 2026-10-31
Progetto: informatoreMS (Flutter + Riverpod)
Obiettivo: sostituire **solo il layer di accesso ai dati** (Firestore, Firebase Auth, seed, script) con Supabase, mantenendo invariata la logica applicativa: modelli, scheduler, use case e schermate non devono cambiare comportamento.

---

## 0. Fattibilità

Sì, la migrazione è fattibile con un intervento circoscritto. L'app è già strutturata bene per questo:

- 10 interfacce repository in `lib/data/repositories/*.dart` (contratti astratti).
- 10 implementazioni remote in `lib/data/repositories/remote/firebase_*.dart`, tutte basate su `FirebaseFirestore`.
- I provider di presentazione leggono i dati **quasi sempre** tramite i repository.
- Tutti i modelli serializzano/deserializzano `Map<String, dynamic>` con date ISO-8601 e id stringa: nessun tipo proprietario Firestore (`Timestamp`, `GeoPoint`, `DocumentReference`) è usato nei model.
- Gli id dei nuovi record sono già generati con `uuid` (v4) lato UI/scheduler.

Non ci sono query complesse, transazioni, Cloud Functions, Storage o regole di sicurezza Firestore nel codice Dart: solo CRUD su 10 collection. È quindi una sostituzione quasi 1:1.

---

## 1. Risposta diretta: i moduli "provider dati" cambiano o restano uguali?

Distinguiamo due livelli:

| Livello | Cosa sono | Cambia? |
|---|---|---|
| **Repository (contratti)** `lib/data/repositories/*_repository.dart` | Interfacce astratte (`getAll`, `save`, `delete`, …) | **No.** Restano identiche, salvo 2 piccole aggiunte elencate sotto (Specializzazione e Zona), necessarie perché oggi quei due CRUD bypassano il repository. |
| **Repository (implementazioni)** `lib/data/repositories/remote/*.dart` | `FirebaseMedicoRepository`, … | **Sì.** Vengono sostituiti da `SupabaseMedicoRepository`, … con gli stessi metodi e stessa semantica. |
| **Provider Riverpod** `lib/presentation/providers/*.dart` | `mediciProvider`, `calendarioProvider`, `salvaMedicoProvider`, ecc. | **No nella loro interfaccia pubblica** (nomi, tipi restituiti, API usata dalle schermate). Cambiano solo: l'import `as firebase` → `as supabase`, l'istanziazione dei repository, e i **5 blocchi** che oggi chiamano `FirebaseFirestore.instance` in modo diretto (ASL, Distretti, Zone, Aree, Specializzazioni) che vengono spostati dietro i repository. |
| **Modelli, scheduler, use case, schermate** | `core/models`, `domain/*`, `presentation/screens`, `widgets` | **No.** Zero modifiche, tranne `login_screen.dart` per il tipo di eccezione Auth e i messaggi d'errore. |

Quindi: **logica identica, layer dati riscritto, provider di presentazione invariati dall'esterno.**

---

## 2. Mappatura Firebase → Supabase

### 2.1 Collection → tabelle

| Collection Firestore | Tabella Supabase | PK |
|---|---|---|
| `asl` | `asl` | `codice` (integer) |
| `distretti` | `distretti` | `codice` (integer) |
| `zone` | `zone` | `id` (text) |
| `specializzazioni` | `specializzazioni` | `id` (text) |
| `aree` | `aree` | `id` (text, es. `A007`, `0000`) |
| `medici` | `medici` | `id` (text/UUID) |
| `fasceOrarie` | `fasceOrarie` | `id` (text/UUID) |
| `calendario_appuntamenti` | `calendario_appuntamenti` | `id` (text/UUID) |
| `appuntamenti` | `appuntamenti` | `id` (text/UUID) |
| `storico_appuntamenti` | `storico_appuntamenti` | `id` (text/UUID) |

### 2.2 Scelta dei nomi colonna: identici ai campi Firestore

Per non toccare nessun `toJson()`/`fromJson()`, le colonne mantengono **esattamente** i nomi dei campi Firestore (`idMedico`, `nrDistretto`, `codiceAsl`, `dataOraInizio`, perfino `"Area"` con la maiuscola). In PostgreSQL vanno definite e citate tra virgolette doppie perché contengono maiuscole:

```sql
create table public.medici (
  "id" text primary key,
  "nome" text not null,
  ...
);
```

Conseguenze:

- PostgREST restituisce le chiavi così come sono memorizzate, quindi `Medico.fromJson(map)` funziona senza modifiche.
- Nelle query Dart i nomi colonna sono stringhe (`select()`, `eq('idMedico', ...)`): nessun problema con le maiuscole.
- Le date restano **`text` in formato ISO-8601**, così `DateTime.parse(json['data'])` continua a funzionare identico. (Alternativa futura: `timestamptz` + conversione nel repository; non necessaria ora.)
- `giorniSettimana` diventa `text[]` (Postgres restituisce `List<dynamic>` come già fa Firestore).
- I booleani (`deleted`, `isFittizia`) diventano `boolean`, gli interi `integer`.

> Nota: se in futuro si preferiscono nomi snake_case convenzionali, si mappa nel repository. Non conviene farlo ora: aumenterebbe il codice da cambiare senza alcun beneficio funzionale.

### 2.3 Semantica operazioni

| Firestore | Supabase (supabase-dart) |
|---|---|
| `collection(x).get()` | `from(x).select().limit(...)` |
| `collection(x).doc(id).set(json)` | `from(x).upsert(json, onConflict: 'id')` |
| `collection(x).doc(id).update({...})` | `from(x).update({...}).eq('id', id)` |
| `collection(x).doc(id).delete()` | `from(x).delete().eq('id', id)` |
| `.where('idMedico', isEqualTo: v)` | `.eq('idMedico', v)` |
| `.where('codiceAsl', isEqualTo: v).orderBy('codice')` | `.eq('codiceAsl', v).order('codice')` |
| `.orderBy('codice')` | `.order('codice')` |
| Map di `doc.id` iniettato nei dati | `id` è una colonna e arriva già nella riga |
| Documento inesistente in `doc(id).get()` | `.select().eq('id', id).maybeSingle()` |

**Attenzione a 2 dettagli operativi:**

1. **Limite righe PostgREST**: Supabase applica di default un `max-rows` (tipicamente 1000). `fasceOrarie` può superare 1000 righe. Ogni `getAll()` deve usare `.limit(100000)` o `.range(0, 99999)`.
2. **Id generati dal DB**: Firestore creava l'id con `doc()`; Supabase no. Per le tabelle con PK `text`:
   - dove l'id è già generato (`medici`, `calendario_appuntamenti`, `zone`, `specializzazioni`, appuntamenti/storico), nessun cambio;
   - `FasciaOrariaRepository.save()` deve generare `Uuid().v4()` quando `fascia.id == null` (oggi lo fa Firestore);
   - `Area` e id fissi (`A007`, `0000`) restano invariati.

### 2.4 Autenticazione

| Firebase | Supabase |
|---|---|
| `FirebaseAuth.instance.signInAnonymously()` | `Supabase.instance.client.auth.signInAnonymously()` |
| `signOut()` | `signOut()` |
| `signInWithEmailAndPassword(...)` | `signInWithEmailAndPassword(email: ..., password: ...)` |
| `FirebaseAuthException` | `AuthException` (con `code`, `message`, `statusCode`) |

L'utente anonimo di Supabase riceve il ruolo `authenticated`: le policy RLS vanno scritte per il ruolo `authenticated`, non `anon`. Il login anonimo va abilitato in Dashboard → Authentication → Providers → Anonymous. Il comportamento resta identico all'attuale: sessione persistita localmente dal client.

### 2.5 Offline (differenza da conoscere)

Firestore su mobile ha cache offline nativa e code di scrittura automatiche. **Supabase non le ha.** Dopo la migrazione:

- Web: già oggi online-only → nessuna differenza.
- Mobile: letture/scritture offline falliscono finché non torna la rete, a meno di aggiungere uno strato di cache.

Il codice ha già `PendingOperationsService` (coda in `SharedPreferences`) e `SyncService`, ma la coda oggi non fa replay reale (i `case` sono vuoti). Per mantenere la parità offline serve una fase opzionale (Fase 8). In prima battuta la migrazione garantisce parità **online**; la scelta se implementare la cache va esplicitata.

---

## 3. Schema SQL Supabase

Creare `supabase/migrations/001_schema.sql` (o incollare nello SQL Editor):

```sql
-- ============ Anagrafica ============
create table if not exists public.asl (
  "codice"     integer primary key,
  "descrizione" text not null
);

create table if not exists public.distretti (
  "codice"      integer primary key,
  "nrDistretto" integer not null,
  "descrizione" text not null,
  "codiceAsl"   integer not null
);

create table if not exists public.zone (
  "id"        text primary key,
  "nome"      text not null,
  "coloreHex" text not null default '#4ECDC4'
);

create table if not exists public.specializzazioni (
  "id"    text primary key,
  "nome"  text not null,
  "icona" text
);

create table if not exists public.aree (
  "id"   text primary key,
  "Area" text not null
);

create table if not exists public.medici (
  "id"                        text primary key,
  "nome"                      text not null,
  "specializzazioneId"        text,
  "periodicitaGiorni"         integer not null default 30,
  "calendarioAppuntamentoId"  text,
  "annotazioni"               text,
  "telefono"                  text,
  "prodotti"                  text
);

-- ============ Fasce orarie ============
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
);
create index if not exists idx_fasce_idmedico on public."fasceOrarie" ("idMedico");
create index if not exists idx_fasce_deleted  on public."fasceOrarie" ("deleted");

-- ============ Appuntamenti ============
create table if not exists public.calendario_appuntamenti (
  "id"              text primary key,
  "medicoId"        text,
  "data"            text not null,
  "note"            text,
  "stato"           text not null default 'proposto',
  "dataCreazione"   text,
  "fasciaNumero"    integer,
  "fasciaOrariaId"  text
);
create index if not exists idx_cal_medico on public.calendario_appuntamenti ("medicoId");

create table if not exists public.appuntamenti (
  "id"            text primary key,
  "medicoId"      text,
  "dataOraInizio" text,
  "dataOraFine"   text,
  "stato"         text,
  "note"          text
);

create table if not exists public.storico_appuntamenti (
  "id"            text primary key,
  "medicoId"      text,
  "appuntamentoId" text,
  "dataEseguita"  text,
  "stato"         text,
  "timestamp"     text
);

-- ============ RLS ============
-- Firebase non aveva regole nel codice; qui manteniamo lo stesso livello di
-- apertura, ma SOLO per utenti autenticati (incluso l'anonimo Supabase).
alter table public.asl                     enable row level security;
alter table public.distretti               enable row level security;
alter table public.zone                    enable row level security;
alter table public.specializzazioni        enable row level security;
alter table public.aree                    enable row level security;
alter table public.medici                  enable row level security;
alter table public."fasceOrarie"           enable row level security;
alter table public.calendario_appuntamenti enable row level security;
alter table public.appuntamenti            enable row level security;
alter table public.storico_appuntamenti    enable row level security;

do $$
declare t text;
begin
  foreach t in array array[
    'asl','distretti','zone','specializzazioni','aree','medici',
    'fasceOrarie','calendario_appuntamenti','appuntamenti','storico_appuntamenti'
  ] loop
    execute format(
      'create policy "authenticated_all" on public.%I for all to authenticated using (true) with check (true)',
      t
    );
  end loop;
end $$;
```

Note:

- **Nessuna foreign key hard** nella prima migrazione (Firestore non le aveva e i dati esistenti possono avere riferimenti orfani). Si possono aggiungere dopo la validazione dei dati.
- Non creare relazioni cascade: le eliminazioni nel codice sono già esplicite (es. `deleteByMedicoId`).
- Verificare i permessi di default: Supabase concede `select/insert/update/delete` ai ruoli `anon`/`authenticated` sullo schema `public`; le policy sopra limitano comunque.

---

## 4. Dipendenze e configurazione

### 4.1 `pubspec.yaml`

```yaml
# rimuovere
firebase_core: ^3.0.0
firebase_auth: ^5.0.0
cloud_firestore: ^5.0.0

# aggiungere
supabase_flutter: ^2.0.0   # verificare l'ultima versione compatibile con Dart 3.11
```

`shared_preferences`, `uuid`, `connectivity_plus` restano.

### 4.2 Configurazione credenziali

Nuovo file `lib/core/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
```

Avvio:

```bash
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=eyJ...
```

La anon key è pubblica per design: la sicurezza sta nelle policy RLS. **Non** inserire la `service_role` key nell'app.

### 4.3 Inizializzazione

`lib/core/providers/firebase_provider.dart` viene sostituito da `lib/core/providers/supabase_provider.dart`:

```dart
final supabaseInitializationProvider = FutureProvider<void>((ref) async {
  if (!SupabaseConfig.isConfigured) {
    throw Exception('Supabase non configurato: mancano SUPABASE_URL/SUPABASE_ANON_KEY.');
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
});

final isSupabaseInitializedProvider = Provider<bool>((ref) {
  final async = ref.watch(supabaseInitializationProvider);
  return async.hasValue && !async.hasError;
});
```

`main.dart` cambia solo:

- import di `supabase_provider.dart`;
- `ref.watch(supabaseInitializationProvider)`;
- testo errore `'Errore inizializzazione Supabase'`.

La struttura `when(data/loading/error)` e la home login/HomeScreen restano identiche.

---

## 5. File da creare / modificare / eliminare

### 5.1 Nuovi repository (10 file)

In `lib/data/repositories/remote/`, per ogni implementazione esistente:

| Nuovo file | Implementa | Note implementative |
|---|---|---|
| `supabase_asl_repository.dart` | `AslRepository` | `select().order('codice')`, upsert su `codice` |
| `supabase_distretto_repository.dart` | `DistrettoRepository` | `getByAsl`: `.eq('codiceAsl', v).order('codice')` |
| `supabase_zona_repository.dart` | `ZonaRepository` | **aggiungere anche `save`/`delete`** (vedi 5.3) |
| `supabase_specializzazione_repository.dart` | `SpecializzazioneRepository` | **aggiungere `save`/`update`/`delete`** |
| `supabase_area_repository.dart` | `AreaRepository` | mappa `{ 'id': area.id, 'Area': area.nome }` |
| `supabase_medico_repository.dart` | `MedicoRepository` | upsert su `id` |
| `supabase_fascia_oraria_repository.dart` | `FasciaOrariaRepository` | filtro `deleted` in memoria (come oggi); sort in memoria; soft-delete con `update({'deleted': true})`; generazione UUID se `id == null`; `deleteByMedicoId` = `delete().eq('idMedico', ...)` |
| `supabase_calendario_repository.dart` | `CalendarioRepository` | `updateStato` con `update({'stato': ...}).eq('id', ...)` |
| `supabase_appuntamento_repository.dart` | `AppuntamentoRepository` | CRUD |
| `supabase_storico_repository.dart` | `StoricoRepository` | CRUD |

Esempio di riferimento (`supabase_medico_repository.dart`):

```dart
class SupabaseMedicoRepository implements MedicoRepository {
  final SupabaseClient _db = Supabase.instance.client;
  static const _table = 'medici';

  @override
  Future<List<Medico>> getAll() async {
    final rows = await _db.from(_table).select().limit(100000);
    return rows.map((row) => Medico.fromJson(Map<String, dynamic>.from(row))).toList();
  }

  @override
  Future<void> save(Medico medico) async {
    await _db.from(_table).upsert(medico.toJson(), onConflict: 'id');
  }

  @override
  Future<void> delete(String id) async {
    await _db.from(_table).delete().eq('id', id);
  }
}
```

`supabase_fascia_oraria_repository.dart` deve replicare **esattamente** la logica attuale: normalizzazione `id` nella mappa, filtering `!fascia.deleted`, ordinamento per `idMedico`/`nr` in `getAll`, ordinamento per `nr` in `getByMedicoId`, `getById` che rilancia `null` se assente.

### 5.2 File da eliminare

- `lib/core/providers/firebase_provider.dart` (sostituito).
- `lib/core/firebase_options.dart`.
- `lib/data/repositories/remote/firebase_*.dart` (10 file) — dopo la sostituzione completa.
- `lib/data/seeds/firebase_seed.dart` (sostituito da `supabase_seed.dart`).
- `firebase.json`.
- `android/app/google-services.json`.

### 5.3 Provider di presentazione (modifiche puntuali)

File e modifiche:

| File | Modifica |
|---|---|
| `medici_provider.dart` | alias import `as firebase` → `as supabase`; `_WebMedicoRepository`, `medicoRepositoryProvider`, `_WebFasciaOrariaRepository`, `fasciaOrariaRepositoryProvider`. **Nessun'altra modifica.** |
| `calendario_provider.dart` | alias + `_WebCalendarioRepository` + `calendarioRepositoryProvider`. `salvaAppuntamentoProvider`, `refreshTriggerProvider` restano identici. |
| `asl_provider.dart` | alias + istanza repo; `salvaAslProvider`/`eliminaAslProvider` devono chiamare `aslRepositoryProvider` (oggi usano `FirebaseFirestore.instance`). Stessi campi salvati: `codice`, `descrizione`. |
| `distretto_provider.dart` | come sopra; `salvaDistrettoProvider` oggi salva **solo** `codice`, `descrizione`, `codiceAsl` (non `nrDistretto`): mantenere questo comportamento 1:1. |
| `zone_provider.dart` | aggiungere a `ZonaRepository` i metodi `save`/`delete`; i provider `salvaZonaProvider`/`eliminaZonaProvider` passano dal repository. |
| `area_provider.dart` | `salvaAreaProvider`/`eliminaAreaProvider` passano da `areaRepositoryProvider`. |
| `specializzazione_provider.dart` | estendere `SpecializzazioneRepository` con `save`/`update`/`delete`; `salvaSpecializzazioneProvider` deve continuare a salvare **solo** `nome` (oggi scarta `icona` anche in creazione); `aggiorna...` solo `nome`. |
| `auth_provider.dart` | `FirebaseAuth` → `Supabase.instance.client.auth`; `AuthStatus` e API del notifier invariati. |
| `login_screen.dart` | `FirebaseAuthException` → `AuthException`; nuova funzione `_authErrorMessage` con i codici Supabase (`anonymous_provider_disabled`, `invalid_credentials`, `over_request_rate_limit`, `user_banned`). Layout invariato. |
| `seed_provider.dart` | riscritto su Supabase (stessi dati demo, `insert`/`upsert`). |
| `lib/data/services/sync_service.dart` | **invariato** (non contiene Firebase). |
| `distretti_selezionati_provider.dart`, `zone_selezionate_provider.dart`, `connectivity_provider.dart` | invariati. |

**Regola guida:** non introdurre miglioramenti o refactor durante la migrazione. Ogni chiamata Firestore va tradotta con la stessa forma, anche dove il comportamento attuale è discutibile (es. dati parziali salvati dai `salva*Provider`, `ref.refresh` vs `invalidate`). Si ripulisce dopo, con test verdi.

### 5.4 Piattaforme / build

- `android/app/build.gradle.kts`: rimuovere `id("com.google.gms.google-services")`.
- `android/settings.gradle.kts`: rimuovere la riga `id("com.google.gms.google-services") version("4.3.15") apply false`.
- `web/index.html`: rimuovere i 3 `<script>` CDN Firebase e il blocco `firebaseConfig`/`firebase.initializeApp`.
- `macos/Flutter/GeneratedPluginRegistrant.swift`, `windows/flutter/generated_plugins.cmake`, `generated_plugin_registrant.cc`: **non toccare a mano**, si rigenerano con `flutter pub get` / build.
- iOS: non è presente `GoogleService-Info.plist`; nessun intervento.
- `CLAUDE.md`: aggiornare i riferimenti a Firebase (architettura e pattern).

### 5.5 Seed

- Nuovo `lib/data/seeds/supabase_seed.dart`: stessa struttura di `firebase_seed.dart`, con `_db.from('asl').upsert(...)`, ecc. Usare `upsert` per essere ripetibile; per `zone`/`specializzazioni`/`medici`/`fasce` generare `Uuid().v4()` esplicito prima dell'insert.
- `seed_provider.dart` (quello con le specializzazioni demo) riscritto con `insert`.
- Entrambi sono strumenti di debug: non devono diventare parte del flusso di produzione.

---

## 6. Migrazione dei dati esistenti

Ordine obbligatorio (dipendenze logiche, come già fa `import_excel.py`):

```
asl → distretti → zone → specializzazioni → aree → medici → fasceOrarie
→ calendario_appuntamenti → appuntamenti → storico_appuntamenti
```

Procedura consigliata:

1. **Export da Firestore** con `scripts/firebase_client.py` (`get_all(collection)` per ciascuna collection) in JSON, includendo il document id.
   - Per `medici`, `zone`, `specializzazioni`, `aree`, `calendario_appuntamenti`, `appuntamenti`, `storico_appuntamenti`, `fasceOrarie`: aggiungere il document id come campo `id`.
   - Per `asl`/`distretti`: `id` non serve, la PK è `codice`.
2. **Trasformazione** (script Python una tantum):
   - garantire i campi attesi e i default (`deleted`, `isFittizia`, `slotDisponibili`, `periodicitaGiorni`, date ISO string);
   - normalizzare `giorniSettimana` in lista di stringhe;
   - verificare che ogni `fasciaOraria.idMedico` esista in `medici`; report degli orfani.
3. **Import in Supabase** con un nuovo `scripts/supabase_client.py` (pacchetto Python `supabase`, upsert a batch di 500-1000 righe).
4. **Validazione**: conteggio righe per tabella vs collection, controllo che i PK siano univoci e che il numero di `fasceOrarie`/`medici` coincida.
5. **Backup**: esportare di nuovo Firestore prima di qualunque wipe. Firestore non va spento finché la migrazione non è validata.

Nota: gli id Firestore (stringhe di 20 caratteri) vanno benissimo come PK `text`; i nuovi record useranno UUID v4. La convivenza è innocua.

---

## 7. Script Python

Tutti i file in `scripts/` accedono a Firebase Admin:

| File | Intervento |
|---|---|
| `firebase_client.py` | Sostituire con `supabase_client.py` mantenendo la stessa API pubblica (`get_all`, `wipe_collections`, `upsert_batch`, metodi `insert_*`), così `import_excel.py` e `export_excel.py` cambiano solo import/client. |
| `import_excel.py` | Import del nuovo client; il resto della pipeline (parse Excel → wipe → insert) resta identico. |
| `export_excel.py` | Import del nuovo client. |
| `crea_aree_e_aggiorna_fasce.py` | Sostituire `firebase_admin` con il client Supabase; stessi upsert su `aree` e `fasceOrarie`. |
| `export_informatorems_aree.py` | Idem. |
| `excel_parser.py` | **Invariato** (pura logica di parsing). |
| `requirements.txt` | Rimuovere `firebase-admin`, aggiungere `supabase`. |
| `README.md` | Aggiornare istruzioni (`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` per gli script, mai nella app). |

Gli script usano la **service_role key** (solo in locale, via variabile d'ambiente), perché devono fare wipe e batch bypassando RLS.

---

## 8. Parità offline (fase opzionale, da decidere)

Se serve mantenere su mobile la lettura/scrittura offline come con Firestore:

- **Letture**: cache dell'ultimo `getAll()` per tabella in `SharedPreferences` (o `sqflite`), usata come fallback in caso di errore di rete. Da inserire in un wrapper comune dei repository, non in ogni classe.
- **Scritture**: usare finalmente `PendingOperationsService` + `SyncService` per accodare `registraEsito` e `sposta` e fare replay quando `connectivityProvider` torna online. Oggi la coda esiste ma i `case` sono vuoti; andrebbero implementati qui.
- **Conflitti**: definire una regola (last-write-wins) e il comportamento per appuntamenti cancellati nel frattempo.

Senza questa fase l'app resta identica **online**, ma su mobile perde la resilienza offline nativa. Va deciso prima di dichiarare la migrazione conclusa.

---

## 9. Fasi di lavoro

1. **Progetto Supabase**: creare progetto, eseguire `001_schema.sql`, abilitare Anonymous sign-in, copiare URL e anon key.
2. **Dipendenze e init**: `pubspec.yaml`, `supabase_config.dart`, `supabase_provider.dart`, `main.dart`, rimozione file Firebase di configurazione piattaforma.
3. **Repository**: creare i 10 `Supabase*Repository`; estendere le interfacce `SpecializzazioneRepository` (save/update/delete) e `ZonaRepository` (save/delete).
4. **Provider**: sostituire alias/istanze; spostare i 5 CRUD diretti dietro i repository; aggiornare `auth_provider` e `login_screen`.
5. **Seed**: `supabase_seed.dart`, riscrittura `seed_provider.dart`.
6. **Dati**: export Firestore → import Supabase → validazione conteggi.
7. **Script Python**: client Supabase + aggiornamento entry point.
8. **Offline** (se deciso): cache letture + replay coda.
9. **Pulizia**: eliminare i file Firebase, aggiornare `CLAUDE.md` e README, `flutter pub get`, build su Android/Web/Windows.

---

## 10. Verifica / test

Automatici:

```bash
flutter pub get
flutter analyze
flutter test
```

Manuali (checklist funzionale, per confermare che la logica è identica):

- Login anonimo → `HomeScreen`; logout → `LoginScreen`; riavvio app con sessione attiva.
- Caricamento liste: ASL, distretti, zone, aree, specializzazioni, medici, fasce.
- Filtri per zona/distretto/area e mappa `zonaPerMedico`/`distrettoPerMedico` (dipendono dalle fasce `nr = 0`).
- CRUD medico + fasce multiple (incluso soft-delete fascia e `deleteByMedicoId`).
- Generazione calendario dallo scheduler (usa `calendarioProvider` + `refreshTriggerProvider`).
- Conferma/concordato/spostamento appuntamento, `updateStato`, collegamento `calendarioAppuntamentoId`.
- Report/storico: `registra_esito`, `storico_appuntamenti`, export Excel.
- Conteggio righe: ogni `getAll()` restituisce il totale atteso (>1000 per le fasce).
- Errori: Supabase spento / rete assente → messaggi UI coerenti.

---

## 11. Rischi e mitigazioni

| Rischio | Mitigazione |
|---|---|
| Policy RLS equivalenti a "tutti possono tutto" | È lo stesso livello di apertura di Firebase, ma va messo a verbale. Se serve multi-utente reale, aggiungere `user_id` alle tabelle e policy per utente. |
| Perdita offline su mobile | Fase 8 oppure accettazione esplicita del cambio di comportamento. |
| Limite 1000 righe PostgREST | `limit`/`range` espliciti in ogni `getAll`. |
| Nomi colonna con maiuscole | Citare sempre tra doppie virgolette in DDL/SQL; i repository usano `select('*')` e mappe. |
| Dati orfani dopo l'import | Nessuna FK hard in fase 1; report di validazione; FK opzionali dopo. |
| Differenze di serializzazione (liste, null) | I repository normalizzano con `Map<String, dynamic>.from(row)`; test su `giorniSettimana` e campi nullable. |
| Login anonimo disabilitato | Abilitarlo subito in Dashboard; messaggio UI dedicato. |
| Free tier Supabase in pausa per inattività | Pianificare upgrade o keep-alive prima del rilascio. |
| Rollback | Nessuna modifica a modelli/scheduler/use case; mantenere il progetto Firebase e i dati intatti fino a validazione. In caso di problemi si ripristina il branch e si ripristinano gli import. |

---

## 12. Cosa non cambia (riepilogo)

- `lib/core/models/*` — zero modifiche.
- `lib/domain/scheduler/calendar_scheduler.dart`, `lib/domain/usecases/*` — zero modifiche.
- `lib/presentation/screens/*` e `widgets/*` — zero modifiche, tranne `login_screen.dart` (tipo eccezione/messaggi).
- Nomi e API dei provider Riverpod usati dalle schermate — invariati.
- Formato dati di Firestore — preservato campo per campo, id compresi.
- Logica di soft-delete, filtro `deleted`, ordinamenti in memoria, `refreshTriggerProvider`, flusso di stato `proposto → confermato → concordato → fatto/annullato` — invariati.
