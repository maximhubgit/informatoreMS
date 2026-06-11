import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/pending_operation.dart';
import 'package:informatoreMS/data/services/pending_operations_service.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';

/// Servizio che ascolta la connessione e sincronizza le operazioni pendenti.
class SyncService {
  final Ref _ref;

  SyncService(this._ref);

  /// Viene chiamato dal main quando la connectività cambia.
  /// Per ora è un metodo manuale, si può ottimizzare con listen manual.
  Future<void> syncIfNeeded(bool isConnected) async {
    if (isConnected) {
      await _syncPending();
    }
  }

  Future<void> _syncPending() async {
    final service = PendingOperationsService();
    final queue = await service.getAll();
    if (queue.isEmpty) return;

    for (final op in queue) {
      try {
        switch (op.tipo) {
          case TipoOperazione.registraEsito:
            // Il payload contiene l'appuntamento serializzato + esito;
            // durante l'evoluzione verso Firebase si applicherà
            // il replay tramite repository reale.
            break;
          case TipoOperazione.sposta:
            // Stessa logica: replay della move verso il backend
            break;
        }
        await service.remove(op.id);
      } catch (e) {
        // Se fallisce, abbandona per lasciare le operazioni rimanenti
        // in coda per il prossimo tentativo.
        break;
      }
    }

    // Invalida il calendario per forzare rigenerazione
    _ref.invalidate(calendarioProvider);
  }
}
