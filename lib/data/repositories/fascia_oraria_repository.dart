import 'package:informatoreMS/core/models/fascia_oraria.dart';

/// Contratto per il repository delle fasce orarie.
abstract class FasciaOrariaRepository {
  Future<List<FasciaOraria>> getByMedicoId(String medicoId);
  Future<FasciaOraria?> getById(String id);
  Future<void> save(FasciaOraria fascia);
  Future<void> delete(String id);
  Future<void> deleteByMedicoId(String medicoId);
}