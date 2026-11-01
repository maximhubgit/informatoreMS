# lingAI.md — InformatoreMS (informatoreMS / BIOGENA)

> File di specifiche tecniche per riprendere il progetto da zero in successive sessioni.
> Generato il: 2025-07-10. Progetto: Flutter app medico calendario con Riverpod + Firestore.

---

## 1. IDENTITÀ PROGETTO

- **Nome pacchetto**: `informatoreMS` (pubspec.yaml)
- **App display name**: "Informatore Medico Scentifico" (HomeScreen drawer header)
- **App intern name**: "BIOGENA" (dashboard title, AppConstants.appName)
- **SDK**: Dart ^3.11.0
- **Architettura**: Layer separato (core/models → data/repositories → domain/usecases → presentation/providers → presentation/screens)
- **State Management**: Riverpod 2.6.1 (Provider, FutureProvider, StateNotifierProvider, StateProvider, Provider.family, autoDispose)
- **Backend**: Firebase (Firestore + Auth anonima). Persistenza offline gestita da Firestore SDK su mobile; su web lancia errore se offline (wrapper `_Web*Repository`).
- **Piattaforme**: Android, iOS, Web, Windows, Linux, macOS (template Flutter multi-platform)

---

## 2. STRUTTURA CARTELLE

```
lib/
  main.dart                          → entry point, Firebase init, auth routing
  core/
    constants.dart                   → AppConstants (appName="BIOGENA", defaultTempoVisita=30min, defaultMaxMediciGiorno=8)
    firebase_options.dart            → Firebase config per piattaforme (projectId: informatorems-784a1)
    extensions/
      date_time_extension.dart       → DateTimeX (dateOnly, isSameDay, formatItalia, formatOrario, minutiDaMezzanotte) + TimeOfDayFormat
      specializzazione_extension.dart → SpecializzazioneX (coloreSpecializzazione per nome)
    models/
      medico.dart                    → Medico (id, nome, specializzazioneId, periodicitaGiorni, calendarioAppuntamentoId, annotazioni, telefono, prodotti)
      appuntamento.dart              → Appuntamento (stato diverso da CalendarioAppuntamento: proposto/confermato/spostato/fatto/nonFatto)
      calendario_appuntamento.dart   → CalendarioAppuntamento (id, medicoId, data, note, stato, dataCreazione, fasciaNumero, fasciaOrariaId) + StatoCalendario enum
      fascia_oraria.dart             → FasciaOraria (nr, minutiInizio/Fine, slotDisponibili, giorniSettimana, distrettoId, zonaId, struttura, indirizzo, tempoVisitaMinuti, deleted, isFittizia, idArea)
      zona.dart                        → Zona (id, nome, coloreHex)
      area.dart                        → Area (id: 'A007' o '0000', nome) — sentinella idNonGeolocalizzato='0000'
      asl.dart                         → Asl (codice auto-increment, descrizione)
      distretto.dart                   → Distretto (codice, nrDistretto, descrizione, codiceAsl)
      specializzazione.dart            → Specializzazione (id, nome, icona: IconData)
      storico_appuntamento.dart        → StoricoAppuntamento (id, medicoId, appuntamentoId, dataEseguita, stato, timestamp)
      pending_operation.dart           → PendingOperation (id, tipo: sposta|registraEsito, payload, timestamp)
    providers/
      firebase_provider.dart           → firebaseInitializationProvider (FutureProvider), isFirebaseInitializedProvider
  data/
    repositories/
      medico_repository.dart           → abstract MedicoRepository (getAll, save, delete)
      calendario_repository.dart       → abstract CalendarioRepository (getAll, save, updateStato, delete)
      appuntamento_repository.dart     → abstract AppuntamentoRepository (getAll, save, delete)
      fascia_oraria_repository.dart    → abstract FasciaOrariaRepository (getAll, getByMedicoId, getById, save, delete, deleteByMedicoId)
      area_repository.dart             → abstract AreaRepository (getAll, save, delete)
      asl_repository.dart              → abstract AslRepository (getAll, save, delete)
      zona_repository.dart             → abstract ZonaRepository (getAll)
      distretto_repository.dart        → abstract DistrettoRepository (getAll, save, delete, getByAsl)
      specializzazione_repository.dart → abstract SpecializzazioneRepository (getAll)
      storico_repository.dart          → abstract StoricoRepository (getAll, save)
    repositories/remote/
      firebase_medico_repository.dart      → FirebaseMedicoRepository (collezione 'medici', doc.id → id)
      firebase_calendario_repository.dart  → FirebaseCalendarioRepository (collezione 'calendario_appuntamenti')
      firebase_appuntamento_repository.dart → FirebaseAppuntamentoRepository (collezione 'appuntamenti')
      firebase_fascia_oraria_repository.dart → Firestore 'fasceOrarie', soft-delete via 'deleted' field
      firebase_area_repository.dart         → Firestore 'aree', doc.id → id, campo 'Area' → nome
      firebase_asl_repository.dart          → Firestore 'asl', doc.codice → codice
      firebase_zona_repository.dart         → Firestore 'zone'
      firebase_distretto_repository.dart    → Firestore 'distretti', orderBy 'codice'
      firebase_specializzazione_repository.dart → Firestore 'specializzazioni', campo 'icona' stringa
      firebase_storico_repository.dart       → Firestore 'storico_appuntamenti'
    seed_provider.dart                   → Provider seedDatabaseProvider (debug only, commented out blocks)
    seeds/firebase_seed.dart             → FirebaseSeeder (script completo per popolare Firestore: ASL→Distretti→Zone→Specializzazioni→Medici+Fasce→Appuntamenti)
    services/
      pending_operations_service.dart    → Singleton, SharedPreferences, JSON string list
      sync_service.dart                  → SyncService(ref), syncIfNeeded(isConnected): replays pending ops, invalida calendarioProvider
  domain/
    scheduler/calendar_scheduler.dart    → CalendarScheduler (genera appuntamenti periodici, ottimizzato O(1) lookup con mappe pre-calcolate)
    usecases/
      genera_calendario_usecase.dart     → GeneraCalendarioUseCase (wraps CalendarScheduler)
      sposta_appuntamento_usecase.dart   → SpostaAppuntamentoUseCase (cambia data/ora + stato=spostato + storico)
      registra_esito_usecase.dart        → RegistraEsitoUseCase (fatto/nonFatto + storico)
      esporta_appuntamenti_usecase.dart  → EsportaAppuntamentiUseCase (genera Excel Uint8List con colonne Zona/Medico/Stato/Data/Giorni/Struttura/Indirizzo/Telefono/Prodotti)
  presentation/
    providers/
      auth_provider.dart               → authProvider (StateNotifier<AuthStatus>), isAuthenticatedProvider
      calendario_provider.dart         → calendarioProvider (FutureProvider), refreshTriggerProvider, calendarioRangeProvider, maxMediciPerGiornoProvider, salvaAppuntamentoProvider, confermaAppuntamentoProvider, eliminaAppuntamentoProvider, calendarioRepositoryProvider, medicoByIdProvider, fasciaByIdProvider, appuntamentiPerMedicoProvider(family), appuntamentiPerMedicoMapProvider, prossimeVisiteProvider, prossimaVisitaPerMedicoProvider(family), appuntamentiDelGiornoProvider(family), contatoriPerMeseProvider, contatoreDelGiornoProvider(family), medicoByIdProvider, fasciaPrincipaleProvider, zonaPerMedicoProvider, distrettoPerMedicoProvider
      medici_provider.dart             → medicoRepositoryProvider, mediciProvider, salvaMedicoProvider, eliminaMedicoProvider, fasciaOrariaRepositoryProvider, fasceOrarieProvider, salvaFasciaOrariaProvider, eliminaFasciaOrariaProvider, fasceOrarieMedicoProvider(family), fasciaByIdProvider, areaPerMedicoMapProvider, zonaPerMedicoProvider, distrettoPerMedicoProvider, fasciaPrincipaleProvider, mediciFiltratiProvider
      area_provider.dart               → areaRepositoryProvider, areaProvider, areaByIdProvider, prossimoCodiceAreaProvider, salvaAreaProvider, eliminaAreaProvider, areeSelezionateProvider (StateNotifier<Set<String>>)
      asl_provider.dart                → aslRepositoryProvider, aslProvider, aslByCodiceProvider, salvaAslProvider, eliminaAslProvider
      distretto_provider.dart          → distrettoRepositoryProvider, distrettoProvider, distrettoByCodiceProvider, distrettiByAslProvider(family), salvaDistrettoProvider, eliminaDistrettoProvider
      zone_provider.dart               → zonaRepositoryProvider, zoneProvider, zonaByIdProvider, salvaZonaProvider, eliminaZonaProvider
      specializzazione_provider.dart   → specializzazioneRepositoryProvider, specializzazioneProvider, salvaSpecializzazioneProvider, aggiornaSpecializzazioneProvider, specializzazioneByIdProvider, eliminaSpecializzazioneProvider
      connectivity_provider.dart       → connectivityProvider (StreamProvider<bool>), isConnectedProvider
      distretti_selezionati_provider.dart → distrettiSelezionatiProvider (StateNotifier<Set<int>>)
      zone_selezionate_provider.dart     → zoneSelezionateProvider (StateNotifier<Set<String>>)
    screens/
      home_screen.dart                 → HomeScreen (Scaffold + DashboardScreen + BottomNavBar con 4 destinazioni + AppDrawer con 9 voci)
      login_screen.dart                → LoginScreen (FirebaseAuth.signInAnonymously)
      dashboard_screen.dart            → DashboardScreen (BIOGENA title, 3 cards: Medici, Appuntamenti stats, Prossimi Appuntamenti)
      calendario_screen.dart           → CalendarioScreen (TableCalendar + lista appuntamenti giorno, mark done/cancelled/move, naviga storico medico)
      calendario_mese_screen.dart      → CalendarioMeseScreen (TableCalendar con badge contatori, lista giorno, ricerca medico aggiungi, mark done/cancelled/move, conferma)
      prossimi_appuntamenti_screen.dart  → ProssimiAppuntamentiScreen ("Pianifica"): TripleFilterRow, lista appuntamenti (scaduti+futuri), esporta Excel, range dialog, max medici dialog, conferma/appuntamenti actions dialog
      appuntamenti_concordati_screen.dart → AppuntamentiConcordatiScreen ("Gestisci"): search, status chips, range presets, lista raggruppata per giorno, filtri avanzati (custom range), dialog nuov appuntamento con medico picker + fascia picker
      medici_list_screen.dart          → MediciListScreen: search bar, TripleFilterRow, ordinamento (alfabetico/prossimaVisita/distretto), tile medico, naviga MedicoEditScreen
      medico_edit_screen.dart          → MedicoEditScreen: form nome/specializzazione/periodicità/annotazioni/telefono/prodotti, section fasce orarie (CRUD con dialog dettagli completi), save→salvaMedico+salvaFasciaOraria per ogni fascia, delete→delete+deleteByMedicoId
      appuntamento_edit_screen.dart    → AppuntamentoEditScreen (modifica appuntamento concordato: data/orario, fascia oraria dropdown, ultima visita, delete)
      aree_screen.dart                 → AreeScreen: lista aree, add/edit/delete con dialog, prossimoCodiceAreaProvider
      asl_screen.dart                  → AslScreen: lista ASL, add/edit/delete, FloatingActionButton
      distretti_screen.dart            → DistrettiScreen: lista distretti con ASL, add/edit/delete con dropdown ASL
      zone_screen.dart                 → ZoneScreen: lista zone con colore cerchio, add/edit/delete
      specializzazioni_screen.dart     → SpecializzazioniScreen: DataTable con nome/icona/azioni, add/edit/delete
      storico_full_screen.dart         → StoricoFullScreen: filtri isConcluso, sorted by data desc, tile con stato
      storico_medico_screen.dart       → StoricoMedicoScreen (timeline medico): filtri solo isConcluso, timeline visuale
      report_screen.dart               → ReportScreen (placeholder: "Report - In sviluppo")
    widgets/
      appuntamento_card.dart           → AppuntamentoCard: Slidable con azioni (Conferma/Elimina/Fatto/Annullato/Sposta), mostra stato badge, info medico
      fascia_selector.dart             → FasciaSelector: Wrap di ActionChip per fasce orarie
      triple_filter_row.dart           → TripleFilterRow: 3 campi Distretti/Zone/Aree con multi-select dialog condiviso
      zona_chip.dart                   → ZonaChip: Material chip colorato per zona
  test/widget_test.dart
```

