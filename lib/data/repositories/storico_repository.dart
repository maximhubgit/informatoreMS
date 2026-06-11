import 'package:informatoreMS/core/models/storico_appuntamento.dart';

/// Contratto per il repository dello storico appuntamenti.
abstract class StoricoRepository {
  Future<List<StoricoAppuntamento>> getAll();
  Future<void> save(StoricoAppuntamento entry);
}
