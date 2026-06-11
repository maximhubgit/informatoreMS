import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/fascia_oraria.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/data/repositories/calendario_repository.dart';
import 'package:informatoreMS/domain/scheduler/calendar_scheduler.dart';
import 'package:informatoreMS/presentation/providers/zone_selezionate_provider.dart';

// Import con alias per evitare conflitti
import 'package:informatoreMS/data/repositories/remote/firebase_calendario_repository.dart' as firebase;

// Import del provider medici
import 'package:informatoreMS/presentation/providers/medici_provider.dart' show mediciProvider, fasciaOrariaRepositoryProvider;

/// Provider per forzare il refresh del calendario
final refreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Repository wrapper per web che lancia errore se offline.
class _WebCalendarioRepository implements CalendarioRepository {
  final _firebaseRepo = firebase.FirebaseCalendarioRepository();

  @override
  Future<List<CalendarioAppuntamento>> getAll() async {
    try {
      return await _firebaseRepo.getAll();
    } catch (e) {
      throw Exception('Connessione richiesta. Ricollegati a internet per usare l\'app web.');
    }
  }

  @override
  Future<void> save(CalendarioAppuntamento appuntamento) async {
    try {
      await _firebaseRepo.save(appuntamento);
    } catch (e) {
      throw Exception('Connessione richiesta per salvare i dati.');
    }
  }

  @override
  Future<void> updateStato(String id, StatoCalendario nuovoStato) async {
    try {
      await _firebaseRepo.updateStato(id, nuovoStato);
    } catch (e) {
      throw Exception('Connessione richiesta per modificare lo stato.');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _firebaseRepo.delete(id);
    } catch (e) {
      throw Exception('Connessione richiesta per eliminare i dati.');
    }
  }
}

/// Provider del repository calendario con logica:
/// - Web: solo Firebase (mostra errore se offline)
/// - Mobile: Firebase con persistenza offline integrata
final calendarioRepositoryProvider = Provider<CalendarioRepository>((ref) {
  if (kIsWeb) {
    return _WebCalendarioRepository();
  }
  return firebase.FirebaseCalendarioRepository();
}, dependencies: []);

/// Provider per l'intervallo di generazione del calendario.
final calendarioRangeProvider =
    StateNotifierProvider<CalendarioRangeNotifier, (DateTime start, DateTime end)>(
  (ref) => CalendarioRangeNotifier(),
);

/// Provider per il numero massimo di medici per giorno.
final maxMediciPerGiornoProvider = StateProvider<int>((ref) => 8);

class MaxMediciNotifier extends StateNotifier<int> {
  MaxMediciNotifier() : super(8);
  void setMax(int value) => state = value;
}

class CalendarioRangeNotifier extends StateNotifier<(DateTime start, DateTime end)> {
  CalendarioRangeNotifier()
      : super((
          DateTime.now(),
          DateTime.now().add(const Duration(days: 90)),
        ));

  void setRange(DateTime start, DateTime end) => state = (start, end);

  void setStartDate(DateTime start) {
    final currentState = state;
    state = (start, currentState.$2);
  }

  void setWeeks(int settimane) {
    final currentState = state;
    state = (currentState.$1, currentState.$1.add(Duration(days: settimane * 7)));
  }
}

/// Provider che genera il calendario basato su medici filtrati,
/// range e appuntamenti esistenti nel calendario.
final calendarioProvider = FutureProvider<List<CalendarioAppuntamento>>((ref) async {
  // Watch refreshTrigger to force re-fetch after save operations
  ref.watch(refreshTriggerProvider);

  final medici = await ref.watch(mediciProvider.future);
  final zoneSelezionate = ref.watch(zoneSelezionateProvider);
  final range = ref.watch(calendarioRangeProvider);
  final calendarioRepo = ref.watch(calendarioRepositoryProvider);

  // Carica le fasce orarie prima del filtraggio
  final fasciaRepo = ref.watch(fasciaOrariaRepositoryProvider);
  final List<FasciaOraria> allFasce = [];
  for (final medico in medici) {
    try {
      final fasce = await fasciaRepo.getByMedicoId(medico.id);
      allFasce.addAll(fasce);
    } catch (_) {
      // Ignora errori individuali
    }
  }

  // Costruisci map medicoId -> zonaId della fascia principale (nr=0)
  final zonaPerMedico = <String, String>{};
  for (final fascia in allFasce.where((f) => f.nr == 0)) {
    zonaPerMedico[fascia.idMedico] = fascia.zonaId;
  }

  // Filtra i medici in base alla zona della loro fascia principale
  final mediciFiltrati = zoneSelezionate.isEmpty
      ? medici
      : medici.where((m) => zoneSelezionate.contains(zonaPerMedico[m.id])).toList();

  if (mediciFiltrati.isEmpty) return [];

  final esistenti = await calendarioRepo.getAll();

  final maxMedici = ref.watch(maxMediciPerGiornoProvider);
  final scheduler = CalendarScheduler();
  final generati = scheduler.genera(
    medici: mediciFiltrati,
    rangeStart: range.$1,
    rangeEnd: range.$2,
    esistenti: esistenti,
    maxMediciPerGiorno: maxMedici,
    fasceOrarie: allFasce,
  );

  // Merge: esistenti hanno precedenza sui generati
  // Mappa medicoId + data per gestire i duplicati
  final medicoPerData = <String, CalendarioAppuntamento>{};

  // Prima aggiungiamo quelli esistenti
  for (final app in esistenti) {
    final key = '${app.medicoId}:${app.soloData.year}-${app.soloData.month}-${app.soloData.day}';
    final prioritaStato = {
      StatoCalendario.fatto: 4,
      StatoCalendario.annullato: 3,
      StatoCalendario.concordato: 2,
      StatoCalendario.confermato: 1,
      StatoCalendario.proposto: 0,
    };
    final esistente = medicoPerData[key];
    if (esistente == null ||
        (prioritaStato[app.stato] ?? 0) > (prioritaStato[esistente.stato] ?? 0)) {
      medicoPerData[key] = app;
    }
  }

  // Poi aggiungiamo i generati solo se non esiste già un appuntamento concordato/confermato per quel giorno
  for (final g in generati) {
    // Non aggiungere se esiste già un appuntamento concordato/confermato per lo stesso medico nello stesso giorno
    final key = '${g.medicoId}:${g.soloData.year}-${g.soloData.month}-${g.soloData.day}';
    final esisteConcordato = medicoPerData.values.any((a) =>
        a.medicoId == g.medicoId &&
        a.soloData.isAtSameMomentAs(g.soloData) &&
        (a.stato == StatoCalendario.concordato || a.stato == StatoCalendario.confermato));

    if (!esisteConcordato && !medicoPerData.containsKey(key)) {
      medicoPerData[key] = g;
    }
  }

  return medicoPerData.values.toList();
});