---

## 3. MODELLI DATI — FIRESTORE COLLECTIONS

| Collection | Document ID | Campi principali | Note |
|---|---|---|---|
| `medici` | id (auto) | id, nome, specializzazioneId, periodicitaGiorni, calendarioAppuntamentoId, annotazioni, telefono, prodotti | Medico.fromJson supporta fallback `specializzazione` |
| `calendario_appuntamenti` | id (auto o uuid) | id, medicoId, data (ISO), note, stato, dataCreazione, fasciaNumero, fasciaOrariaId | stato: StatoCalendario.name |
| `fasceOrarie` | id (uuid) | id, idMedico, nr, minutiInizio/Fine, slotDisponibili, giorniSettimana (list string), distrettoId, zonaId, struttura, indirizzo, tempoVisitaMinuti, deleted, isFittizia, idArea | Soft delete via `deleted=true`. Fallback campi vecchio formato (idDistretto, distrettoIdEstido, zonaIdEsteso, etc.) |
| `zone` | id (uuid) | nome, coloreHex | Colore hex con # |
| `aree` | id ('A007' format) | Area (nome) | Area.formattaCodice(codice) → 'A'+3 cifre. Sentinella '0000' |
| `asl` | codice (toString) | codice, descrizione | Auto-increment in UI |
| `distretti` | codice (toString) | codice, nrDistretto, descrizione, codiceAsl | orderBy 'codice' |
| `specializzazioni` | id (uuid) | nome, icona (string) | Icon string → IconData mapping |
| `appuntamenti` | id | medicoId, dataOraInizio, dataOraFine, stato, note | StatoAppuntamento enum |
| `storico_appuntamenti` | id | medicoId, appuntamentoId, dataEseguita, stato, timestamp | |
| `storico_appuntamenti` | id | medicoId, appuntamentoId, dataEseguita, stato, timestamp | |

