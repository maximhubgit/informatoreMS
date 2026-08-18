import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:informatoreMS/core/models/area.dart';
import 'package:informatoreMS/data/repositories/area_repository.dart';

/// Repository Firebase per le aree.
class FirebaseAreaRepository implements AreaRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'aree';

  @override
  Future<List<Area>> getAll() async {
    // Nessun orderBy: ordinamento in memoria per id, come fatto per
    // le fasceOrarie, per evitare dipendenza dagli indici Firestore.
    final snapshot = await _db.collection(_collection).get();
    final aree = snapshot.docs.map((doc) {
      final data = doc.data();
      return Area(id: doc.id, nome: data['Area'] as String? ?? '');
    }).toList();
    aree.sort((a, b) => a.id.compareTo(b.id));
    return aree;
  }

  @override
  Future<void> save(Area area) async {
    await _db.collection(_collection).doc(area.id).set(area.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }
}