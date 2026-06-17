import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/distretto.dart';
import 'package:informatoreMS/data/repositories/distretto_repository.dart';
import 'package:informatoreMS/data/repositories/remote/firebase_distretto_repository.dart' as firebase;

/// Repository Firebase per i distretti (import esplicito per evitare ambiguità).
class _WebDistrettoRepository implements DistrettoRepository {
  final _firebaseRepo = firebase.FirebaseDistrettoRepository();

  @override
  Future<List<Distretto>> getAll() async {
    try {
      return await _firebaseRepo.getAll();
    } catch (e) {
      throw Exception('Connessione richiesta. Ricollegati a internet per usare l\'app web.');
    }
  }

  @override
  Future<void> save(Distretto distretto) async {
    await _firebaseRepo.save(distretto);
  }

  @override
  Future<void> delete(int codice) async {
    await _firebaseRepo.delete(codice);
  }

  @override
  Future<List<Distretto>> getByAsl(int codiceAsl) async {
    return await _firebaseRepo.getByAsl(codiceAsl);
  }
}

/// Provider del repository distretti con logica:
/// - Web: solo Firebase (mostra errore se offline)
/// - Mobile: Firebase con persistenza offline integrata
final distrettoRepositoryProvider = Provider<DistrettoRepository>((ref) {
  if (kIsWeb) {
    return _WebDistrettoRepository();
  }
  return firebase.FirebaseDistrettoRepository();
});

/// Provider che espone la lista dei distretti.
final distrettoProvider = FutureProvider<List<Distretto>>((ref) async {
  final repo = ref.watch(distrettoRepositoryProvider);
  return repo.getAll();
});

/// Provider che mappa codice -> Distretto.
final distrettoByCodiceProvider = Provider<Map<int, Distretto>>((ref) {
  final async = ref.watch(distrettoProvider);
  return {
    for (final d in (async.valueOrNull ?? [])) d.codice: d,
  };
});

/// Provider per ottenere i distretti filtrati per ASL.
final distrettiByAslProvider = Provider((ref) {
  return (int codiceAsl) {
    final distretti = ref.watch(distrettoProvider);
    return distretti.when(
      data: (list) => list.where((d) => d.codiceAsl == codiceAsl).toList(),
      loading: () => <Distretto>[],
      error: (_, __) => <Distretto>[],
    );
  };
});

/// Provider per salvare un distretto.
final salvaDistrettoProvider = Provider((ref) {
  return (Distretto distretto) async {
    final db = FirebaseFirestore.instance;
    await db.collection('distretti').doc(distretto.codice.toString()).set({
      'codice': distretto.codice,
      'descrizione': distretto.descrizione,
      'codiceAsl': distretto.codiceAsl,
    });
    ref.invalidate(distrettoProvider);
  };
});

/// Provider per eliminare un distretto.
final eliminaDistrettoProvider = Provider((ref) {
  return (int codice) async {
    final db = FirebaseFirestore.instance;
    await db.collection('distretti').doc(codice.toString()).delete();
    ref.invalidate(distrettoProvider);
  };
});