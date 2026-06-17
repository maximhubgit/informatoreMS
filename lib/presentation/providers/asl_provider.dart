import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/asl.dart';
import 'package:informatoreMS/data/repositories/asl_repository.dart';
import 'package:informatoreMS/data/repositories/remote/firebase_asl_repository.dart' as firebase;

/// Repository Firebase per le ASL (import esplicito per evitare ambiguità).
class _WebAslRepository implements AslRepository {
  final _firebaseRepo = firebase.FirebaseAslRepository();

  @override
  Future<List<Asl>> getAll() async {
    try {
      return await _firebaseRepo.getAll();
    } catch (e) {
      throw Exception('Connessione richiesta. Ricollegati a internet per usare l\'app web.');
    }
  }

  @override
  Future<void> save(Asl asl) async {
    await _firebaseRepo.save(asl);
  }

  @override
  Future<void> delete(int codice) async {
    await _firebaseRepo.delete(codice);
  }
}

/// Provider del repository ASL con logica:
/// - Web: solo Firebase (mostra errore se offline)
/// - Mobile: Firebase con persistenza offline integrata
final aslRepositoryProvider = Provider<AslRepository>((ref) {
  if (kIsWeb) {
    return _WebAslRepository();
  }
  return firebase.FirebaseAslRepository();
});

/// Provider che espone la lista delle ASL.
final aslProvider = FutureProvider<List<Asl>>((ref) async {
  final repo = ref.watch(aslRepositoryProvider);
  return repo.getAll();
});

/// Provider che mappa codice -> Asl.
final aslByCodiceProvider = Provider<Map<int, Asl>>((ref) {
  final async = ref.watch(aslProvider);
  return {
    for (final a in (async.valueOrNull ?? [])) a.codice: a,
  };
});

/// Provider per salvare un'ASL.
final salvaAslProvider = Provider((ref) {
  return (Asl asl) async {
    final db = FirebaseFirestore.instance;
    await db.collection('asl').doc(asl.codice.toString()).set({
      'codice': asl.codice,
      'descrizione': asl.descrizione,
    });
    ref.invalidate(aslProvider);
  };
});

/// Provider per eliminare un'ASL.
final eliminaAslProvider = Provider((ref) {
  return (int codice) async {
    final db = FirebaseFirestore.instance;
    await db.collection('asl').doc(codice.toString()).delete();
    ref.invalidate(aslProvider);
  };
});