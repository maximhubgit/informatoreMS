import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:informatoreMS/core/models/specializzazione.dart';
import 'package:informatoreMS/data/repositories/specializzazione_repository.dart';

/// Repository Firebase per le specializzazioni.
class FirebaseSpecializzazioneRepository implements SpecializzazioneRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<Specializzazione>> getAll() async {
    final snapshot = await _db.collection('specializzazioni').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Specializzazione.fromJson({
        'id': doc.id,
        'nome': data['nome'],
        'icona': data['icona'],
      });
    }).toList();
  }
}
