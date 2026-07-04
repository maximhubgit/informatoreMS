import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/distretto.dart';

/// Provider che tiene lo stato dei distretti selezionati (set di codice).
final distrittiSelezionatiProvider =
    StateNotifierProvider<DistrittiSelezionatiNotifier, Set<int>>((ref) {
  return DistrittiSelezionatiNotifier();
});

class DistrittiSelezionatiNotifier extends StateNotifier<Set<int>> {
  DistrittiSelezionatiNotifier() : super({});

  void toggle(int distrettoId) {
    if (state.contains(distrettoId)) {
      state = {...state}..remove(distrettoId);
    } else {
      state = {...state, distrettoId};
    }
  }

  void replaceAll(Set<int> nuovi) => state = {...nuovi};

  void clearAll() => state = {};

  void selectAll(List<Distretto> distretti) => state = distretti.map((d) => d.codice).toSet();
}