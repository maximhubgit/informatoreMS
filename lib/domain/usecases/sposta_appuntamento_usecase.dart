import 'package:informatoreMS/core/models/appuntamento.dart';
import 'package:informatoreMS/core/models/storico_appuntamento.dart';
import 'package:informatoreMS/data/repositories/appuntamento_repository.dart';
import 'package:informatoreMS/data/repositories/storico_repository.dart';
import 'package:uuid/uuid.dart';

/// Caso d'uso: sposta un appuntamento in una nuova data/ora.
///
/// Le ricorrenze future ripartono dalla nuova data (ciclo continuo dal rinvio).
class SpostaAppuntamentoUseCase {
  final AppuntamentoRepository _appuntamentoRepo;
  final StoricoRepository _storicoRepo;
  static final _uuid = const Uuid();

  SpostaAppuntamentoUseCase(
    this._appuntamentoRepo,
    this._storicoRepo,
  );

  Future<Appuntamento> call({
    required Appuntamento appuntamento,
    required DateTime nuovaDataOraInizio,
    required DateTime nuovaDataOraFine,
  }) async {
    final spostato = appuntamento.copyWith(
      dataOraInizio: nuovaDataOraInizio,
      dataOraFine: nuovaDataOraFine,
      stato: StatoAppuntamento.spostato,
    );

    await _appuntamentoRepo.save(spostato);

    final entry = StoricoAppuntamento(
      id: _uuid.v4(),
      medicoId: appuntamento.medicoId,
      appuntamentoId: appuntamento.id,
      dataEseguita: nuovaDataOraInizio,
      stato: StatoAppuntamento.spostato,
      timestamp: DateTime.now(),
    );
    await _storicoRepo.save(entry);

    return spostato;
  }
}
