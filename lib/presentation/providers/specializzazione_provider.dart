import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/specializzazione.dart';
import 'package:informatoreMS/data/repositories/specializzazione_repository.dart';

// Import con alias per evitare conflitti
import 'package:informatoreMS/data/repositories/remote/firebase_specializzazione_repository.dart' as firebase;

/// Repository wrapper per web che lancia errore se offline.
class _WebSpecializzazioneRepository implements SpecializzazioneRepository {
  final _firebaseRepo = firebase.FirebaseSpecializzazioneRepository();

  @override
  Future<List<Specializzazione>> getAll() async {
    try {
      return await _firebaseRepo.getAll();
    } catch (e) {
      if (e.toString().contains('offline') || e.toString().contains('network')) {
        throw Exception('Connessione richiesta. Ricollegati a internet per usare l\'app web.');
      }
      // Rilancia altri errori
      rethrow;
    }
  }
}

/// Provider del repository specializzazioni con logica:
/// - Web: solo Firebase (mostra errore se offline)
/// - Mobile: Firebase con persistenza offline integrata
final specializzazioneRepositoryProvider = Provider<SpecializzazioneRepository>((ref) {
  if (kIsWeb) {
    return _WebSpecializzazioneRepository();
  }
  return firebase.FirebaseSpecializzazioneRepository();
});

/// Provider che espone la lista delle specializzazioni.
final specializzazioneProvider = FutureProvider<List<Specializzazione>>((ref) async {
  final repo = ref.watch(specializzazioneRepositoryProvider);
  return repo.getAll();
});

/// Provider per salvare una specializzazione.
final salvaSpecializzazioneProvider = Provider((ref) {
  return (Specializzazione spec) async {
    final db = FirebaseFirestore.instance;
    await db.collection('specializzazioni').doc(spec.id).set({
      'nome': spec.nome,
    });
    ref.refresh(specializzazioneProvider);
  };
});

/// Provider per aggiornare una specializzazione.
final aggiornaSpecializzazioneProvider = Provider((ref) {
  return (Specializzazione spec) async {
    final db = FirebaseFirestore.instance;
    await db.collection('specializzazioni').doc(spec.id).update({
      'nome': spec.nome,
    });
    ref.refresh(specializzazioneProvider);
  };
});

/// Provider che mappa specializzazioneId -> Specializzazione.
final specializzazioneByIdProvider = Provider<Map<String, Specializzazione>>((ref) {
  final async = ref.watch(specializzazioneProvider);
  return {
    for (final s in (async.valueOrNull ?? [])) s.id: s,
  };
});

/// Provider per eliminare una specializzazione.
final eliminaSpecializzazioneProvider = Provider((ref) {
  return (String id) async {
    final db = FirebaseFirestore.instance;
    await db.collection('specializzazioni').doc(id).delete();
    ref.refresh(specializzazioneProvider);
  };
});
