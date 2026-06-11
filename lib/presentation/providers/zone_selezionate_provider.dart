import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/zona.dart';

/// Provider che tiene lo stato delle zone selezionate (set di id).
final zoneSelezionateProvider =
    StateNotifierProvider<ZoneSelezionateNotifier, Set<String>>((ref) {
  return ZoneSelezionateNotifier();
});

class ZoneSelezionateNotifier extends StateNotifier<Set<String>> {
  ZoneSelezionateNotifier() : super({});

  void toggle(String zonaId) {
    if (state.contains(zonaId)) {
      state = {...state}..remove(zonaId);
    } else {
      state = {...state, zonaId};
    }
  }

  void clearAll() => state = {};

  void selectAll(List<Zona> zone) => state = zone.map((z) => z.id).toSet();
}