### Gerarchia anagrafica
`ASL (codice)` → `Distretti (codice, codiceAsl)` → `Zone (id)` → `Aree (id)` ← `FasciaOraria (distrettoId, zonaId, idArea)` → `Medico (specializzazioneId)`

---

## 4. STATO APPUNTAMENTO — DUE ENUM DISTINTI

### StatoCalendario (CalendarioAppuntamento)
```
proposto → confermato → concordato → fatto/annullato
```
- `proposto`: generato dallo scheduler, non ancora confermato
- `confermato`: confermato dall'utente ma non collegato all'anagrafica
- `concordato`: collegato all'anagrafica medico (calendarioAppuntamentoId)
- `fatto`/`annullato`: conclusi (`isConcluso = true`)

Colori: proposto=blue, confermato=indigo, concordato=teal, fatto=green, annullato=red.

### StatoAppuntamento (Appuntamento - storico)
`proposto, confermato, spostato, fatto, nonFatto` — `isConcluso = fatto || nonFatto`

---

## 5. ROUTING E NAVIGAZIONE

**main.dart**: 
- `firebaseInitializationProvider` → `MyApp` → se `isAuthenticated` → `HomeScreen` altrimenti `LoginScreen`
- Login: `authProvider.notifier.login()` → `signInAnonymously()`
- Logout: `authProvider.notifier.logout()` → HomeScreen (non LoginScreen) — re-autenticazione anonima all'accesso futuro

