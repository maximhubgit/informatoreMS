import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/fascia_oraria.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:uuid/uuid.dart';

/// Helper per gestire periodicita mensile.
/// Se la periodicita e 28-31 o multiplo di 30, si interpreta come "mesi".
DateTime _aggiungiPeriodicita(DateTime data, int periodicitaGiorni) {
  // Controlla se la periodicita rappresenta mesi (28-31 o multipli di ~30)
  bool isMensile = false;
  int mesi = 1;

  if (periodicitaGiorni >= 28 && periodicitaGiorni <= 31) {
    isMensile = true;
    mesi = (periodicitaGiorni / 30).round();
    mesi = mesi == 0 ? 1 : mesi;
  } else if (periodicitaGiorni >= 60) {
    // Multipli di ~30 (60, 90, 120...) diventano multipli di mesi
    final multiplo = periodicitaGiorni / 30;
    if (multiplo == multiplo.roundToDouble()) {
      isMensile = true;
      mesi = multiplo.round();
    }
  }

  if (isMensile) {
    // Aggiungi mesi mantenendo il giorno fisso
    int nuovoAnno = data.year;
    int nuovoMese = data.month + mesi;
    int giorno = data.day;

    while (nuovoMese > 12) {
      nuovoMese -= 12;
      nuovoAnno += 1;
    }

    // Gestisci il caso in cui il giorno non esiste nel nuovo mese
    final giorniNelNuovoMese = DateTime(nuovoAnno, nuovoMese + 1, 1).subtract(const Duration(days: 1)).day;
    giorno = giorno > giorniNelNuovoMese ? giorniNelNuovoMese : giorno;

    return DateTime(nuovoAnno, nuovoMese, giorno);
  }

  // Periodicita semplice in giorni
  return data.add(Duration(days: periodicitaGiorni));
}

class _Slot {
  final int inizio;
  final int fine;
  _Slot(this.inizio, this.fine);
}

class _SlotResult {
  final int orario;
  final int fasciaIndice;
  _SlotResult({required this.orario, required this.fasciaIndice});
}

class CalendarScheduler {
  static final _uuid = const Uuid();
  static const int _passoSlotMinuti = 15;

  CalendarScheduler();