/// Provider per salvare un appuntamento nel calendario.
final salvaAppuntamentoProvider = Provider((ref) {
  return (CalendarioAppuntamento appuntamento) async {
    final repo = ref.read(calendarioRepositoryProvider);
    await repo.save(appuntamento);
    // Forza refresh incrementando il trigger
    ref.read(refreshTriggerProvider.notifier).update((v) => v + 1);
  };
});

/// Provider per confermare un appuntamento (cambia stato da proposto a confermato).
final confermaAppuntamentoProvider = Provider((ref) {
  return (String id) async {
    final repo = ref.read(calendarioRepositoryProvider);
    await repo.updateStato(id, StatoCalendario.confermato);
    ref.refresh(calendarioProvider);
  };
});

/// Provider che mappa medicoId -> Medico.
final medicoByIdProvider = Provider<Map<String, Medico>>((ref) {
  final async = ref.watch(mediciProvider);
  return {
    for (final m in (async.valueOrNull ?? [])) m.id: m,
  };
});

/// Provider family: appuntamenti calendario per un medico specifico.
final appuntamentiPerMedicoProvider = Provider.autoDispose
    .family<List<CalendarioAppuntamento>, String>((ref, medicoId) {
  final calendarioAsync = ref.watch(calendarioProvider);
  return calendarioAsync.when(
    data: (lista) => lista
        .where((a) => a.medicoId == medicoId)
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data)),
    loading: () => <CalendarioAppuntamento>[],
    error: (_, __) => <CalendarioAppuntamento>[],
  );
});

/// Provider family per gli appuntamenti di una specifica data.
final appuntamentiDelGiornoProvider = Provider.autoDispose
    .family<List<CalendarioAppuntamento>, DateTime>((ref, data) {
  final calendarioAsync = ref.watch(calendarioProvider);
  return calendarioAsync.when(
    data: (lista) {
      final giorno = DateTime(data.year, data.month, data.day);
      return lista.where((a) => a.soloData.isAtSameMomentAs(giorno)).toList()
        ..sort((a, b) => a.data.compareTo(b.data));
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Modello per i contatori appuntamenti di un giorno.
class ContatoriGiorno {
  final int proposti;
  final int confermati;
  final int concordati;

  const ContatoriGiorno({
    this.proposti = 0,
    this.confermati = 0,
    this.concordati = 0,
  });

  int get totaleConfermati => confermati + concordati;

  ContatoriGiorno copyWith({int? proposti, int? confermati, int? concordati}) {
    return ContatoriGiorno(
      proposti: proposti ?? this.proposti,
      confermati: confermati ?? this.confermati,
      concordati: concordati ?? this.concordati,
    );
  }
}

/// Provider per contare gli appuntamenti per giorno nel mese visualizzato.
final contatoriPerMeseProvider = Provider<Map<DateTime, ContatoriGiorno>>((ref) {
  final calendarioAsync = ref.watch(calendarioProvider);
  final Map<DateTime, ContatoriGiorno> contatori = {};

  calendarioAsync.when(
    data: (lista) {
      for (final app in lista) {
        final key = DateTime(app.soloData.year, app.soloData.month, app.soloData.day);
        final corrente = contatori[key] ?? const ContatoriGiorno();

        final nuovo = switch (app.stato) {
          StatoCalendario.proposto => corrente.copyWith(proposti: corrente.proposti + 1),
          StatoCalendario.confermato => corrente.copyWith(confermati: corrente.confermati + 1),
          StatoCalendario.concordato => corrente.copyWith(concordati: corrente.concordati + 1),
          StatoCalendario.fatto || StatoCalendario.annullato => corrente,
        };
        contatori[key] = nuovo;
      }
    },
    loading: () {},
    error: (_, __) {},
  );

  return contatori;
});

/// Provider family per i contatori di un giorno specifico.
final contatoreDelGiornoProvider = Provider.autoDispose
    .family<ContatoriGiorno, DateTime>((ref, data) {
  final contatori = ref.watch(contatoriPerMeseProvider);
  final key = DateTime(data.year, data.month, data.day);
  return contatori[key] ?? const ContatoriGiorno();
});

/// Provider per eliminare un appuntamento dal calendario.
final eliminaAppuntamentoProvider = Provider((ref) {
  return (String id) async {
    final repo = ref.read(calendarioRepositoryProvider);
    await repo.delete(id);
    ref.refresh(calendarioProvider);
  };
});