**HomeScreen**: Scaffold con AppBar "Informatore Medico Scentifico" + Drawer + DashboardScreen body + BottomNavBar (4 tab: Pianifica/ProssimiAppuntamenti, Gestisci/AppuntamentiConcordati, Calendario/CalendarioMese, Report/ReportScreen)

**BottomNavBar destinations** (index): 0=Pianifica, 1=Gestisci, 2=Calendario, 3=Report

**Drawer sections**: Principale (Pianifica, Gestisci, Calendario, Report), Anagrafica (Zone, Specializzazioni, Medici, ASL, Distretti, Aree), Footer (Logout)

---

## 6. KEY PROVIDERS — CALENDARIO PROVIDER

### calendarioProvider (FutureProvider<List<CalendarioAppuntamento>>)
Logica:
1. `ref.watch(refreshTriggerProvider)` — forza refresh dopo salvataggi
2. Carica medici (`mediciProvider.future`)
3. Filtra per zone selezionate (zona dalla fascia principale nr=0 del medico)
4. Carica `fasceOrarieProvider` (singola query, condivisa)
5. Chiama `CalendarScheduler().genera(mediciFiltrati, rangeStart, rangeEnd, esistenti, maxMediciPerGiorno, fasceOrarie)`
6. **Merge**: esistenti hanno priorità sui generati (mappa `medicoId:soloData` → priorità stati: fatto(4) > annullato(3) > concordato(2) > confermato(1) > proposto(0))
7. Generati aggiunti solo se non esiste concordato/confermato per stesso medico+giorno

