import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/data/repositories/medico_repository.dart';

/// Repository Firebase per i medici.
class FirebaseMedicoRepository implements MedicoRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<Medico>> getAll() async {
    final snapshot = await _db.collection('medici').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Aggiungiamo l'ID del documento ai dati
      final dataWithId = Map<String, dynamic>.from(data);
      dataWithId['id'] = doc.id;
      return Medico.fromJson(dataWithId);
    }).toList();
  }

  @override
  Future<void> save(Medico medico) async {
    await _db.collection('medici').doc(medico.id).set(medico.toJson());
  }

  @override
  Future<void> delete(String id) async {
    await _db.collection('medici').doc(id).delete();
  }
}
