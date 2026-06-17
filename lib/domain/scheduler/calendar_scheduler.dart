import 'package:flutter/foundation.dart' show debugPrint;
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

  /// Cap di sicurezza per evitare loop infiniti: se lo scheduler non termina
  /// entro questo numero di iterazioni del while loop principale, si ferma.
  /// Con 204 medici, 90 giorni e periodicita 30, il numero di iterazioni
  /// atteso è ~3 per medico × 204 = ~600. 50000 è un margine ampio.
  static const int _maxIterazioniTotali = 50000;

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
    // === PRE-CALCOLO: raggruppa esistenti e fasce per medicoId UNA SOLA VOLTA ===
    // Senza queste mappe, il codice faceva scan lineari multipli ad ogni
    // iterazione: con 204 medici e migliaia di esistenti, il main thread
    // restava bloccato per decine di secondi.
    final esistentiPerMedico = <String, List<CalendarioAppuntamento>>{};
    for (final e in esistenti) {
      (esistentiPerMedico[e.medicoId] ??= <CalendarioAppuntamento>[]).add(e);
    }

    final fascePerMedico = <String, List<FasciaOraria>>{};
    for (final f in fasceOrarie) {
      if (!f.deleted) {
        (fascePerMedico[f.idMedico] ??= <FasciaOraria>[]).add(f);
      }
    }

    // Set delle chiavi "medicoId:YYYY-M-D" per lookup O(1) sui conflitti data-medico.
    final esistentiKeys = <String>{};
    for (final e in esistenti) {
      esistentiKeys.add(
          '${e.medicoId}:${e.soloData.year}-${e.soloData.month}-${e.soloData.day}');
    }

    // === OCCUPAZIONE: mappa giorno -> lista slot occupati (per il while loop) ===
    final occupazione = <DateTime, List<_Slot>>{};
    for (final a in esistenti) {
      final key = a.soloData.dateOnly;
      occupazione.putIfAbsent(key, () => []).add(_Slot(
            a.data.hour * 60 + a.data.minute,
            a.data.hour * 60 + a.data.minute + 30,
          ));
    }

    // === CONTATORE: mappa giorno -> numero medici già generati per quel giorno ===
    // Permette di controllare maxMediciPerGiorno in O(1) invece di O(generati).
    final mediciPerGiorno = <DateTime, int>{};

    final result = <CalendarioAppuntamento>[];

    // === PRE-CALCOLO FLAG DI PRIORITÀ per il sort: O(medici) confronti O(1) ===
    // Il vecchio codice chiamava 6 `.any()` su `esistenti` ad ogni confronto
    // del sort → O(N log N × esistenti) chiamate. Con 204 medici e migliaia
    // di esistenti erano milioni di iterazioni bloccanti.
    final flags = <String, _MedicoFlags>{};
    for (final m in medici) {
      final apps = esistentiPerMedico[m.id] ?? const <CalendarioAppuntamento>[];
      bool hasSaltato = false;
      bool hasConcordato = false;
      bool hasConfermato = false;
      for (final a in apps) {
        if (!hasSaltato &&
            !a.stato.isConcluso &&
            a.stato != StatoCalendario.proposto &&
            a.soloData.isBefore(rangeStart)) {
          hasSaltato = true;
        }
        if (!hasConcordato &&
            a.stato == StatoCalendario.concordato &&
            a.soloData.isAfter(rangeStart)) {
          hasConcordato = true;
        }
        if (!hasConfermato &&
            a.stato == StatoCalendario.confermato &&
            a.soloData.isAfter(rangeStart)) {
          hasConfermato = true;
        }
        // Short-circuit se tutti i flag sono già veri
        if (hasSaltato && hasConcordato && hasConfermato) break;
      }
      flags[m.id] = _MedicoFlags(hasSaltato, hasConcordato, hasConfermato);
    }

    // === SORT: O(N log N) confronti O(1) usando i flag pre-calcolati ===
    final mediciOrdinati = List<Medico>.from(medici)
      ..sort((a, b) {
        final fa = flags[a.id]!;
        final fb = flags[b.id]!;
        if (fa.hasSaltato != fb.hasSaltato) return fa.hasSaltato ? -1 : 1;
        if (fa.hasConcordato != fb.hasConcordato) {
          return fa.hasConcordato ? -1 : 1;
        }
        if (fa.hasConfermato != fb.hasConfermato) {
          return fa.hasConfermato ? -1 : 1;
        }
        return a.nome.compareTo(b.nome);
      });

    // Contatore globale di iterazioni del while loop principale: se supera
    // _maxIterazioniTotali usciamo per evitare di bloccare la UI per sempre.
    int iterazioniTotali = 0;

    for (final medico in mediciOrdinati) {
      if (iterazioniTotali >= _maxIterazioniTotali) break;

      // Lookup O(1) invece di fasceOrarie.where(...).toList() ad ogni iterazione
      final fasceMedico = fascePerMedico[medico.id] ?? const <FasciaOraria>[];

      // Difesa contro periodicitaGiorni <= 0 che causerebbe loop infinito
      // nel while (la data non avanzerebbe mai). Default: 30 giorni.
      final periodicita =
          medico.periodicitaGiorni > 0 ? medico.periodicitaGiorni : 30;

      DateTime candidata = _calcolaAncoraggio(
        medico: medico,
        esistentiPerMedico: esistentiPerMedico,
        rangeStart: rangeStart,
      );

      while (candidata.isBefore(rangeEnd) || candidata.isAtSameMomentAs(rangeEnd)) {
        iterazioniTotali++;
        if (iterazioniTotali >= _maxIterazioniTotali) {
          debugPrint(
              'CalendarScheduler: raggiunto cap di $_maxIterazioniTotali iterazioni, terminazione anticipata. '
              'Medici processati parzialmente.');
          break;
        }

        // O(1) invece di generati.where(...).length
        final numMediciGiorno = mediciPerGiorno[candidata.dateOnly] ?? 0;
        if (numMediciGiorno >= maxMediciPerGiorno) {
          candidata = candidata.add(const Duration(days: 1));
          continue;
        }

        final key = '${medico.id}:${candidata.year}-${candidata.month}-${candidata.day}';
        if (esistentiKeys.contains(key)) {
          // Esiste gia un appuntamento per questo giorno, passa al successivo rispettando periodicita
          candidata = _aggiungiPeriodicita(candidata, periodicita);
          continue;
        }

        final slotResult = _trovaSlotLibero(medico, candidata, occupazione, fasceMedico);
        if (slotResult != null) {
          final giorno = candidata.dateOnly;
          final fasciaIndice = slotResult.fasciaIndice; // 0-based index
          // Trova la fascia utilizzata per ottenere l'ID
          final fasciaUtilizzata = fasceMedico.firstWhere(
              (f) => f.nr == slotResult.fasciaIndice + 1,
              orElse: () => fasceMedico.isNotEmpty ? fasceMedico.first : _fasciaVuota);
          final durataVisita = fasciaUtilizzata.tempoVisitaMinuti ?? 30;

          result.add(CalendarioAppuntamento(
            id: _uuid.v4(),
            medicoId: medico.id,
            data: DateTime(giorno.year, giorno.month, giorno.day, slotResult.orario ~/ 60, slotResult.orario % 60),
            stato: StatoCalendario.proposto,
            dataCreazione: DateTime.now(),
            fasciaNumero: fasciaIndice + 1, // Numero progressivo a partire da 1
            fasciaOrariaId: fasciaUtilizzata.id, // ID della fascia oraria
          ));

          occupazione.putIfAbsent(giorno, () => []).add(_Slot(slotResult.orario, slotResult.orario + durataVisita));
          mediciPerGiorno[giorno] = numMediciGiorno + 1;
        } else {
          // Nessun slot disponibile per questa data (medico non riceve in questo giorno o tutti gli slot sono occupati)
          // Trova il prossimo giorno valido per il medico
          final prossimo = _trovaProssimoGiornoValido(medico, candidata, occupazione, rangeEnd, fasceMedico);
          // Difesa: se per qualche motivo prossimo <= candidata, forziamo +1 giorno
          // per evitare loop infinito
          if (!prossimo.isAfter(candidata)) {
            candidata = candidata.add(const Duration(days: 1));
          } else {
            candidata = prossimo;
          }
          continue;
        }

        candidata = _aggiungiPeriodicita(candidata, periodicita);
      }

      if (iterazioniTotali >= _maxIterazioniTotali) break;
    }

    return result;
  }

  // Placeholder usato solo se un medico finisce in una situazione anomala
  // (slot trovato ma fasceMedico vuote): evita il crash del `firstWhere`.
  static final _fasciaVuota = FasciaOraria(
    idMedico: '',
    nr: 0,
    minutiInizio: 0,
    minutiFine: 0,
    distrettoId: 0,
    zonaId: '',
  );

  DateTime _calcolaAncoraggio({
    required Medico medico,
    required Map<String, List<CalendarioAppuntamento>> esistentiPerMedico,
    required DateTime rangeStart,
  }) {
    final apps = esistentiPerMedico[medico.id] ?? const <CalendarioAppuntamento>[];

    // Prima controlla se c'e un appuntamento non concluso (confermato/concordato) NEL FUTURO
    CalendarioAppuntamento? futuroPiuVicino;
    CalendarioAppuntamento? passatoNonConcluso;
    CalendarioAppuntamento? ultimoConclusoOConfermato;
    for (final a in apps) {
      if (!a.stato.isConcluso && a.stato != StatoCalendario.proposto) {
        if (a.soloData.isAfter(rangeStart)) {
          if (futuroPiuVicino == null ||
              a.soloData.isBefore(futuroPiuVicino.soloData)) {
            futuroPiuVicino = a;
          }
        } else {
          passatoNonConcluso ??= a;
        }
      }
      if (a.stato.isConcluso ||
          a.stato == StatoCalendario.confermato ||
          a.stato == StatoCalendario.concordato) {
        if (ultimoConclusoOConfermato == null ||
            a.soloData.isAfter(ultimoConclusoOConfermato.soloData)) {
          ultimoConclusoOConfermato = a;
        }
      }
    }

    if (futuroPiuVicino != null) {
      return _aggiungiPeriodicita(
          futuroPiuVicino.soloData, medico.periodicitaGiorni);
    }

    // Se c'e un appuntamento confermato/concordato nel PASSATO (saltato),
    // il medico va riorientato a partire da oggi
    if (passatoNonConcluso != null) {
      return rangeStart;
    }

    // Se il medico ha gia un appuntamento prefissato nel calendario
    final prefissatoId = medico.calendarioAppuntamentoId;
    if (prefissatoId != null) {
      for (final a in apps) {
        if (a.id == prefissatoId) {
          if (a.soloData.isAfter(rangeStart)) return a.soloData;
          return rangeStart;
        }
      }
    }

    // Altrimenti cerchiamo l'ultima visita conclusa o confermata (fatto/annullato/confermato/concordato)
    if (ultimoConclusoOConfermato != null) {
      final prossimaData = _aggiungiPeriodicita(
          ultimoConclusoOConfermato.soloData, medico.periodicitaGiorni);
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

      // Cerca il prossimo giorno con fasce valide (+1 per volta).
      // La periodicità si applica DOPO che uno slot è stato generato (vedi
      // while loop principale), NON durante la ricerca: se il medico riceve
      // solo il mercoledì e oggi è martedì, va proposto mercoledì (domani),
      // non mercoledì + 30. La vecchia logica applicava la periodicità qui,
      // sbalzando via di un mese i medici il cui candidato cadeva nel weekend
      // o in un giorno non lavorativo.
      giornoCorrente = giornoCorrente.add(const Duration(days: 1));
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
    final occupati = occupazione[giorno] ?? const <_Slot>[];

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

/// Flag di priorità pre-calcolati per ogni medico, usati dal sort.
/// Tenerli in una struttura dati separata permette il sort in O(N log N)
/// con confronti O(1) invece di O(N log N × esistenti).
class _MedicoFlags {
  final bool hasSaltato;
  final bool hasConcordato;
  final bool hasConfermato;
  const _MedicoFlags(this.hasSaltato, this.hasConcordato, this.hasConfermato);
}