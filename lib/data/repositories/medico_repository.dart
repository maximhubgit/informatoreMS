import 'package:informatoreMS/core/models/medico.dart';

/// Contratto per il repository dei medici.
abstract class MedicoRepository {
  Future<List<Medico>> getAll();
  Future<void> save(Medico medico);
  Future<void> delete(String id);
}
