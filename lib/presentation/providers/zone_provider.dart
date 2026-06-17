import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/zona.dart';
import 'package:informatoreMS/data/repositories/zona_repository.dart';

/// Repository Firebase per le zone (import esplicito per evitare ambiguità).
import 'package:informatoreMS/data/repositories/remote/firebase_zona_repository.dart' as firebase;

/// Repository wrapper per web che lancia errore se offline.
class _WebZonaRepository implements ZonaRepository {
  final _firebaseRepo = firebase.FirebaseZonaRepository();

  @override
  Future<List<Zona>> getAll() async {
    try {
      return await _firebaseRepo.getAll();
    } catch (e) {
      throw Exception('Connessione richiesta. Ricollegati a internet per usare l\'app web.');
    }
  }
}

/// Provider del repository zone con logica:
/// - Web: solo Firebase (mostra errore se offline)
/// - Mobile/Desktop: Firebase (persistenza offline gestita da Firestore SDK)
final zonaRepositoryProvider = Provider<ZonaRepository>((ref) {
  if (kIsWeb) {
    return _WebZonaRepository();
  }
  return firebase.FirebaseZonaRepository();
}, dependencies: []);

/// Provider che espone la lista delle zone.
final zoneProvider = FutureProvider<List<Zona>>((ref) async {
  final repo = ref.watch(zonaRepositoryProvider);
  return repo.getAll();
});

/// Provider che mappa zonaId -> Zona.
final zonaByIdProvider = Provider<Map<String, Zona>>((ref) {
  final async = ref.watch(zoneProvider);
  return {
    for (final z in (async.valueOrNull ?? [])) z.id: z,
  };
});

/// Provider per salvare una zona.
final salvaZonaProvider = Provider((ref) {
  return (Zona zona) async {
    final db = FirebaseFirestore.instance;
    await db.collection('zone').doc(zona.id).set({
      'nome': zona.nome,
      'coloreHex': zona.coloreHex,
    });
    ref.refresh(zoneProvider);
  };
});

/// Provider per eliminare una zona.
final eliminaZonaProvider = Provider((ref) {
  return (String id) async {
    final db = FirebaseFirestore.instance;
    await db.collection('zone').doc(id).delete();
    ref.refresh(zoneProvider);
  };
});
