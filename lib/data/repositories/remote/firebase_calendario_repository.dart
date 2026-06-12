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
      // Inietto l'id del documento (Firestore doc id) nel payload letto
      // perché CalendarioAppuntamento.fromJson lo richiede come campo `id`.
      data['id'] = doc.id;
      return CalendarioAppuntamento.fromJson(data);
    }).toList();
  }

  @override
  Future<void> save(CalendarioAppuntamento appuntamento) async {
    // Serializzo tramite toJson() del modello per non dimenticare campi
    // (es. fasciaOrariaId, fasciaNumero). Rimuovo `id` perché è il doc id di Firestore.
    final json = appuntamento.toJson();
    json.remove('id');
    await _db.collection('calendario_appuntamenti').doc(appuntamento.id).set(json);
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
