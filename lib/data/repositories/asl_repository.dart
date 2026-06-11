import 'package:informatoreMS/core/models/asl.dart';

/// Contratto per il repository delle ASL.
abstract class AslRepository {
  Future<List<Asl>> getAll();
  Future<void> save(Asl asl);
  Future<void> delete(int codice);
}