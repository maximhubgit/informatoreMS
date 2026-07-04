import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/distretto.dart';
import 'package:informatoreMS/presentation/providers/distretto_provider.dart';
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
/// - Mobile/Desktop: Firebase (la persistenza offline è gestita da Firestore SDK)
final medicoRepositoryProvider = Provider<MedicoRepository>((ref) {
  if (kIsWeb) {
    return _WebMedicoRepository();
  }
  return firebase.FirebaseMedicoRepository();
}, dependencies: []);

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
  Future<List<FasciaOraria>> getAll() async {
    try {
      return await _firebaseRepo.getAll();
    } catch (e) {
      throw Exception('Errore caricamento fasce: $e. Controlla la connessione.');
    }
  }

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
}, dependencies: []);

/// Provider che espone tutte le fasce orarie.
///
/// Esegue una singola query Firestore invece di N query separate per
/// ciascun medico: con 204 medici il vecchio pattern N+1 causava freeze
/// di 30+ secondi all'avvio.
final fasceOrarieProvider = FutureProvider<List<FasciaOraria>>((ref) async {
  final repo = ref.watch(fasciaOrariaRepositoryProvider);
  return repo.getAll();
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

/// Mappa memoizzata medicoId -> zonaId della fascia principale (nr=0).
/// Calcolata una sola volta per render, evita di filtrare tutte le fasce
/// in ogni widget che necessita di questa associazione.
final zonaPerMedicoProvider = Provider<Map<String, String>>((ref) {
  final fasceAsync = ref.watch(fasceOrarieProvider);
  final fasce = fasceAsync.valueOrNull ?? const <FasciaOraria>[];
  return {
    for (final f in fasce)
      if (f.nr == 0) f.idMedico: f.zonaId,
  };
});

/// Mappa memoizzata medicoId -> FasciaOraria principale (nr=0).
/// Lookup O(1) per evitare di scorrere tutte le fasce in ogni tile.
final fasciaPrincipaleProvider = Provider<Map<String, FasciaOraria>>((ref) {
  final fasceAsync = ref.watch(fasceOrarieProvider);
  final fasce = fasceAsync.valueOrNull ?? const <FasciaOraria>[];
  return {
    for (final f in fasce)
      if (f.nr == 0) f.idMedico: f,
  };
});

/// Mappa memoizzata medicoId -> Distretto della fascia principale (nr=0).
/// Utile per filtri e ordinamento basati su distretto.
final distrettoPerMedicoProvider = Provider<Map<String, Distretto>>((ref) {
  final fasceAsync = ref.watch(fasceOrarieProvider);
  final fasce = fasceAsync.valueOrNull ?? const <FasciaOraria>[];
  final distrettoByCodice = ref.watch(distrettoByCodiceProvider);
  return {
    for (final f in fasce)
      if (f.nr == 0) f.idMedico: distrettoByCodice[f.distrettoId] ?? const Distretto(
        codice: 0,
        nrDistretto: 0,
        descrizione: 'Sconosciuto',
        codiceAsl: 0,
      ),
  };
});

/// Provider derivato: medici filtrati per le zone selezionate.
/// Filtriamo in base alla zona della fascia principale (nr=0) del medico.
final mediciFiltratiProvider = Provider<AsyncValue<List<Medico>>>((ref) {
  final zoneSelezionate = ref.watch(zoneSelezionateProvider);
  final mediciAsync = ref.watch(mediciProvider);
  final zonaPerMedico = ref.watch(zonaPerMedicoProvider);

  return mediciAsync.when(
    data: (medici) {
      if (zoneSelezionate.isEmpty) return AsyncData(medici);
      final filtrati = medici
          .where((m) => zoneSelezionate.contains(zonaPerMedico[m.id]))
          .toList();
      return AsyncData(filtrati);
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});