### Range & Limit
- `calendarioRangeProvider`: default (now, now+90 giorni). Impostabile tramite dialog range in ProssimiAppuntamentiScreen
- `maxMediciPerGiornoProvider`: default 8. Impostabile tramite dialog in ProssimiAppuntamentiScreen (opzioni: 4,6,8,10,12)

### Salvataggio
- `salvaAppuntamentoProvider`: salva su repo + incrementa `refreshTriggerProvider`
- `confermaAppuntamentoProvider`: updateStato a confermato + refresh calendarioProvider
- `eliminaAppuntamentoProvider`: delete + refresh calendarioProvider

---

## 7. CALENDAR SCHEDULER (domain/scheduler/calendar_scheduler.dart)

**Input**: List<Medico>, rangeStart, rangeEnd, List<CalendarioAppuntamento> esistenti, maxMediciPerGiorno=8, List<FasciaOraria> fasceOrarie

**Algoritmo** (ottimizzato per 204 medici):
- Pre-calcolo: `esistentiPerMedico` (Map), `fascePerMedico` (Map), `esistentiKeys` (Set "medicoId:YYYY-M-D"), `occupazione` (Map<DateTime, List<_Slot>>), `mediciPerGiorno` (Map<DateTime, int>), `mediciEsistentiPerGiorno` (Map<DateTime, int> per stati non-conclusi)
- **Sort medici** con flag pre-calcolati (_MedicoFlags: hasSaltato, hasConcordato, hasConfermato) → O(N log N) con confronti O(1)
- **Loop per medico**: 
  - `_calcolaAncoraggio`: trova prossima data in base a esistenti (futuro non-concluso → periodicità; passato non-concluso → rangeStart; prefissato; ultimo concluso; altrimenti rangeStart)
  - **While loop** fino a rangeEnd:
    - Check maxMediciPerGiorno (O(1) con mappe)
    - Check duplicati (Set O(1))
    - `_trovaSlotLibero`: cerca slot libero nelle fasce del medico per quella data (step 15 min)
    - Se slot trovato → crea CalendarioAppuntamento (stato=proposto, fasciaNumero=indice+1, fasciaOrariaId=fascia.id)
    - Se no → `_trovaProssimoGiornoValido` (cerca giorno con fasce valide, NON applicando periodicità qui)
  - Difesa `_maxIterazioniTotali = 50000`
- `_aggiungiPeriodicita`: se 28-31 giorni o multipli di 30 → mensile (aggiunge mesi); altrimenti giorni

**Prossima visita** (prossimaVisitaPerMedicoProvider): cerca prima concordati, poi proposti, poi ultimo fatto + periodicità. Usa `appuntamentiPerMedicoMapProvider` (Map medicoId → lista) per O(1) lookup.

---

## 8. WEB vs MOBILE STRATEGY

Ogni repository ha un wrapper `_Web*Repository` che lancia `Exception('Connessione richiesta...')` se il Firebase call fallisce. Il provider del repository seleziona:
- **Web** (`kIsWeb`): wrapper web-only
- **Mobile/Desktop**: Firebase diretto (persistenza offline nativa Firestore)

Eccezione: `salvaAreaProvider`, `salvaAslProvider`, `salvaDistrettoProvider`, `salvaZonaProvider`, `salvaSpecializzazioneProvider`, `salvaFasciaOrariaProvider` usano `FirebaseFirestore.instance` direttamente (non passano per il wrapper).

---

## 9. OFFLINE SYNC

- `PendingOperation` enum: `sposta`, `registraEsito`
- `PendingOperationsService`: singleton con SharedPreferences (chiave: 'pending_operations'), JSON string list
- `SyncService`: chiamato da main quando connectivity cambia; `syncIfNeeded(true)` percorre la coda e rimuove operazioni riuscite; `_ref.invalidate(calendarioProvider)` alla fine
- **Nota**: il replay effettivo verso backend è ancora stub (break in switch) — sarà implementato con repository reali

---

## 10. FIREBASE CONFIG

- **Project ID**: `informatorems-784a1`
- **Auth**: Anonymous sign-in (`signInAnonymously`). Login con email/password anche disponibile (`loginWithEmail`)
- **Firestore**: Collections come sopra. Persistenza offline abilitata di default su mobile
- **Firebase Options**: `DefaultFirebaseOptions.currentPlatform` (android, web, windows configurati; iOS/macOS/Linux non configurati → UnsupportedError)
- **Firebase Auth error handling**: Login screen mappa errori (operation-not-allowed, network-request-failed, too-many-requests, user-disabled)

