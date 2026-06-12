import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:informatoreMS/core/models/fascia_oraria.dart';
import 'package:informatoreMS/data/repositories/fascia_oraria_repository.dart';

/// Repository Firebase per le fasce orarie.
class FirebaseFasciaOrariaRepository implements FasciaOrariaRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'fasceOrarie';

  @override
  Future<List<FasciaOraria>> getByMedicoId(String medicoId) async {
    try {
      // Prima prova senza orderBy (per testare se è l'indice il problema)
      Query query = _db.collection(_collection).where('idMedico', isEqualTo: medicoId);

      final snapshot = await query.get();
      final fasce = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final dataWithId = Map<String, dynamic>.from(data);
            dataWithId['id'] = doc.id;
            return FasciaOraria.fromJson(dataWithId);
          })
          .where((fascia) => !fascia.deleted) // Filtro soft-delete a livello applicativo
          .toList();

      // Ordina in memoria
      fasce.sort((a, b) => a.nr.compareTo(b.nr));
      return fasce;
    } catch (e) {
      // Log dell'errore per debug
      print('ERRORE getByMedicoId: $e');
      rethrow;
    }
  }

  @override
  Future<FasciaOraria?> getById(String id) async {
    final doc = await _db.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final dataWithId = Map<String, dynamic>.from(data);
    dataWithId['id'] = doc.id;
    return FasciaOraria.fromJson(dataWithId);
  }

  @override
  Future<void> save(FasciaOraria fascia) async {
    final data = fascia.toJson();
    final docRef = fascia.id != null
        ? _db.collection(_collection).doc(fascia.id)
        : _db.collection(_collection).doc();
    data['id'] = docRef.id;
    await docRef.set(data);
  }

  @override
  Future<void> delete(String id) async {
    // Soft-delete: imposta deleted=true invece di rimuovere il documento
    await _db.collection(_collection).doc(id).update({'deleted': true});
  }

  @override
  Future<void> deleteByMedicoId(String medicoId) async {
    final snapshot = await _db
        .collection(_collection)
        .where('idMedico', isEqualTo: medicoId)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}