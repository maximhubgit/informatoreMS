import 'package:informatoreMS/core/models/calendario_appuntamento.dart';

/// Provider mock statico per il calendario appuntamenti.
/// Contiene lo storico (fatto/annullato) e gli appuntamenti futuri (proposto/concordato).
class MockCalendarioProvider {
  MockCalendarioProvider._();

  static final List<CalendarioAppuntamento> appuntamenti = [
    // Storico (visitati)
    CalendarioAppuntamento(
      id: 'c1',
      medicoId: 'm1',
      data: DateTime(2026, 4, 15, 9, 30),
      stato: StatoCalendario.fatto,
      note: 'Controllo periodico',
    ),
    CalendarioAppuntamento(
      id: 'c2',
      medicoId: 'm2',
      data: DateTime(2026, 3, 20, 8, 30),
      stato: StatoCalendario.fatto,
    ),
    CalendarioAppuntamento(
      id: 'c3',
      medicoId: 'm3',
      data: DateTime(2026, 5, 1, 10, 0),
      stato: StatoCalendario.annullato,
    ),
    CalendarioAppuntamento(
      id: 'c4',
      medicoId: 'm4',
      data: DateTime(2026, 4, 28, 9, 0),
      stato: StatoCalendario.fatto,
    ),
    CalendarioAppuntamento(
      id: 'c5',
      medicoId: 'm5',
      data: DateTime(2026, 2, 15, 8, 0),
      stato: StatoCalendario.fatto,
    ),
    // Appuntamento concordato (prefissato nel calendario)
    CalendarioAppuntamento(
      id: 'c6',
      medicoId: 'm6',
      data: DateTime(2026, 6, 20, 10, 0),
      stato: StatoCalendario.confermato,
      note: 'Visita di controllo',
    ),
  ];
}
