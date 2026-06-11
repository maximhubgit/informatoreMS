import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:informatoreMS/core/models/appuntamento.dart';
import 'package:informatoreMS/data/repositories/appuntamento_repository.dart';

/// Repository Firebase per gli appuntamenti.
class FirebaseAppuntamentoRepository implements AppuntamentoRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<Appuntamento>> getAll() async {
    final snapshot = await _db.collection('appuntamenti').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Appuntamento(
        id: doc.id,
        medicoId: data['medicoId'] ?? '',
        dataOraInizio: DateTime.parse(data['dataOraInizio'] ?? DateTime.now().toIso8601String()),
        dataOraFine: DateTime.parse(data['dataOraFine'] ?? DateTime.now().toIso8601String()),
        stato: StatoAppuntamento.values.byName(data['stato'] ?? 'confermato'),
        note: data['note'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> save(Appuntamento appuntamento) async {
    await _db.collection('appuntamenti').doc(appuntamento.id).set({
      'medicoId': appuntamento.medicoId,
      'dataOraInizio': appuntamento.dataOraInizio.toIso8601String(),
      'dataOraFine': appuntamento.dataOraFine.toIso8601String(),
      'stato': appuntamento.stato.name,
      'note': appuntamento.note,
    });
  }

  @override
  Future<void> delete(String id) async {
    await _db.collection('appuntamenti').doc(id).delete();
  }
}