---

## 11. EXPORT EXCEL

`EsportaAppuntamentiUseCase` → Colonne: Zona, Medico, Stato, Data Appuntamento, Lunedì-Venerdì (orario fascia), Struttura, Indirizzo, Telefono, Prodotti. Ordinato per data/ora. Righe vuote tra giorni diversi. Usa `excel` package → `Uint8List`. Salva con `FileSaver.instance.saveFile(name, bytes)` nella schermata ProssimiAppuntamentiScreen.

---

## 12. WIDGET KEY PATTERN

- `AppuntamentoCard`: Slidable (flutter_slidable). Azioni: Conferma (blue, solo proposto), Elimina (red), Fatto (green), Annullato (red), Sposta (orange). `enabled: !isConcluso`. `onTap` → naviga a StoricoMedicoScreen (calendario_screen) o azione dialog (prossimi_appuntamenti_screen)
- `TripleFilterRow`: 3 `_CompactFilterField` (Distretti/Zone/Aree) con icona centrata + caption bordo. Dialog multi-select condiviso `_showMultiSelectDialog<T>`. Stati: `distrettiSelezionatiProvider`, `zoneSelezionateProvider`, `areeSelezionateProvider`
- `FasciaSelector`: ActionChip wrap per selezione fascia oraria
- `ZonaChip`: Material chip con colore zona

---

## 13. MEDICO EDIT FLOW

`MedicoEditScreen`:
1. Se `widget.medico == null` → nuovo medico (carica `fasceOrarieMedicoProvider('')` → vuoto)
2. Se modifica → carica `fasceOrarieMedicoProvider(medicoId)` via post-frame callback
3. Form: nome (obbligatorio), specializzazione (dropdown), periodicità (numero), annotazioni, telefono, prodotti
4. Section fasce: mostra `_fasce` con ExpansionTile (orari, giorni, distretto, zona, struttura, indirizzo, durata). Per ogni fascia: edit orari (time pickers), edit dettagli (dialog con distretto/zona/struttura/indirizzo/area/durata/giorni), toggle `isFittizia`, delete
5. Aggiungi fascia: dialog dettagli completi (distretto obbligatorio, zona obbligatorio, idArea obbligatoria). Se esiste fascia nr=0 → dialog "richiama dati fascia principale" vs "dettagli specifici"
6. Save: `salvaMedicoProvider(nuovoMedico)` + `salvaFasciaOrariaProvider` per ogni fascia + `invalidate(fasceOrarieMedicoProvider(medicoId))` + `_completaSalvataggio()` → invalidate mediciProvider + calendarioProvider + pop
7. Delete: dialog conferma → `medicoRepositoryProvider.delete(id)` + `fasciaOrariaRepositoryProvider.deleteByMedicoId(id)` + invalidate mediciProvider

---

## 14. APPUNTAMENTO EDIT FLOW

`AppuntamentoEditScreen` (da StoricoMedicoScreen tap):
- Mostra medico in sola lettura + zona + ultima visita
- Modifica data (date picker) e ora (time picker)
- Dropdown fascia oraria (numero progressivo da 1)
- Save: `salvaAppuntamentoProvider` + refresh calendarioProvider + pop
- Delete: dialog conferma + `calendarioRepositoryProvider.delete(id)`

---

## 15. NUOVO APPUNTAMENTO (AppuntamentiConcordatiScreen)

Dialog "Nuovo appuntamento":
1. Selezione medico (picker da lista medici)
2. Selezione fascia oraria obbligatoria (dropdown con orari + struttura/indirizzo)
3. Data (date picker) e Ora (time picker)
4. Se stato era "proposto" e `salvaComeConcordato=true` → stato diventa "concordato"
5. Salva + pop + clear search

---

## 16. PROSSIMI APPUNTAMENTI — FILTRI

Filtri attivi: zona (da `zonaPerMedicoProvider`), distretto (`distrettoPerMedicoProvider`), area (`fasciaPrincipaleProvider[idMedico]?.idArea`). 
Separazione: `scaduti` (concordato/confermato con data passata, sfondo arancione) vs `futuri`. Ordinati per data/ora. Vista: ListTile con avatar specializzazione, stato badge, struttura/indirizzo/telefono.

