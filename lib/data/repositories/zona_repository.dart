import 'package:informatoreMS/core/models/zona.dart';

/// Contratto per il repository zone.
abstract class ZonaRepository {
  Future<List<Zona>> getAll();
}
