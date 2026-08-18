import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/area.dart';
import 'package:informatoreMS/core/models/distretto.dart';
import 'package:informatoreMS/core/models/zona.dart';
import 'package:informatoreMS/presentation/providers/area_provider.dart';
import 'package:informatoreMS/presentation/providers/distretto_provider.dart';
import 'package:informatoreMS/presentation/providers/distretti_selezionati_provider.dart';
import 'package:informatoreMS/presentation/providers/zone_provider.dart';
import 'package:informatoreMS/presentation/providers/zone_selezionate_provider.dart';

/// Riga compatta con i tre filtri Distretti / Zone / Aree, condivisa tra la
/// schermata Medici e la schermata Pianifica.
///
/// Ogni campo mostra solo la caption sul bordo e l'icona al centro (nessun
/// testo). L'icona si accentua quando il filtro ha delle selezioni attive.
/// Lo stato è condiviso: i provider sono gli stessi usati dalle liste.
class TripleFilterRow extends ConsumerWidget {
  const TripleFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distrettiSelezionati = ref.watch(distrettiSelezionatiProvider);
    final zoneSelezionate = ref.watch(zoneSelezionateProvider);
    final areeSelezionate = ref.watch(areeSelezionateProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _CompactFilterField(
              label: 'Distretti',
              icon: Icons.location_city_rounded,
              active: distrettiSelezionati.isNotEmpty,
              onTap: () => _showMultiSelectDialog<Distretto>(
                context: context,
                ref: ref,
                title: 'Seleziona distretti',
                itemsAsync: ref.watch(distrettoProvider),
                initialSelected: Set<Object>.from(distrettiSelezionati),
                idOf: (d) => d.codice,
                labelOf: (d) => _truncateLabel(d.campoDescrittivo),
                onApply: (selected) => ref
                    .read(distrettiSelezionatiProvider.notifier)
                    .replaceAll(selected.cast<int>()),
                onClear: () =>
                    ref.read(distrettiSelezionatiProvider.notifier).clearAll(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _CompactFilterField(
              label: 'Zone',
              icon: Icons.map_rounded,
              active: zoneSelezionate.isNotEmpty,
              onTap: () => _showMultiSelectDialog<Zona>(
                context: context,
                ref: ref,
                title: 'Seleziona zone',
                itemsAsync: ref.watch(zoneProvider),
                initialSelected: Set<Object>.from(zoneSelezionate),
                idOf: (z) => z.id,
                labelOf: (z) => z.nome,
                onApply: (selected) => ref
                    .read(zoneSelezionateProvider.notifier)
                    .replaceAll(selected.cast<String>()),
                onClear: () =>
                    ref.read(zoneSelezionateProvider.notifier).clearAll(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _CompactFilterField(
              label: 'Aree',
              icon: Icons.grid_on_rounded,
              active: areeSelezionate.isNotEmpty,
              onTap: () => _showMultiSelectDialog<Area>(
                context: context,
                ref: ref,
                title: 'Seleziona aree',
                itemsAsync: ref.watch(areaProvider),
                initialSelected: Set<Object>.from(areeSelezionate),
                idOf: (a) => a.id,
                labelOf: (a) => a.nome,
                onApply: (selected) => ref
                    .read(areeSelezionateProvider.notifier)
                    .replaceAll(selected.cast<String>()),
                onClear: () =>
                    ref.read(areeSelezionateProvider.notifier).clearAll(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog multiselezione condiviso. L'id di ogni item identifica la
  /// selezione; gli oggetti selezionati vengono raccolti come Set<Object>.
  Future<void> _showMultiSelectDialog<T>({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required AsyncValue<List<T>> itemsAsync,
    required Set<Object> initialSelected,
    required Object Function(T item) idOf,
    required String Function(T item) labelOf,
    required void Function(Set<Object> selected) onApply,
    required VoidCallback onClear,
  }) async {
    final selected = Set<Object>.from(initialSelected);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                child: itemsAsync.when(
                  data: (items) => SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: items.map((item) {
                        final isSelected = selected.contains(idOf(item));
                        return CheckboxListTile(
                          title: Text(labelOf(item)),
                          value: isSelected,
                          onChanged: (v) {
                            setStateDialog(() {
                              if (v == true) {
                                selected.add(idOf(item));
                              } else {
                                selected.remove(idOf(item));
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Errore caricamento'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    onClear();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Pulisci'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () {
                    onApply(selected);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Applica'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _truncateLabel(String text) {
    final cleanText = text.replaceAll('\n', ' ').replaceAll('\r', '');
    return cleanText.length <= 20 ? cleanText : '${cleanText.substring(0, 20)}...';
  }
}

/// Campo compatto: caption sul bordo + icona centrata, nessun testo.
class _CompactFilterField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _CompactFilterField({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = active ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: active ? colorScheme.primary : colorScheme.outlineVariant,
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            Positioned(
              top: 0,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                color: colorScheme.surface,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}