Azioni:
- Stato "proposto": click → `_showConfermaDialog` → conferma → stato=confermato
- Stato non-proposto: click → `_showActionsDialog` (bottom sheet: Segna effettuato, Segna annullato, Modifica data/orario)
- App bar: icona date_range (range dialog), settings (max medici dialog), file_download (esporta Excel)

---

## 17. COSTANTI CHIAVE

```dart
AppConstants.appName = 'BIOGENA';
AppConstants.defaultTempoVisitaMinuti = 30;
AppConstants.defaultMaxAppuntamentiGiorno = 1; // usato nel medesimo file
```

- `_passoSlotMinuti = 15` (CalendarScheduler)
- `_maxIterazioniTotali = 50000` (CalendarScheduler)
- Theme seedColor: `Color(0xFF4ECDC4)` (teal)
- Material3: true
- CardTheme: elevation 2, borderRadius 16
- ChipTheme: borderRadius 12

---

## 18. SPECIALIZZAZIONI NOTE

Nomi nel sistema (da SpecializzazioneX.coloreSpecializzazione): Cardiologia, Dermatologia, Ortopedia, Pediatria, Ginecologia, Neurologia, Medicina Generale, Oculistica, Otorinolaringoiatria, Endocrinologia.
Icona mapping (da Specializzazione.fromJson): favorite, face_retouching_natural, child_care, accessibility_new, pregnant_woman, psychology, medical_services, visibility, hearing, water_drop, local_hospital (default).

---

## 19. ESTENSIONI UTILIZZATE

- `DateTimeX`: `dateOnly`, `isSameDay`, `addDays`, `isBeforeOrSameDay`, `formatItalia` (dd/MM/yyyy), `formatOrario` (HH:mm), `minutiDaMezzanotte`
- `TimeOfDayFormat`: `formatTime()` (HH:mm)
- `StatoCalendarioX` (on CalendarioAppuntamento): `isScaduto` (concordato/confermato + data passata + non concluso)
- `StatoAppuntamentoX` (on StatoAppuntamento): `label`, `isConcluso`
- `SpecializzazioneX`: `iconaSpecializzazione`, `coloreSpecializzazione` (per nome)
- `StatoCalendario` extension: `label`, `colore`

---

## 20. SCRIPT E STRUMENTI ESTERNI

- `scripts/`: contiene script Python per parsing Excel, geocoding, export, Firebase operations (`firebase_client.py`, `excel_parser.py`, `excel_time_utils.py`, `crea_aree_e_aggiorna_fasce.py`, etc.)
- `scripts/serviceAccountKey.json`: credenziali Firebase (ATTENZIONE: potrebbe contenere segreti)
- `scripts/geocode_cache.json`: cache geocoding
- `Elenco dottori 2025.xlsx`: Excel sorgente dati medici
- `lib.zip`: zip contenente librerie
- `scripts/export_informatorems.xlsx`, `export_informatorems_aree.xlsx`, `export_informatorems_geocodificato.xlsx`: file export

---

## 21. FILE NON PÙO INTELLIGENTI (BACKUP/LOG)

- `lib/core/models/fascia_oraria.dart.bak`: backup del modello FasciaOraria
- `flutter_01.log`: log di flutter
- `.dart_tool/`, `build/`, `.gradle/`: build artifacts (ignorare)

---

## 22. NOTA PER SVILUPPO FUTURO

1. `SyncService` ha i replay come stub (break in switch) — va implementato con repository reali
2. `ReportScreen` è placeholder — va sviluppato
3. `firebase_options.dart` non ha iOS/macOS/Linux configurati
4. Lo seeding (`seedDatabaseProvider`) è quasi tutto commentato — da riattivare per debug
5. Il file `firebase_seed.dart` è eseguibile con `dart run lib/data/seeds/firebase_seed.dart` (ha un main)
6. Il provider `medicifiltratiProvider` è stato creato ma non usato nelle schermate (tengono il filtraggio inline)
7. `StoricoAppuntamento` usa `StatoAppuntamento` (diverso da `StatoCalendario`) — attenzione alle mapping
8. `Appuntamento` e `CalendarioAppuntamento` sono due modelli separati con stati diversi — non confonderli
9. La periodicità mensile si deduce da giorni (28-31 o multipli di 30) — logica in `_aggiungiPeriodicita`
10. Le `fasceOrarie` con `deleted=true` sono filtrate lato applicativo (non a livello Firestore query) nel `getAll()`
