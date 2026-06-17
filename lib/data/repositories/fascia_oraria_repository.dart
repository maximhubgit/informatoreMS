import 'package:informatoreMS/core/models/fascia_oraria.dart';

/// Contratto per il repository delle fasce orarie.
abstract class FasciaOrariaRepository {
  /// Recupera tutte le fasce non soft-deleted in un'unica query.
  /// Da preferire a `getByMedicoId` in loop, per evitare N+1 su Firestore.
  Future<List<FasciaOraria>> getAll();
  Future<List<FasciaOraria>> getByMedicoId(String medicoId);
  Future<FasciaOraria?> getById(String id);
  Future<void> save(FasciaOraria fascia);
  Future<void> delete(String id);
  Future<void> deleteByMedicoId(String medicoId);
}