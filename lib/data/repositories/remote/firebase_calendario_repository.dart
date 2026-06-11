import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/data/repositories/calendario_repository.dart';

/// Repository Firebase per il calendario appuntamenti.
class FirebaseCalendarioRepository implements CalendarioRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<CalendarioAppuntamento>> getAll() async {
    final snapshot = await _db.collection('calendario_appuntamenti').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CalendarioAppuntamento(
        id: doc.id,
        medicoId: data['medicoId'] ?? '',
        data: DateTime.parse(data['data'] ?? DateTime.now().toIso8601String()),
        note: data['note'] as String?,
        stato: () {
      final statoStr = data['stato'] ?? 'proposto';
      try {
        return StatoCalendario.values.byName(statoStr);
      } catch (_) {
        // Se lo stato salvato non è valido, usa il valore di default
        return StatoCalendario.proposto;
      }
    }(),
        dataCreazione: data['dataCreazione'] != null
            ? DateTime.parse(data['dataCreazione'])
            : null,
      );
    }).toList();
  }

  @override
  Future<void> save(CalendarioAppuntamento appuntamento) async {
    await _db.collection('calendario_appuntamenti').doc(appuntamento.id).set({
      'medicoId': appuntamento.medicoId,
      'data': appuntamento.data.toIso8601String(),
      'note': appuntamento.note,
      'stato': appuntamento.stato.name,
      'dataCreazione': appuntamento.dataCreazione?.toIso8601String(),
    });
  }

  @override
  Future<void> updateStato(String id, StatoCalendario nuovoStato) async {
    await _db.collection('calendario_appuntamenti').doc(id).update({
      'stato': nuovoStato.name,
    });
  }

  @override
  Future<void> delete(String id) async {
    await _db.collection('calendario_appuntamenti').doc(id).delete();
  }
}
