import 'package:informatoreMS/core/models/distretto.dart';

/// Contratto per il repository dei distretti.
abstract class DistrettoRepository {
  Future<List<Distretto>> getAll();
  Future<void> save(Distretto distretto);
  Future<void> delete(int codice);
  Future<List<Distretto>> getByAsl(int codiceAsl);
}