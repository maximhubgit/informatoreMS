import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider per il seeding del database in modalità debug.
final seedDatabaseProvider = Provider((ref) {
  return (BuildContext context) async {
    try {
      final db = FirebaseFirestore.instance;

      // Zone con icone e colori specifici
   /*    final zoneRef = await db.collection('zone').add({'nome': 'Centro', 'coloreHex': '#FF6B6B'});
      final nordRef = await db.collection('zone').add({'nome': 'Nord', 'coloreHex': '#4ECDC4'});
      await db.collection('zone').add({'nome': 'Sud', 'coloreHex': '#45B7D1'}); */

      // Specializzazioni con icone specifiche
      await db.collection('specializzazioni').add({'nome': 'Cardiologia', 'icona': 'favorite'});
      await db.collection('specializzazioni').add({'nome': 'Dermatologia', 'icona': 'face_retouching_natural'});
      await db.collection('specializzazioni').add({'nome': 'Pediatria', 'icona': 'child_care'});
      await db.collection('specializzazioni').add({'nome': 'Ortopedia', 'icona': 'accessibility_new'});
      await db.collection('specializzazioni').add({'nome': 'Ginecologia', 'icona': 'pregnant_woman'});
      await db.collection('specializzazioni').add({'nome': 'Neurologia', 'icona': 'psychology'});
      await db.collection('specializzazioni').add({'nome': 'Medicina Generale', 'icona': 'medical_services'});
      await db.collection('specializzazioni').add({'nome': 'Oculistica', 'icona': 'visibility'});
      await db.collection('specializzazioni').add({'nome': 'Otorinolaringoiatria', 'icona': 'hearing'});
      await db.collection('specializzazioni').add({'nome': 'Endocrinologia', 'icona': 'water_drop'});      

      /*// Medici
      await db.collection('medici').add({
        'nome': 'Mario',
        'cognome': 'Rossi',
        'specializzazione': 'Cardiologia',
        'indirizzo': 'Via Roma 1',
        'zonaId': zoneRef.id,
        'periodicitaGiorni': 30,
        'fasceOrarie': [
          {'minutiInizio': 540, 'minutiFine': 720}, // 9:00-12:00
          {'minutiInizio': 780, 'minutiFine': 1020}, // 13:00-17:00
        ],
        'tempoVisitaMinuti': 30,
      });

      await db.collection('medici').add({
        'nome': 'Luigi',
        'cognome': 'Verdi',
        'specializzazione': 'Dermatologia',
        'indirizzo': 'Via Milano 2',
        'zonaId': nordRef.id,
        'periodicitaGiorni': 60,
        'fasceOrarie': [
          {'minutiInizio': 480, 'minutiFine': 720}, // 8:00-12:00
        ],
        'tempoVisitaMinuti': 30,
      });

      await db.collection('medici').add({
        'nome': 'Anna',
        'cognome': 'Bianchi',
        'specializzazione': 'Pediatria',
        'indirizzo': 'Via Napoli 3',
        'zonaId': nordRef.id,
        'periodicitaGiorni': 28,
        'fasceOrarie': [
          {'minutiInizio': 540, 'minutiFine': 900}, // 9:00-15:00
        ],
        'tempoVisitaMinuti': 30,
      });
      
      // Appuntamenti di esempio
      final medici = await db.collection('medici').get();
      final mediciIds = medici.docs.map((d) => d.id).toList();

      await db.collection('calendario_appuntamenti').add({
        'medicoId': mediciIds.isNotEmpty ? mediciIds[0] : '',
        'data': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
        'note': 'Controllo periodico',
        'stato': 'fatto',
        'dataCreazione': DateTime.now().toIso8601String(),
      });

      await db.collection('calendario_appuntamenti').add({
        'medicoId': mediciIds.length > 1 ? mediciIds[1] : '',
        'data': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'stato': 'concordato',
        'note': 'Visita di controllo',
        'dataCreazione': DateTime.now().toIso8601String(),
      });
      */
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database popolato con dati di esempio!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore seeding: $e')),
        );
      }
    }
  };
});
