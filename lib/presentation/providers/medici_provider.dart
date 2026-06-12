import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/fascia_oraria.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/data/repositories/fascia_oraria_repository.dart';
import 'package:informatoreMS/data/repositories/medico_repository.dart';
import 'package:informatoreMS/presentation/providers/zone_selezionate_provider.dart';

// Import con alias per evitare conflitti
import 'package:informatoreMS/data/repositories/remote/firebase_medico_repository.dart' as firebase;
import 'package:informatoreMS/data/repositories/remote/firebase_fascia_oraria_repository.dart' as firebase_fascia;

/// Repository wrapper per web che lancia errore se offline.
class _WebMedicoRepository implements MedicoRepository {
  final _firebaseRepo = firebase.FirebaseMedicoRepository();

  @override
  Future<List<Medico>> getAll() async {
    try {
      return await _firebaseRepo.getAll();
    } catch (e) {
      throw Exception('Errore caricamento medici: $e. Controlla la connessione.');
    }
  }

  @override
  Future<void> save(Medico medico) async {
    try {
      await _firebaseRepo.save(medico);
    } catch (e) {
      throw Exception('Connessione richiesta per salvare i dati.');
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

/// Provider del repository medici con logica:
/// - Web: solo Firebase (mostra errore se offline)
/// - Mobile: Firebase con persistenza offline integrata (si sincronizza automaticamente)
final medicoRepositoryProvider = Provider<MedicoRepository>((ref) {
  if (kIsWeb) {
    return _WebMedicoRepository();
  }
  return firebase.FirebaseMedicoRepository();
});

/// Provider che espone tutti i medici.
final mediciProvider = FutureProvider<List<Medico>>((ref) async {
  final repo = ref.watch(medicoRepositoryProvider);
  return repo.getAll();
});

/// Provider per salvare un medico.
final salvaMedicoProvider = Provider((ref) {
  return (Medico medico) async {
    final repo = ref.read(medicoRepositoryProvider);
    await repo.save(medico);
    ref.invalidate(mediciProvider);
  };
});

/// Provider per eliminare un medico.
final eliminaMedicoProvider = Provider((ref) {
  return (String id) async {
    final repo = ref.read(medicoRepositoryProvider);
    await repo.delete(id);
    ref.invalidate(mediciProvider);
  };
});

/// Repository wrapper per web che lancia errore se offline (per fasce orarie).
class _WebFasciaOrariaRepository implements FasciaOrariaRepository {
  final _firebaseRepo = firebase_fascia.FirebaseFasciaOrariaRepository();

  @override
  Future<List<FasciaOraria>> getByMedicoId(String medicoId) async {
    try {
      return await _firebaseRepo.getByMedicoId(medicoId);
    } catch (e) {
      throw Exception('Errore caricamento fasce: $e. Controlla la connessione.');
    }
  }

  @override
  Future<FasciaOraria?> getById(String id) async {
    try {
      return await _firebaseRepo.getById(id);
    } catch (e) {
      throw Exception('Errore nel caricamento fascia.');
    }
  }

  @override
  Future<void> save(FasciaOraria fascia) async {
    try {
      await _firebaseRepo.save(fascia);
    } catch (e) {
      throw Exception('Connessione richiesta per salvare i dati.');
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

  @override
  Future<void> deleteByMedicoId(String medicoId) async {
    try {
      await _firebaseRepo.deleteByMedicoId(medicoId);
    } catch (e) {
      throw Exception('Connessione richiesta per eliminare i dati.');
    }
  }
}

/// Provider del repository fasce orarie.
final fasciaOrariaRepositoryProvider = Provider<FasciaOrariaRepository>((ref) {
  if (kIsWeb) {
    return _WebFasciaOrariaRepository();
  }
  return firebase_fascia.FirebaseFasciaOrariaRepository();
});

/// Provider che espone tutte le fasce orarie.
final fasceOrarieProvider = FutureProvider<List<FasciaOraria>>((ref) async {
  final repo = ref.watch(fasciaOrariaRepositoryProvider);
  // Ottieni tutti i medici e poi le loro fasce
  final medici = ref.watch(mediciProvider).valueOrNull ?? [];
  final allFasce = <FasciaOraria>[];
  for (final medico in medici) {
    final fasce = await repo.getByMedicoId(medico.id);
    allFasce.addAll(fasce);
  }
  return allFasce;
});

/// Provider per salvare una fascia oraria.
final salvaFasciaOrariaProvider = Provider((ref) {
  return (FasciaOraria fascia) async {
    final repo = ref.read(fasciaOrariaRepositoryProvider);
    await repo.save(fascia);
    ref.invalidate(fasceOrarieProvider);
    ref.invalidate(mediciProvider); // Per rinfrescare
  };
});

/// Provider per eliminare una fascia oraria.
final eliminaFasciaOrariaProvider = Provider((ref) {
  return (String id) async {
    final repo = ref.read(fasciaOrariaRepositoryProvider);
    await repo.delete(id);
    ref.invalidate(fasceOrarieProvider);
  };
});

/// Provider per ottenere le fasce orarie di un medico specifico.
final fasceOrarieMedicoProvider = FutureProvider.family<List<FasciaOraria>, String>((ref, medicoId) async {
  final repo = ref.watch(fasciaOrariaRepositoryProvider);
  return repo.getByMedicoId(medicoId);
});

/// Provider che mappa fasciaOrariaId -> FasciaOraria.
/// Utile per recuperare struttura/indirizzo di un appuntamento in O(1).
final fasciaByIdProvider = Provider<Map<String, FasciaOraria>>((ref) {
  final fasceAsync = ref.watch(fasceOrarieProvider);
  final fasce = fasceAsync.valueOrNull ?? const <FasciaOraria>[];
  return {
    for (final f in fasce)
      if (f.id != null) f.id!: f,
  };
});

/// Provider derivato: medici filtrati per le zone selezionate.
/// Filtriamo in base alla zona della fascia principale (nr=0) del medico.
final mediciFiltratiProvider = Provider<AsyncValue<List<Medico>>>((ref) {
  final zoneSelezionate = ref.watch(zoneSelezionateProvider);
  final mediciAsync = ref.watch(mediciProvider);
  final fasceAsync = ref.watch(fasceOrarieProvider);

  return mediciAsync.when(
    data: (medici) {
      if (zoneSelezionate.isEmpty) return AsyncData(medici);
      // Costruisci un map medicoId -> zonaId della fascia principale
      final fasce = fasceAsync.valueOrNull ?? [];
      final zonaPerMedico = <String, String>{};
      for (final fascia in fasce.where((f) => f.nr == 0)) {
        zonaPerMedico[fascia.idMedico] = fascia.zonaId;
      }
      final filtrati = medici.where((m) => zoneSelezionate.contains(zonaPerMedico[m.id])).toList();
      return AsyncData(filtrati);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});