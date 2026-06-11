import 'package:informatoreMS/core/models/appuntamento.dart';
import 'package:informatoreMS/core/models/storico_appuntamento.dart';
import 'package:informatoreMS/data/repositories/appuntamento_repository.dart';
import 'package:informatoreMS/data/repositories/storico_repository.dart';
import 'package:uuid/uuid.dart';

/// Caso d'uso: registra esito (fatto / non fatto) di un appuntamento.
///
/// Se fatto: la prossima ricorrenza riparte da dataEseguita + periodicità.
/// Se non fatto: slittamento totale; prossima ricorrenza = prima data libera.
class RegistraEsitoUseCase {
  final AppuntamentoRepository _appuntamentoRepo;
  final StoricoRepository _storicoRepo;
  static final _uuid = const Uuid();

  RegistraEsitoUseCase(
    this._appuntamentoRepo,
    this._storicoRepo,
  );

  Future<void> call({
    required Appuntamento appuntamento,
    required StatoAppuntamento esito,
  }) async {
    assert(esito == StatoAppuntamento.fatto || esito == StatoAppuntamento.nonFatto);

    final aggiornato = appuntamento.copyWith(stato: esito);
    await _appuntamentoRepo.save(aggiornato);

    final entry = StoricoAppuntamento(
      id: _uuid.v4(),
      medicoId: appuntamento.medicoId,
      appuntamentoId: appuntamento.id,
      dataEseguita: appuntamento.dataOraInizio,
      stato: esito,
      timestamp: DateTime.now(),
    );
    await _storicoRepo.save(entry);
  }
}
