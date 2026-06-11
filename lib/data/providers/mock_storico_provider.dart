import 'package:informatoreMS/core/models/storico_appuntamento.dart';
import 'package:informatoreMS/core/models/appuntamento.dart';

/// Provider mock statico per lo storico appuntamenti.
class MockStoricoProvider {
  MockStoricoProvider._();

  static final List<StoricoAppuntamento> storico = [
    StoricoAppuntamento(
      id: 's1',
      medicoId: 'm1',
      appuntamentoId: 'a1',
      dataEseguita: DateTime(2026, 4, 15, 9, 30),
      stato: StatoAppuntamento.fatto,
      timestamp: DateTime(2026, 4, 15, 10, 0),
    ),
    StoricoAppuntamento(
      id: 's2',
      medicoId: 'm2',
      appuntamentoId: 'a2',
      dataEseguita: DateTime(2026, 3, 20, 8, 30),
      stato: StatoAppuntamento.fatto,
      timestamp: DateTime(2026, 3, 20, 9, 0),
    ),
    StoricoAppuntamento(
      id: 's3',
      medicoId: 'm3',
      appuntamentoId: 'a3',
      dataEseguita: DateTime(2026, 5, 1, 10, 0),
      stato: StatoAppuntamento.nonFatto,
      timestamp: DateTime(2026, 5, 1, 11, 0),
    ),
    StoricoAppuntamento(
      id: 's4',
      medicoId: 'm4',
      appuntamentoId: 'a4',
      dataEseguita: DateTime(2026, 4, 28, 9, 0),
      stato: StatoAppuntamento.fatto,
      timestamp: DateTime(2026, 4, 28, 10, 0),
    ),
    StoricoAppuntamento(
      id: 's5',
      medicoId: 'm5',
      appuntamentoId: 'a5',
      dataEseguita: DateTime(2026, 2, 15, 8, 0),
      stato: StatoAppuntamento.fatto,
      timestamp: DateTime(2026, 2, 15, 9, 0),
    ),
  ];
}
