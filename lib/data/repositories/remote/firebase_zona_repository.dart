import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:informatoreMS/core/models/zona.dart';
import 'package:informatoreMS/data/repositories/zona_repository.dart';

/// Repository Firebase per le zone.
class FirebaseZonaRepository implements ZonaRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<Zona>> getAll() async {
    final snapshot = await _db.collection('zone').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Zona(
        id: doc.id,
        nome: data['nome'] ?? '',
        coloreHex: data['coloreHex'] ?? '#4ECDC4',
      );
    }).toList();
  }
}
