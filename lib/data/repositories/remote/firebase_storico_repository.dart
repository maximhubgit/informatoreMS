import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:informatoreMS/core/models/appuntamento.dart';
import 'package:informatoreMS/core/models/storico_appuntamento.dart';
import 'package:informatoreMS/data/repositories/storico_repository.dart';

/// Repository Firebase per lo storico appuntamenti.
class FirebaseStoricoRepository implements StoricoRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<StoricoAppuntamento>> getAll() async {
    final snapshot = await _db.collection('storico_appuntamenti').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return StoricoAppuntamento(
        id: doc.id,
        medicoId: data['medicoId'] ?? '',
        appuntamentoId: data['appuntamentoId'] as String?,
        dataEseguita: DateTime.parse(data['dataEseguita'] ?? DateTime.now().toIso8601String()),
        stato: StatoAppuntamento.values.byName(data['stato'] ?? 'fatto'),
        timestamp: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
      );
    }).toList();
  }

  @override
  Future<void> save(StoricoAppuntamento entry) async {
    await _db.collection('storico_appuntamenti').doc(entry.id).set({
      'medicoId': entry.medicoId,
      'appuntamentoId': entry.appuntamentoId,
      'dataEseguita': entry.dataEseguita.toIso8601String(),
      'stato': entry.stato.name,
      'timestamp': entry.timestamp.toIso8601String(),
    });
  }
}
