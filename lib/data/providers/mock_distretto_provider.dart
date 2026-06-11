import 'package:informatoreMS/core/models/distretto.dart';

/// Provider mock statico per i distretti.
class MockDistrettoProvider {
  MockDistrettoProvider._();

  static final List<Distretto> distretti = [
    const Distretto(codice: 1, nrDistretto: 1, descrizione: 'Distretto Nord Centro', codiceAsl: 1),
    const Distretto(codice: 2, nrDistretto: 2, descrizione: 'Distretto Sud Centro', codiceAsl: 1),
    const Distretto(codice: 3, nrDistretto: 3, descrizione: 'Distretto Est', codiceAsl: 2),
    const Distretto(codice: 4, nrDistretto: 4, descrizione: 'Distretto Ovest', codiceAsl: 2),
    const Distretto(codice: 5, nrDistretto: 5, descrizione: 'Distretto Milano 1', codiceAsl: 3),
    const Distretto(codice: 6, nrDistretto: 6, descrizione: 'Distretto Milano 2', codiceAsl: 3),
  ];
}