import 'package:informatoreMS/core/models/fascia_oraria.dart';
import 'package:informatoreMS/core/models/medico.dart';

/// Provider mock statico per i medici senza fasce orarie.
/// Le fasce orarie vanno usate tramite MockFasciaOrariaProvider.
class MockMedicoProvider {
  MockMedicoProvider._();

  static final List<Medico> medici = [
    const Medico(
      id: 'm1',
      nome: 'Mario Rossi',
      specializzazioneId: 's1',
      periodicitaGiorni: 30,
    ),
    const Medico(
      id: 'm2',
      nome: 'Laura Bianchi',
      specializzazioneId: 's2',
      periodicitaGiorni: 60,
    ),
    const Medico(
      id: 'm3',
      nome: 'Giuseppe Verdi',
      specializzazioneId: 's3',
      periodicitaGiorni: 45,
    ),
    const Medico(
      id: 'm4',
      nome: 'Anna Neri',
      specializzazioneId: 's4',
      periodicitaGiorni: 30,
    ),
    const Medico(
      id: 'm5',
      nome: 'Francesca Gialli',
      specializzazioneId: 's5',
      periodicitaGiorni: 90,
    ),
    const Medico(
      id: 'm6',
      nome: 'Roberto Blu',
      specializzazioneId: 's6',
      periodicitaGiorni: 30,
    ),
  ];
}

/// Provider mock statico per le fasce orarie.
/// Ogni medico ha almeno una fascia con nr=0 (fascia principale).
class MockFasciaOrariaProvider {
  MockFasciaOrariaProvider._();

  static final List<FasciaOraria> fasce = [
    // Fasce per Mario Rossi (m1) - nr=0 è la principale
    FasciaOraria(
      id: 'f1',
      idMedico: 'm1',
      nr: 0,
      minutiInizio: 9 * 60,
      minutiFine: 12 * 60,
      distrettoId: 1,
      zonaId: 'z1',
      struttura: 'Ospedale San Raffaele',
      indirizzo: 'Via Roma 10, Centro Storico',
      tempoVisitaMinuti: 30,
    ),
    FasciaOraria(
      id: 'f2',
      idMedico: 'm1',
      nr: 1,
      minutiInizio: 15 * 60,
      minutiFine: 18 * 60,
      distrettoId: 1,
      zonaId: 'z1',
    ),
    // Fasce per Laura Bianchi (m2)
    FasciaOraria(
      id: 'f3',
      idMedico: 'm2',
      nr: 0,
      minutiInizio: 8 * 60 + 30,
      minutiFine: 11 * 60 + 30,
      distrettoId: 2,
      zonaId: 'z2',
      struttura: 'Clinica Est',
      indirizzo: 'Via Milano 5, Periferia Nord',
      tempoVisitaMinuti: 20,
    ),
    // Fasce per Giuseppe Verdi (m3)
    FasciaOraria(
      id: 'f4',
      idMedico: 'm3',
      nr: 0,
      minutiInizio: 10 * 60,
      minutiFine: 13 * 60,
      distrettoId: 1,
      zonaId: 'z1',
      struttura: 'Ospedale San Raffaele',
      indirizzo: 'Piazza Garibaldi 1, Centro Storico',
      tempoVisitaMinuti: 45,
    ),
    FasciaOraria(
      id: 'f5',
      idMedico: 'm3',
      nr: 1,
      minutiInizio: 16 * 60,
      minutiFine: 19 * 60,
      distrettoId: 1,
      zonaId: 'z1',
    ),
    // Fasce per Anna Neri (m4)
    FasciaOraria(
      id: 'f6',
      idMedico: 'm4',
      nr: 0,
      minutiInizio: 9 * 60,
      minutiFine: 12 * 60,
      distrettoId: 3,
      zonaId: 'z3',
      indirizzo: 'Via Napoli 20, Periferia Sud',
      tempoVisitaMinuti: 30,
    ),
    FasciaOraria(
      id: 'f7',
      idMedico: 'm4',
      nr: 1,
      minutiInizio: 14 * 60,
      minutiFine: 17 * 60,
      distrettoId: 3,
      zonaId: 'z3',
    ),
    // Fasce per Francesca Gialli (m5)
    FasciaOraria(
      id: 'f8',
      idMedico: 'm5',
      nr: 0,
      minutiInizio: 8 * 60,
      minutiFine: 12 * 60,
      distrettoId: 4,
      zonaId: 'z4',
      indirizzo: 'Corso Italia 50, Zona Ovest',
      tempoVisitaMinuti: 40,
    ),
    // Fasce per Roberto Blu (m6)
    FasciaOraria(
      id: 'f9',
      idMedico: 'm6',
      nr: 0,
      minutiInizio: 9 * 60,
      minutiFine: 13 * 60,
      distrettoId: 5,
      zonaId: 'z2',
      indirizzo: 'Via Torino 15, Periferia Nord',
      tempoVisitaMinuti: 30,
    ),
    FasciaOraria(
      id: 'f10',
      idMedico: 'm6',
      nr: 1,
      minutiInizio: 15 * 60,
      minutiFine: 18 * 60,
      distrettoId: 5,
      zonaId: 'z2',
    ),
  ];
}