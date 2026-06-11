# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

App Flutter per calendario medico con Riverpod state management. Struttura a layer:

- **core/models** - Modelli dati (Medico, CalendarioAppuntamento, Zona, FasciaOraria)
- **data/repositories** - Repository pattern con implementazioni mock
- **data/providers** - Provider statici per dati iniziali
- **domain/usecases** - Caso d'uso (business logic)
- **domain/scheduler** - Generazione automatica appuntamenti basata su periodicità
- **presentation/providers** - Provider Riverpod per state management
- **presentation/screens** - Schermate UI
- **presentation/widgets** - Componenti riutilizzabili

## Key Patterns

**StatoCalendario**: proposto → confermato → concordato → fatto/annullato
- Proposto: generato dallo scheduler (periodicità del medico), non ancora confermato
- Confermato: confermato dall'utente ma non collegato all'anagrafata
- Concordato: collegato all'anagrafica medico tramite `calendarioAppuntamentoId`

**Riverpod Providers**:
- `calendarioProvider` è un FutureProvider che richiede `ref.watch(refreshTriggerProvider)` per forzare il refresh dopo operazioni di salvataggio
- `salvaAppuntamentoProvider` incrementa `refreshTriggerProvider` dopo il salvataggio
- Per errori "isConcluso method not found": il repository Firebase gestisce valori di stato non validi con fallback a `proposto`

## Development Commands

```bash
# Build and run
flutter run

# Analyze (lint)
flutter analyze

# Run tests
flutter test

# Run single test
flutter test --name "test_name"
```