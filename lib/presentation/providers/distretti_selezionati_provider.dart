import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/distretto.dart';

/// Provider che tiene lo stato dei distretti selezionati (set di codici).
final distrettiSelezionatiProvider =
    StateNotifierProvider<DistrettiSelezionatiNotifier, Set<int>>((ref) {
  return DistrettiSelezionatiNotifier();
});

class DistrettiSelezionatiNotifier extends StateNotifier<Set<int>> {
  DistrettiSelezionatiNotifier() : super({});

  void toggle(int codice) {
    if (state.contains(codice)) {
      state = {...state}..remove(codice);
    } else {
      state = {...state, codice};
    }
  }

  void replaceAll(Set<int> nuovi) => state = {...nuovi};

  void clearAll() => state = {};

  void selectAll(List<Distretto> distretti) => state = distretti.map((d) => d.codice).toSet();
}