  List<CalendarioAppuntamento> genera({
    required List<Medico> medici,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<CalendarioAppuntamento> esistenti,
    int maxMediciPerGiorno = 8,
    // Nuovo parametro: fasce orarie esterne alla tabella medici
    List<FasciaOraria> fasceOrarie = const [],
  }) {
    final occupazione = <DateTime, List<_Slot>>{};
    for (final a in esistenti) {
      final key = a.soloData.dateOnly;
      occupazione.putIfAbsent(key, () => []);
      occupazione[key]!.add(_Slot(
        a.data.hour * 60 + a.data.minute,
        a.data.hour * 60 + a.data.minute + 30,
      ));
    }

    final result = <CalendarioAppuntamento>[];
    final esistentiKeys = esistenti
        .map((e) =>
            '${e.medicoId}:${e.soloData.year}-${e.soloData.month}-${e.soloData.day}')
        .toSet();

    // Ordiniamo i medici per priorita:
    // 1. Medici con appuntamento concordato
    // 2. Medici con appuntamento proposto/concordato saltato
    // 3. Medici con appuntamento proposto nel futuro
    // 4. Tutti gli altri
    final mediciOrdinati = List<Medico>.from(medici)
      ..sort((a, b) {
        final aHasSaltato = esistenti.any((app) =>
            app.medicoId == a.id &&
            !app.stato.isConcluso &&
            app.stato != StatoCalendario.proposto &&
            app.soloData.isBefore(rangeStart));
        final bHasSaltato = esistenti.any((app) =>
            app.medicoId == b.id &&
            !app.stato.isConcluso &&
            app.stato != StatoCalendario.proposto &&
            app.soloData.isBefore(rangeStart));

        final aHasConcordato = esistenti.any((app) =>
            app.medicoId == a.id &&
            app.stato == StatoCalendario.concordato &&
            app.soloData.isAfter(rangeStart));
        final bHasConcordato = esistenti.any((app) =>
            app.medicoId == b.id &&
            app.stato == StatoCalendario.concordato &&
            app.soloData.isAfter(rangeStart));

        final aHasConfermato = esistenti.any((app) =>
            app.medicoId == a.id &&
            app.stato == StatoCalendario.confermato &&
            app.soloData.isAfter(rangeStart));
        final bHasConfermato = esistenti.any((app) =>
            app.medicoId == b.id &&
            app.stato == StatoCalendario.confermato &&
            app.soloData.isAfter(rangeStart));

        // Priorita massima: appuntamenti saltati
        if (aHasSaltato && !bHasSaltato) return -1;
        if (!aHasSaltato && bHasSaltato) return 1;

        // Poi: appuntamenti concordati
        if (aHasConcordato && !bHasConcordato) return -1;
        if (!aHasConcordato && bHasConcordato) return 1;

        // Poi: appuntamenti confermati
        if (aHasConfermato && !bHasConfermato) return -1;
        if (!aHasConfermato && bHasConfermato) return 1;

        return a.nome.compareTo(b.nome);
      });

    for (final medico in mediciOrdinati) {
      // Prendi le fasce orarie del medico dalla collection separata (esclude soft-delete)
      final fasceMedico = fasceOrarie.where((f) => f.idMedico == medico.id && !f.deleted).toList();

      DateTime candidata = _calcolaAncoraggio(medico: medico, esistenti: esistenti, rangeStart: rangeStart);

      while (candidata.isBefore(rangeEnd) || candidata.isAtSameMomentAs(rangeEnd)) {
        final numMediciGiorno = _contaMediciPerGiorno(result, candidata);
        if (numMediciGiorno >= maxMediciPerGiorno) {
          candidata = candidata.add(const Duration(days: 1));
          continue;
        }

        final key = '${medico.id}:${candidata.year}-${candidata.month}-${candidata.day}';
        if (esistentiKeys.contains(key)) {
          // Esiste gia un appuntamento per questo giorno, passa al successivo rispettando periodicita
          candidata = _aggiungiPeriodicita(candidata, medico.periodicitaGiorni);
          continue;
        }

        final slotResult = _trovaSlotLibero(medico, candidata, occupazione, fasceMedico);
        if (slotResult != null) {
          final giorno = candidata.dateOnly;
          final fasciaIndice = slotResult.fasciaIndice; // 0-based index
          result.add(CalendarioAppuntamento(
            id: _uuid.v4(),
            medicoId: medico.id,
            data: DateTime(giorno.year, giorno.month, giorno.day, slotResult.orario ~/ 60, slotResult.orario % 60),
            stato: StatoCalendario.proposto,
            dataCreazione: DateTime.now(),
            fasciaNumero: fasciaIndice + 1, // Numero progressivo a partire da 1
          ));
          // Usa tempoVisitaMinuti dalla fascia se specificato, altrimenti 30 di default
      final fasciaUtilizzata = fasceMedico.firstWhere((f) => f.nr == slotResult!.fasciaIndice + 1, orElse: () => fasceMedico.first);
      final durataVisita = fasciaUtilizzata.tempoVisitaMinuti ?? 30;

      occupazione.putIfAbsent(giorno, () => []).add(_Slot(slotResult.orario, slotResult.orario + durataVisita));
        } else {
          // Nessun slot disponibile per questa data (medico non riceve in questo giorno o tutti gli slot sono occupati)
          // Trova il prossimo giorno valido per il medico
          candidata = _trovaProssimoGiornoValido(medico, candidata, occupazione, rangeEnd, fasceMedico);
          continue;
        }

        candidata = _aggiungiPeriodicita(candidata, medico.periodicitaGiorni);
      }
    }

    return result;
  }

  int _contaMediciPerGiorno(List<CalendarioAppuntamento> generati, DateTime giorno) {
    return generati.where((a) => a.soloData.isSameDay(giorno)).length;
  }

