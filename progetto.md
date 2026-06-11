# Piano di Sviluppo — App Calendario Appuntamenti Medici (Flutter)

## Contesto

Si sviluppa una nuova applicazione Flutter per la gestione di un calendario perpetuo di appuntamenti medici. Il sistema deve operare su un archivio di medici con dati anagrafici, specializzazione, indirizzo, periodicità appuntamento, zona di appartenenza collegata a una tabella zone, fascia oraria giornaliera di visitabilità e tempo stimato per l’appuntamento. Gli appuntamenti si ripetono in base alla periodicità stabilita, con gestione dinamica degli slittamenti e dei rinvii. L’architettura richiede separazione netta tra logica, dati e UI, persistenza su Firebase con cache locale offline, stato gestito con Riverpod, provider dati iniziali mock, e UI moderna ed accattivante.

---

## Fase 1 — Scaffolding Progetto e Architettura Layer

**Obiettivo:** Creare il progetto Flutter con struttura di cartelle a layer e dipendenze iniziali.

**Cartelle (non generare codice con build_runner):**
- `lib/core/` — modelli puri, costanti, extension, utilità.
- `lib/data/` — repository, provider dati, classi mock.
- `lib/domain/` — casi d’uso, logica di business, scheduler del calendario.
- `lib/presentation/` — widget, screen, provider/state notifier Riverpod.

**Dipendenze `pubspec.yaml` (solo pacchetti senza generazione di classi):**
- `flutter_riverpod` — stato.
- `freezed_annotation` + `json_serializable` solo se l’utente accetta build_runner; altrimenti POJO manuali. **Scelta architetturale corrente: modelli scritti manualmente, nessuna esecuzione di `build_runner`.**
- `cloud_firestore`, `firebase_core` — persistenza remota.
- `hive` o `shared_preferences` — cache locale semplice (opzionale, può essere aggiunto in fase 3).
- `intl`, `table_calendar`, `flutter_slidable` — UI calendario e interazioni.
- `uuid` per ID univoci.

**File critici da creare:**
- `lib/core/models/medico.dart` — modello Medico.
- `lib/core/models/zona.dart` — modello Zona.
- `lib/core/models/fascia_oraria.dart` — modello FasciaOraria.
- `lib/core/models/appuntamento.dart` — modello Appuntamento.
- `lib/core/models/storico_appuntamento.dart` — modello Storico.
- `lib/data/providers/mock_medico_provider.dart` — provider mock statico con dati di esempio.
- `lib/data/providers/mock_storico_provider.dart` — storico mock di esempio.

---

## Fase 2 — Modelli Dati (Sempre manuali, nessuna generazione)

**Requisito chiave:** il sorgente non deve contenere moduli che richiedano generazione di classi (`freezed`, `json_serializable` blocchi `@freezed`, classi `part`). Si scrivono classi Dart plain con `fromJson` / `toJson` manuali, `copyWith` scritti a mano se necessario, `==` e `hashCode` con `Equatable` (pacchetto leggero senza codice generato) oppure implementazione manuale.

**Schema entità:**

- `Zona`: `id`, `nome`, `colore` (per UI).
- `Medico`: `id`, `nome`, `specializzazione`, `indirizzo`, `zonaId`, `periodicitaGiorni` (int), `fasciaOraria` (lista di `FasciaOraria`), `tempoVisitaMinuti` (int), `maxAppuntamentiGiorno` (int = 1 come da risposta utente).
- `FasciaOraria`: `inizio` (`TimeOfDay` o minuti da mezzanotte), `fine`, `slotDisponibili` (int, per futura evoluzione, ora sempre 1).
- `Appuntamento`: `id`, `medicoId`, `dataOraInizio`, `dataOraFine`, `stato` (proposto, confermato, spostato, fatto, nonFatto), `note`.
- `StoricoAppuntamento`: `id`, `appuntamentoId` (o `medicoId` + `dataEseguita`), `stato`, `timestamp`.

**Business rules confermate dall’utente:**
1. Spostamento manuale di un appuntamento: le ricorrenze future partono dalla **nuova data** (ciclo continuo dal rinvio).
2. Appuntamento segnato come non fatto: **slittamento totale del ciclo**; il prossimo riparte dal “prima possibile” dopo la data scaduta.
3. Un medico ha **massimo 1 appuntamento al giorno** (indipendentemente dalle fasce).

---

## Fase 3 — Logica di Business / Domain Layer

**Componente chiave: `CalendarScheduler`**

Algoritmo di generazione del calendario perpetuo:

1. **Input:**
   - Lista medici filtrati per zone selezionate.
   - Intervallo futuro richiesto (start, end).
   - Storico appuntamenti conclusi.

