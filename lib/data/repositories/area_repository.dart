import 'package:informatoreMS/core/models/area.dart';

/// Contratto per il repository delle aree.
abstract class AreaRepository {
  Future<List<Area>> getAll();
  Future<void> save(Area area);
  Future<void> delete(String id);
}