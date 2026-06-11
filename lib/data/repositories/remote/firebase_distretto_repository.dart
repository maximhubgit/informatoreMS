import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:informatoreMS/core/models/distretto.dart';
import 'package:informatoreMS/data/repositories/distretto_repository.dart';

/// Repository Firebase per i distretti.
class FirebaseDistrettoRepository implements DistrettoRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<Distretto>> getAll() async {
    final snapshot = await _db.collection('distretti').orderBy('codice').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Distretto.fromJson(data);
    }).toList();
  }

  @override
  Future<void> save(Distretto distretto) async {
    await _db.collection('distretti').doc(distretto.codice.toString()).set(distretto.toJson());
  }

  @override
  Future<void> delete(int codice) async {
    await _db.collection('distretti').doc(codice.toString()).delete();
  }

  /// Get distretti by ASL code
  Future<List<Distretto>> getByAsl(int codiceAsl) async {
    final snapshot = await _db.collection('distretti')
        .where('codiceAsl', isEqualTo: codiceAsl)
        .orderBy('codice')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Distretto.fromJson(data);
    }).toList();
  }
}