import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:informatoreMS/core/models/asl.dart';
import 'package:informatoreMS/data/repositories/asl_repository.dart';

/// Repository Firebase per le ASL.
class FirebaseAslRepository implements AslRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<Asl>> getAll() async {
    final snapshot = await _db.collection('asl').orderBy('codice').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Asl.fromJson(data);
    }).toList();
  }

  @override
  Future<void> save(Asl asl) async {
    await _db.collection('asl').doc(asl.codice.toString()).set(asl.toJson());
  }

  @override
  Future<void> delete(int codice) async {
    await _db.collection('asl').doc(codice.toString()).delete();
  }
}