2. **Inizializzazione dello stato di ogni medico:**
   - Determina la “prossima data candidata” per ogni medico.
   - Se esiste uno storico:
     - Ultimo appuntamento **fatto** → candidata = data eseguita + periodicità.
     - Ultimo appuntamento **non fatto** o **spostato** → candidata = prima data libera ≥ oggi rispettando il vincolo di non sovrapposizione e max 1/giorno.
     - Se c’è un appuntamento **manualmente prefissato** in futuro → quella data diventa l’ancoraggio; il calcolo della ricorrenza parte da lì.
   - Se non esiste storico → candidata = prima data ≥ oggi nella fascia oraria del medico.

3. **Generazione ricorrenze:**
   - A partire dalla candidata, genera appuntamenti ogni `periodicitaGiorni` fino a `end`.
   - Per ogni data:
     - Verifica che il medico non abbia già un appuntamento (proposto, confermato o spostato) in quella data (regola: max 1/giorno).
     - Verifica che la fascia oraria del medico sia disponibile (nessun’altra visita sovrapposta nello stesso slot orario, anche se il vincolo max 1/giorno rende la sovrapposizione difficile, resta necessario per multi-medico stessa fascia).
     - Assegna `dataOraInizio` e `dataOraFine = inizio + tempoVisitaMinuti`.
   - Se una data collide con un’altra visita già fissata (di un altro medico nella stessa fascia), sposta al giorno successivo valido (sempre rispettando la periodicità? NO: qui serve una decisione architetturale).

> **Domanda architetturale aperta / da verificare con utente:** se il giorno candidato è occupato da un altro appuntamento fisso in quella fascia, si slitta di 1 giorno (rompendo la periodicità esatta) o si salta quel “slot” e si attende il prossimo giorno valido della periodicità?
> **Scelta adottata nel piano:** slitta al giorno successivo valido, mantenendo l’intervallo di periodicità a partire dal giorno effettivamente assegnato. Esempio: periodicità 30gg, candidato 15 marzo occupato → assegna 16 marzo, prossimo sarà 16 marzo + 30gg. Questo allinea con la regola "ciclo continuo dal rinvio".

**Caso d’uso: `GeneraCalendarioUseCase`**
- Filtra medici per zone.
- Esegue `CalendarScheduler`.
- Restituisce lista `Appuntamento` entro il periodo richiesto.

**Caso d’uso: `SpostaAppuntamentoUseCase`**
- Riceve `appuntamentoId`, `nuovaDataOra`.
- Verifica disponibilità medico e sovrapposizioni.
- Aggiorna `Appuntamento.stato = spostato`.
- Salva in storico con flag.
- Ricalcola ricorrenze future a partire dalla nuova data.

**Caso d’uso: `RegistraEsitoAppuntamentoUseCase`**
- Riceve `appuntamentoId`, `esito` (fatto / nonFatto).
- Se `fatto`: prossima ricorrenza = data eseguita + periodicità.
- Se `nonFatto`: prossima ricorrenza = prima data libera ≥ oggi (slittamento totale ciclo).
- Scrive nello storico.

---

## Fase 4 — Data Layer (Mock → Firebase)

**Inizialmente (fase 4a — Mock):**
- `MedicoRepository` → implementazione `MockMedicoRepository` con lista hardcoded di 5-10 medici su 3 zone, con fasce orarie variate.
- `StoricoRepository` → implementazione `MockStoricoRepository` con alcuni appuntamenti passati fittizi.
- `AppuntamentoRepository` → gestisce in RAM la lista generata dallo scheduler, permette CRUD.

**Successivamente (fase 4b — Firebase):**
- `FirebaseMedicoRepository` legge da Firestore collection `medici`.
- `FirebaseStoricoRepository` legge/scrive collection `storico_appuntamenti`.
- `FirebaseAppuntamentoRepository` sincronizza in tempo reale `appuntamenti` (snapshot listener) con cache locale in Hive/SharedPreferences fallback se offline. Implementare logica di `pending sync` per operazioni fatte offline.

**Pattern:** Repository espongono `Either<Failure, T>` o semplici `AsyncValue` con Riverpod. Manteniamo interfaccia Repository astratta così lo switch mock → Firebase è a costo zero nel Domain/Presentation.

---

## Fase 5 — Stato con Riverpod

**Provider da implementare (tutti scritti manualmente, nessun `@riverpod`):**
- `mediciProvider` (`StateNotifier` o `AsyncNotifier`) — lista medici filtrati per zona.
- `zoneProvider` — lista zone.
- `calendarioProvider` — dipende da `mediciProvider`, `zoneSelezionateProvider`, `intervalloProvider`, `storicoProvider`.
- `appuntamentoDettaglioProvider` (family) — dettaglio singolo appuntamento.
- `storicoProvider` — lista storico.

**Approccio:** `StateNotifier<AsyncValue<List<Appuntamento>>>` con metodi espliciti `genera`, `sposta`, `registraEsito`. Riverpod gestisce la reattività; quando cambia lo storico o le zone, il calendario si rigenera automaticamente attraverso le dipendenze tra provider.

---

## Fase 6 — UI / Presentation Layer