  DateTime _calcolaAncoraggio({
    required Medico medico,
    required List<CalendarioAppuntamento> esistenti,
    required DateTime rangeStart,
  }) {
    // Prima controlla se c'e un appuntamento non concluso (confermato/concordato) NEL FUTURO
    final appuntamentiFuturi = esistenti
        .where((a) =>
            a.medicoId == medico.id &&
            !a.stato.isConcluso &&
            a.stato != StatoCalendario.proposto &&
            a.soloData.isAfter(rangeStart))
        .toList();

    if (appuntamentiFuturi.isNotEmpty) {
      appuntamentiFuturi.sort((a, b) => a.soloData.compareTo(b.soloData));
      return _aggiungiPeriodicita(appuntamentiFuturi.first.soloData, medico.periodicitaGiorni);
    }

    // Se c'e un appuntamento confermato/concordato nel PASSATO (saltato),
    // il medico va riorientato a partire da oggi
    final appuntamentiPassatiNonConclusi = esistenti
        .where((a) =>
            a.medicoId == medico.id &&
            !a.stato.isConcluso &&
            a.stato != StatoCalendario.proposto &&
            a.soloData.isBefore(rangeStart))
        .toList();

    if (appuntamentiPassatiNonConclusi.isNotEmpty) {
      // Appuntamento saltato - riproponi a partire da oggi
      return rangeStart;
    }

    // Se il medico ha gia un appuntamento prefissato nel calendario
    final appuntamentoPrefissato = esistenti.where(
        (a) => a.id == medico.calendarioAppuntamentoId).firstOrNull;

    if (appuntamentoPrefissato != null) {
      if (appuntamentoPrefissato.soloData.isAfter(rangeStart)) {
        return appuntamentoPrefissato.soloData;
      }
      // Se e nel passato, lo consideriamo come saltato
      return rangeStart;
    }

    // Altrimenti cerchiamo l'ultima visita conclusa o confermata (fatto/annullato/confermato/concordato)
    // Le visite confermate/conordate vengono usate come ancoraggio per le future ripetizioni
    final ultimi = esistenti
        .where((a) => a.medicoId == medico.id && (a.stato.isConcluso || a.stato == StatoCalendario.confermato || a.stato == StatoCalendario.concordato))
        .toList();
    if (ultimi.isNotEmpty) {
      ultimi.sort((a, b) => b.soloData.compareTo(a.soloData));
      final prossimaData = _aggiungiPeriodicita(ultimi.first.soloData, medico.periodicitaGiorni);
      return prossimaData.isBefore(rangeStart) ? rangeStart : prossimaData;
    }

    return rangeStart;
  }

  /// Trova il prossimo giorno in cui il medico ha disponibilità oraria.
  /// Cerca in avanti fino a maxDays ricerca o fino a rangeEnd, rispettando la periodicità.
  DateTime _trovaProssimoGiornoValido(
    Medico medico,
    DateTime dataPartenza,
    Map<DateTime, List<_Slot>> occupazione,
    DateTime rangeEnd,
    List<FasciaOraria> fasceMedico, {
    int maxDays = 90,
  }) {
    var giornoCorrente = dataPartenza.dateOnly;
    int giorniContati = 0;

    while ((giornoCorrente.isBefore(rangeEnd) || giornoCorrente.isAtSameMomentAs(rangeEnd)) && giorniContati < maxDays) {
      giorniContati++;

      // Controlla se il medico ha fasce orarie valide per questo giorno
      final hasFasceValide = fasceMedico.any((f) => f.isValidaPer(giornoCorrente));
      if (hasFasceValide) {
        return giornoCorrente;
      }

      // Passa al giorno successivo rispettando la periodicità
      giornoCorrente = _aggiungiPeriodicita(giornoCorrente, medico.periodicitaGiorni);
    }

    // Se non trova un giorno entro maxDays, torna al prossimo giorno (potrebbe non avere fasce)
    return giornoCorrente;
  }

  _SlotResult? _trovaSlotLibero(
    Medico medico,
    DateTime data,
    Map<DateTime, List<_Slot>> occupazione,
    List<FasciaOraria> fasceMedico,
  ) {
    // Filtra le fasce valide per il giorno specificato
    final fasceValide = fasceMedico.where((f) => f.isValidaPer(data)).toList();
    if (fasceValide.isEmpty) return null;

    final giorno = data.dateOnly;
    final occupati = occupazione[giorno] ?? [];

    for (var i = 0; i < fasceValide.length; i++) {
      final fascia = fasceValide[i];
      // Usa tempoVisitaMinuti dalla fascia se specificato, altrimenti 30 di default
      final durata = fascia.tempoVisitaMinuti ?? 30;
      for (var inizio = fascia.minutiInizio; inizio + durata <= fascia.minutiFine; inizio += _passoSlotMinuti) {
        final fine = inizio + durata;
        final conflitto = occupati.any((s) => !(fine <= s.inizio || inizio >= s.fine));
        if (!conflitto) {
          // Restituisci anche l'indice nella lista originale delle fasce
          final indiceOriginale = fasceMedico.indexOf(fascia);
          return _SlotResult(orario: inizio, fasciaIndice: indiceOriginale);
        }
      }
    }
    return null;
  }
}