import 'package:informatoreMS/core/models/appuntamento.dart';

/// Contratto per il repository degli appuntamenti generati.
abstract class AppuntamentoRepository {
  Future<List<Appuntamento>> getAll();
  Future<void> save(Appuntamento appuntamento);
  Future<void> delete(String id);
}