**Screen principali:**
1. **Dashboard / Selezione Zone** — lista zone con toggle multiplo, chip colorati. Bottone "Genera Calendario".
2. **Vista Calendario** — `TableCalendar` (`table_calendar` pacchetto) customizzato con marker colorati per tipo medico/specializzazione. Giorni con slot liberi evidenziati diversamente da quelli pieni.
3. **Lista Appuntamenti del Giorno** — bottom sheet o pagina dedicata; elenco medici con orario, possibilità di slide-to-action (sposta/conferma/esito).
4. **Modale Spostamento** — date picker + selezione fascia oraria disponibile del medico con Highlight dei conflitti.
5. **Storico Medico** — timeline degli appuntamenti passati di quel medico con esiti.

**Librerie UI moderne:**
- Animazioni: `flutter_animate` (o scrivere manualmente con `AnimationController` per evitare dipendenze pesanti).
- Componenti: card con ombre sfumate, colori pastello per zone, icone specialità.
- Layout responsivo con `LayoutBuilder` o pacchetto `flutter_staggered_grid_view` se serve tablet.

---

## Fase 7 — Sincronizzazione Offline / Cache

**Strategia:**
- Riverpod tiene stato in memoria.
- Ogni modifica (`sposta`, `registraEsito`) viene scritta immediatamente in Firestore se online.
- Se offline: salva in coda locale (Hive box `pending_operations`).
- Alla riconnessione (listener `ConnectivityProvider` manuale con `connectivity_plus`), svuota coda locale su Firestore.
- Lettura iniziale: tenta Firestore → se fallisce/error, carica da cache locale (lista `appuntamenti` serializzata in JSON in Hive/SP).

---

## Fase 8 — Test e Polish

- Unit test per `CalendarScheduler` con scenari edge (periodicità, conflitti, spostamenti, non fatto).
- Widget test per flusso screen principali.
- Test di integrazione mock → verifica che switch a Firebase non rompa i casi d’uso.

---

## Albero File Chiave (fasi 1-6)

```
lib/
├── main.dart
├── core/
│   ├── constants.dart
│   ├── models/
│   │   ├── medico.dart
│   │   ├── zona.dart
│   │   ├── fascia_oraria.dart
│   │   ├── appuntamento.dart
│   │   └── storico_appuntamento.dart
│   └── extensions/
│       └── date_time_extension.dart
├── data/
│   ├── repositories/
│   │   ├── medico_repository.dart (abstract)
│   │   ├── mock_medico_repository.dart
│   │   ├── firebase_medico_repository.dart
│   │   ├── storico_repository.dart (abstract)
│   │   ├── mock_storico_repository.dart
│   │   └── firebase_storico_repository.dart
│   └── providers/
│       └── connectivity_provider.dart
├── domain/
│   ├── scheduler/
│   │   └── calendar_scheduler.dart
│   └── usecases/
│       ├── genera_calendario_usecase.dart
│       ├── sposta_appuntamento_usecase.dart
│       └── registra_esito_usecase.dart
└── presentation/
    ├── providers/
    │   ├── medici_provider.dart
    │   ├── zone_provider.dart
    │   ├── calendario_provider.dart
    │   └── zone_selezionate_provider.dart
    ├── screens/
    │   ├── dashboard_screen.dart
    │   ├── calendario_screen.dart
    │   └── storico_medico_screen.dart
    └── widgets/
        ├── zona_chip.dart
        ├── appuntamento_card.dart
        └── fascia_selector.dart
```

---


### Architettura Data Layer (Mock → Firebase)

Il passaggio da mock a Firebase è a costo zero nel resto dell’app perché:
- `MedicoRepository`, `StoricoRepository`, `AppuntamentoRepository`, `ZonaRepository` sono **interfacce astratte**.
- I provider Riverpod (`medicoRepositoryProvider`, `storicoRepositoryProvider`, `appuntamentoRepositoryProvider`) istanziano oggi i mock.
- **Per passare a Firebase**: cambiare solo quei 3 provider (es. `return FirebaseMedicoRepository();`).

### File chiave per riprendere lo sviluppo

| Scopo | Path |
|-------|------|
| Algoritmo scheduling | `lib/domain/scheduler/calendar_scheduler.dart` |
| Casi d’uso | `lib/domain/usecases/` |
| Provider Riverpod | `lib/presentation/providers/` |
| Schermate principali | `lib/presentation/screens/` |
| Widget UI | `lib/presentation/widgets/` |
| Mock dati | `lib/data/providers/mock_*.dart` |

### Domande residue aperte

1. Se il giorno candidato è occupato da un altro appuntamento fisso, va slittato di 1 giorno o saltato al prossimo ciclo periodico? *(Scelta attuale: slitta di 1gg, mantenendo periodicità dal giorno effettivo).*
2. Limite globale di appuntamenti per giorno (indipendentemente dal medico) o solo per-medico? *(Attuale: solo per-medico = 1).*
3. Giorni festivi / weekend da bloccare? *(Attuale: nessun blocco, 7gg/7).*
4. Multi-utente con Firebase Auth o single-user? *(Attuale: single-user implicito).*

---