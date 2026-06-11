import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:informatoreMS/core/firebase_options.dart';

/// Script per popolare il database Firebase con dati di esempio.
/// Richiamare da UI dell'app in modalità debug.
class FirebaseSeeder {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> seed() async {
    // Firebase già inizializzato dall'app

    // Crea ASL
    await _seedAsl();

    // Crea distretti (dopo le ASL)
    await _seedDistretti();

    // Crea zone
    await _seedZone();

    // Crea specializzazioni
    await _seedSpecializzazioni();

    // Crea medici (dopo le zone)
    await _seedMedici();

    // Crea appuntamenti di esempio
    await _seedAppuntamenti();

    print('Seeding completato!');
  }

  Future<void> _seedAsl() async {
    final aslList = [
      {'codice': 1, 'descrizione': 'ASL Roma 1'},
      {'codice': 2, 'descrizione': 'ASL Roma 2'},
      {'codice': 3, 'descrizione': 'ASL Milano'},
      {'codice': 4, 'descrizione': 'ASL Napoli'},
    ];

    for (final asl in aslList) {
      await _db.collection('asl').doc(asl['codice'].toString()).set(asl);
    }
    print('ASL inserite: ${aslList.length}');
  }

  Future<void> _seedDistretti() async {
    final distretti = [
      {'codice': 1, 'nrDistretto': 1, 'descrizione': 'Distretto Nord Centro', 'codiceAsl': 1},
      {'codice': 2, 'nrDistretto': 2, 'descrizione': 'Distretto Sud Centro', 'codiceAsl': 1},
      {'codice': 3, 'nrDistretto': 3, 'descrizione': 'Distretto Est', 'codiceAsl': 2},
      {'codice': 4, 'nrDistretto': 4, 'descrizione': 'Distretto Ovest', 'codiceAsl': 2},
      {'codice': 5, 'nrDistretto': 5, 'descrizione': 'Distretto Milano 1', 'codiceAsl': 3},
      {'codice': 6, 'nrDistretto': 6, 'descrizione': 'Distretto Milano 2', 'codiceAsl': 3},
    ];

    for (final d in distretti) {
      await _db.collection('distretti').doc(d['codice'].toString()).set(d);
    }
    print('Distretti inseriti: ${distretti.length}');
  }

  Future<void> _seedZone() async {
    final zone = [
      {'nome': 'Centro', 'coloreHex': '#FF6B6B'},
      {'nome': 'Nord', 'coloreHex': '#4ECDC4'},
      {'nome': 'Sud', 'coloreHex': '#45B7D1'},
      {'nome': 'Est', 'coloreHex': '#96CEB4'},
      {'nome': 'Ovest', 'coloreHex': '#FFEAA7'},
    ];

    for (final z in zone) {
      await _db.collection('zone').add(z);
    }
    print('Zone inserite: ${zone.length}');
  }

  Future<void> _seedSpecializzazioni() async {
    final specializzazioni = [
      'Cardiologia',
      'Dermatologia',
      'Endocrinologia',
      'Gastroenterologia',
      'Ortopedia',
      'Pediatria',
    ];

    for (final s in specializzazioni) {
      await _db.collection('specializzazioni').add({'nome': s});
    }
    print('Specializzazioni inserite: ${specializzazioni.length}');
  }

  Future<void> _seedMedici() async {
    final zoneSnapshot = await _db.collection('zone').get();
    final zoneMap = {for (final z in zoneSnapshot.docs) z.id: z.id};

    final specializzazioniSnapshot = await _db.collection('specializzazioni').get();
    final specMap = {
      for (final s in specializzazioniSnapshot.docs) s.data()['nome'] as String: s.id
    };

    // Medici - i dettagli (distretto, zona, struttura, indirizzo, durata) sono nelle fasce orarie
    final medici = [
      {
        'nome': 'Mario Rossi',
        'specializzazioneId': specMap['Cardiologia'],
        'periodicitaGiorni': 30,
      },
      {
        'nome': 'Luigi Verdi',
        'specializzazioneId': specMap['Dermatologia'],
        'periodicitaGiorni': 60,
      },
      {
        'nome': 'Anna Bianchi',
        'specializzazioneId': specMap['Pediatria'],
        'periodicitaGiorni': 28,
      },
    ];

    List<String> mediciIds = [];
    for (final m in medici) {
      final docRef = await _db.collection('medici').add(m);
      mediciIds.add(docRef.id);
    }
    print('Medici inseriti: ${medici.length}');

    // Fasce orarie separate - ogni fascia ha i propri dettagli
    final fasce = [
      // Mario Rossi
      {
        'idMedico': mediciIds[0],
        'nr': 0,
        'minutiInizio': 540, 'minutiFine': 720,
        'giorniSettimana': ['lunedi', 'martedi'],
        'distrettoId': 1, 'zonaId': zoneMap.values.first,
        'struttura': 'Ospedale San Raffaele',
        'indirizzo': 'Via Roma 1',
        'tempoVisitaMinuti': 30,
      },
      {
        'idMedico': mediciIds[0],
        'nr': 1,
        'minutiInizio': 780, 'minutiFine': 1020,
        'giorniSettimana': ['lunedi', 'martedi'],
        'distrettoId': 1, 'zonaId': zoneMap.values.first,
      },
      // Luigi Verdi
      {
        'idMedico': mediciIds[1],
        'nr': 0,
        'minutiInizio': 480, 'minutiFine': 720,
        'distrettoId': 3, 'zonaId': zoneMap.values.elementAt(1) ?? '',
        'struttura': 'Clinica Est',
        'indirizzo': 'Via Milano 2',
      },
      // Anna Bianchi
      {
        'idMedico': mediciIds[2],
        'nr': 0,
        'minutiInizio': 540, 'minutiFine': 900,
        'giorniSettimana': ['venerdi', 'sabato'],
        'distrettoId': 5, 'zonaId': zoneMap.values.elementAt(2) ?? '',
        'struttura': 'Pediatrico Nord',
        'indirizzo': 'Via Napoli 3',
      },
    ];

    for (final f in fasce) {
      await _db.collection('fasceOrarie').add(f);
    }
    print('Fasce orarie inserite: ${fasce.length}');
  }

  Future<void> _seedAppuntamenti() async {
    final mediciSnapshot = await _db.collection('medici').get();
    final mediciMap = {for (final m in mediciSnapshot.docs) m.id: m.id};

    final appuntamenti = [
      {
        'medicoId': mediciMap.values.first,
        'data': DateTime(2026, 4, 15, 9, 30).toIso8601String(),
        'note': 'Controllo periodico',
        'stato': 'fatto',
      },
      {
        'medicoId': mediciMap.values.elementAt(1),
        'data': DateTime(2026, 3, 20, 8, 30).toIso8601String(),
        'stato': 'fatto',
      },
      {
        'medicoId': mediciMap.values.elementAt(2),
        'data': DateTime(2026, 6, 20, 10, 0).toIso8601String(),
        'stato': 'concordato',
        'note': 'Visita di controllo',
      },
    ];

    for (final a in appuntamenti) {
      await _db.collection('calendario_appuntamenti').add(a);
    }
    print('Appuntamenti inseriti: ${appuntamenti.length}');
  }
}

// Per eseguire: dart run lib/data/seeds/firebase_seed.dart
void main() async {
  final seeder = FirebaseSeeder();
  await seeder.seed();
}