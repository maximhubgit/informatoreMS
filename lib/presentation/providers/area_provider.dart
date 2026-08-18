import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/area.dart';
import 'package:informatoreMS/data/repositories/area_repository.dart';

/// Repository Firebase per le aree (import esplicito per evitare ambiguità).
import 'package:informatoreMS/data/repositories/remote/firebase_area_repository.dart' as firebase;

/// Repository wrapper per web che lancia errore se offline.
class _WebAreaRepository implements AreaRepository {
  final _firebaseRepo = firebase.FirebaseAreaRepository();

  @override
  Future<List<Area>> getAll() async {
    try {
      return await _firebaseRepo.getAll();
    } catch (e) {
      throw Exception('Connessione richiesta. Ricollegati a internet per usare l\'app web.');
    }
  }

  @override
  Future<void> save(Area area) async {
    await _firebaseRepo.save(area);
  }

  @override
  Future<void> delete(String id) async {
    await _firebaseRepo.delete(id);
  }
}

/// Provider del repository aree con logica:
/// - Web: solo Firebase (mostra errore se offline)
/// - Mobile/Desktop: Firebase con persistenza offline integrata
final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  if (kIsWeb) {
    return _WebAreaRepository();
  }
  return firebase.FirebaseAreaRepository();
});

/// Provider che espone la lista delle aree.
final areaProvider = FutureProvider<List<Area>>((ref) async {
  final repo = ref.watch(areaRepositoryProvider);
  return repo.getAll();
});

/// Provider che mappa id -> Area.
final areaByIdProvider = Provider<Map<String, Area>>((ref) {
  final async = ref.watch(areaProvider);
  return {
    for (final a in (async.valueOrNull ?? [])) a.id: a,
  };
});

/// Prossimo codice area libero: max tra i codici esistenti (id "A…",
/// esclusa la sentinella '0000') + 1. Lista vuota -> 1.
/// Il codice viene formattato come 'A' + 3 cifre (es. 52 -> 'A052').
final prossimoCodiceAreaProvider = Provider<int>((ref) {
  final async = ref.watch(areaProvider);
  var maxCodice = 0;
  for (final a in (async.valueOrNull ?? [])) {
    if (a.id.startsWith('A')) {
      final codice = int.tryParse(a.id.substring(1));
      if (codice != null && codice > maxCodice) {
        maxCodice = codice;
      }
    }
  }
  return maxCodice + 1;
});

/// Provider per salvare un'area.
final salvaAreaProvider = Provider((ref) {
  return (Area area) async {
    final db = FirebaseFirestore.instance;
    await db.collection('aree').doc(area.id).set(area.toJson());
    ref.invalidate(areaProvider);
  };
});

/// Provider per eliminare un'area.
final eliminaAreaProvider = Provider((ref) {
  return (String id) async {
    final db = FirebaseFirestore.instance;
    await db.collection('aree').doc(id).delete();
    ref.invalidate(areaProvider);
  };
});

/// Provider che tiene lo stato delle aree selezionate (set di id).
final areeSelezionateProvider =
    StateNotifierProvider<AreeSelezionateNotifier, Set<String>>((ref) {
      return AreeSelezionateNotifier();
    });

class AreeSelezionateNotifier extends StateNotifier<Set<String>> {
  AreeSelezionateNotifier() : super({});

  void toggle(String areaId) {
    if (state.contains(areaId)) {
      state = {...state}..remove(areaId);
    } else {
      state = {...state, areaId};
    }
  }

  void replaceAll(Set<String> nuove) => state = {...nuove};

  void clearAll() => state = {};

  void selectAll(List<Area> aree) => state = aree.map((a) => a.id).toSet();
}