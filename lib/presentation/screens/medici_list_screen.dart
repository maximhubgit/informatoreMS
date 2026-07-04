import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/extensions/specializzazione_extension.dart';
import 'package:informatoreMS/core/models/distretto.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/core/models/zona.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';
import 'package:informatoreMS/presentation/providers/distretto_provider.dart';
import 'package:informatoreMS/presentation/providers/distritti_selezionati_provider.dart';
import 'package:informatoreMS/presentation/providers/medici_provider.dart';
import 'package:informatoreMS/presentation/providers/specializzazione_provider.dart';
import 'package:informatoreMS/presentation/providers/zone_provider.dart';
import 'package:informatoreMS/presentation/providers/zone_selezionate_provider.dart';
import 'medico_edit_screen.dart';

enum OrdinamentoMedico { alfabetico, prossimaVisita, distretto }

final ordinamentoMedicoProvider = StateProvider<OrdinamentoMedico>((ref) => OrdinamentoMedico.alfabetico);

class MediciListScreen extends ConsumerStatefulWidget {
  const MediciListScreen({super.key});

  @override
  ConsumerState<MediciListScreen> createState() => _MediciListScreenState();
}

class _MediciListScreenState extends ConsumerState<MediciListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediciAsync = ref.watch(mediciProvider);
    final ordinamento = ref.watch(ordinamentoMedicoProvider);
    // Mappe memoizzate: calcolate una volta per render, condivise
    // tra ricerca, ordinamento, filtro e costruzione dei tile.
    final zonaPerMedico = ref.watch(zonaPerMedicoProvider);
    final distrettoPerMedico = ref.watch(distrettoPerMedicoProvider);
    final zoneMap = ref.watch(zonaByIdProvider);
    final prossimeVisite = ref.watch(prossimeVisiteProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medici'),
        centerTitle: true,
        actions: [
          PopupMenuButton<OrdinamentoMedico>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              ref.read(ordinamentoMedicoProvider.notifier).state = value;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: OrdinamentoMedico.alfabetico,
                child: Text('Ordine alfabetico'),
              ),
              const PopupMenuItem(
                value: OrdinamentoMedico.prossimaVisita,
                child: Text('Per prossima visita'),
              ),
              const PopupMenuItem(
                value: OrdinamentoMedico.distretto,
                child: Text('Per distretto'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MedicoEditScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra di ricerca
          _buildSearchBar(),
          // Filtri distretto e zona
          _buildFilterRow(ref),
          const Divider(height: 1),
          // Lista medici
          Expanded(
            child: mediciAsync.when(
              data: (medici) {
                final mediciFiltrati = _filtraMedici(medici);

                if (mediciFiltrati.isEmpty) {
                  return _emptyState(context);
                }

                final mediciOrdinati = _ordinaMedici(
                  mediciFiltrati,
                  distrettoPerMedico,
                  zonaPerMedico,
                  prossimeVisite,
                  ordinamento,
                  zoneMap,
                );

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: mediciOrdinati.length,
                  itemBuilder: (context, index) {
                    final medico = mediciOrdinati[index];
                    return Dismissible(
                      key: Key(medico.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Medico eliminato')),
                        );
                      },
                      child: _buildMedicoTile(context, medico, ref),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Errore: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Cerca medico, indirizzo, zona, telefono...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Pulisci',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow(WidgetRef ref) {
    final distrittiSelezionati = ref.watch(distrittiSelezionatiProvider);
    final zoneSelezionate = ref.watch(zoneSelezionateProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Dropdown distretti
          Expanded(
            child: _DistrettoDropdown(
              selectedCodes: distrittiSelezionati,
              onSelectionChanged: (Set<int> newSelection) {
                ref.read(distrittiSelezionatiProvider.notifier).replaceAll(newSelection);
              },
              onClear: () => ref.read(distrittiSelezionatiProvider.notifier).clearAll(),
            ),
          ),
          const SizedBox(width: 8),
          // Dropdown zone
          Expanded(
            child: _ZonaDropdown(
              selectedIds: zoneSelezionate,
              onSelectionChanged: (Set<String> newSelection) {
                ref.read(zoneSelezionateProvider.notifier).replaceAll(newSelection);
              },
              onClear: () => ref.read(zoneSelezionateProvider.notifier).clearAll(),
            ),
          ),
        ],
      ),
    );
  }

  /// Filtra i medici in base a ricerca, distretti selezionati e zone selezionate.
  List<Medico> _filtraMedici(List<Medico> medici) {
    final distrittiSelezionati = ref.watch(distrittiSelezionatiProvider);
    final zoneSelezionate = ref.watch(zoneSelezionateProvider);
    final fasciaPrincipaleMap = ref.watch(fasciaPrincipaleProvider);
    final zoneMap = ref.watch(zonaByIdProvider);

    Iterable<Medico> result = medici;

    // Filtro per distretti (usa la mappa O(1))
    if (distrittiSelezionati.isNotEmpty) {
      result = result.where((m) {
        final fascia = fasciaPrincipaleMap[m.id];
        return fascia != null && distrittiSelezionati.contains(fascia.distrettoId);
      });
    }

    // Filtro per zone (usa la mappa O(1))
    if (zoneSelezionate.isNotEmpty) {
      result = result.where((m) {
        final fascia = fasciaPrincipaleMap[m.id];
        return fascia != null && zoneSelezionate.contains(fascia.zonaId);
      });
    }

    // Filtro ricerca testo
    if (_searchQuery.isNotEmpty) {
      result = result.where((m) {
        final fascia = fasciaPrincipaleMap[m.id];
        final zona = fascia != null ? zoneMap[fascia.zonaId] : null;
        final haystack = [
          m.nome,
          m.telefono ?? '',
          fascia?.struttura ?? '',
          fascia?.indirizzo ?? '',
          zona?.nome ?? '',
        ].join(' ').toLowerCase();
        return haystack.contains(_searchQuery);
      });
    }

    return result.toList();
  }

  /// Ordina i medici usando le mappe memoizzate passate dal build().
  List<Medico> _ordinaMedici(
    List<Medico> medici,
    Map<String, Distretto> distrettoPerMedico,
    Map<String, String> zonaPerMedico,
    Map<String, DateTime?> prossimeVisite,
    OrdinamentoMedico ordinamento,
    Map<String, Zona> zoneMap,
  ) {
    final result = List<Medico>.from(medici);

    switch (ordinamento) {
      case OrdinamentoMedico.alfabetico:
        result.sort((a, b) => a.nomeCompleto.compareTo(b.nomeCompleto));
      case OrdinamentoMedico.prossimaVisita:
        result.sort((a, b) {
          final aVisita = prossimeVisite[a.id];
          final bVisita = prossimeVisite[b.id];
          if (aVisita == null && bVisita == null) return 0;
          if (aVisita == null) return 1;
          if (bVisita == null) return -1;
          return aVisita.compareTo(bVisita);
        });
      case OrdinamentoMedico.distretto:
        result.sort((a, b) {
          final aDistretto = distrettoPerMedico[a.id]?.campoDescrittivo ?? '';
          final bDistretto = distrettoPerMedico[b.id]?.campoDescrittivo ?? '';
          return aDistretto.compareTo(bDistretto);
        });
    }

    return result;
  }

  Widget _emptyState(BuildContext context) {
    final distrittiSelezionati = ref.watch(distrittiSelezionatiProvider);
    final zoneSelezionate = ref.watch(zoneSelezionateProvider);

    final bool hasFiltri = distrittiSelezionati.isNotEmpty ||
        zoneSelezionate.isNotEmpty ||
        _searchQuery.isNotEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFiltri ? Icons.search_off_rounded : Icons.medical_services_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            hasFiltri ? 'Nessun medico trovato' : 'Nessun medico registrato',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
          if (hasFiltri) ...[
            const SizedBox(height: 4),
            Text(
              'Prova a modificare i filtri',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                ref.read(distrittiSelezionatiProvider.notifier).clearAll();
                ref.read(zoneSelezionateProvider.notifier).clearAll();
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset filtri'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicoTile(
    BuildContext context,
    Medico medico,
    WidgetRef ref,
  ) {
    // Lookup O(1) nelle mappe memoizzate
    final zoneMap = ref.read(zonaByIdProvider);
    final distrettoMap = ref.read(distrettoByCodiceProvider);
    final specializzazioniMap = ref.read(specializzazioneByIdProvider);
    final specializzazione = specializzazioniMap[medico.specializzazioneId];
    final prossimaVisita = ref.read(prossimaVisitaPerMedicoProvider(medico.id));
    final fasciaPrincipale = ref.read(fasciaPrincipaleProvider)[medico.id];
    final zona = fasciaPrincipale != null ? zoneMap[fasciaPrincipale.zonaId] : null;
    final distretto = fasciaPrincipale != null
        ? distrettoMap[fasciaPrincipale.distrettoId]
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            specializzazione?.iconaSpecializzazione ?? Icons.local_hospital,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          medico.nomeCompleto,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(specializzazione?.nome ?? 'Specializzazione sconosciuta'),
            Text('Distretto: ${distretto?.descrizione ?? 'Sconosciuto'}'),
            Text('Zona: ${zona?.nome ?? 'Sconosciuta'}'),
            if (fasciaPrincipale?.struttura != null && fasciaPrincipale!.struttura!.isNotEmpty)
              Text('Struttura: ${fasciaPrincipale.struttura}'),
            if (prossimaVisita != null)
              Text('Prossima visita: ${prossimaVisita.formatItalia()}'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MedicoEditScreen(medico: medico),
            ),
          );
        },
      ),
    );
  }
}

// Dropdown multiselezione per i distretti
class _DistrettoDropdown extends ConsumerWidget {
  final Set<int> selectedCodes;
  final ValueChanged<Set<int>> onSelectionChanged;
  final VoidCallback onClear;

  const _DistrettoDropdown({
    required this.selectedCodes,
    required this.onSelectionChanged,
    required this.onClear,
  });

  String _truncateLabel(String text, int maxLength) {
    // Rimuove i ritorni a capo e tronca
    final cleanText = text.replaceAll('\n', ' ').replaceAll('\r', '');
    return cleanText.length <= maxLength ? cleanText : '${cleanText.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showMultiSelectDialog(context, ref),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Distretti',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.location_city_rounded),
          suffixIcon: Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(
          selectedCodes.isEmpty
              ? 'Seleziona distretti'
              : '${selectedCodes.length} selezionati',
          style: TextStyle(
            color: selectedCodes.isEmpty
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Future<void> _showMultiSelectDialog(BuildContext context, WidgetRef ref) async {
    final distrittiAsync = ref.watch(distrettoProvider);
    final selected = Set<int>.from(selectedCodes);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Seleziona distretti'),
              content: SizedBox(
                width: double.maxFinite,
                child: distrittiAsync.when(
                  data: (distretti) => SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: distretti.map((d) {
                        final isSelected = selected.contains(d.codice);
                        return CheckboxListTile(
                          title: Text(_truncateLabel(d.campoDescrittivo, 20)),
                          value: isSelected,
                          onChanged: (v) {
                            setStateDialog(() {
                              if (v == true) {
                                selected.add(d.codice);
                              } else {
                                selected.remove(d.codice);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Errore caricamento distretti'),
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
                    onSelectionChanged(selected);
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
}

// Dropdown multiselezione per le zone
class _ZonaDropdown extends ConsumerWidget {
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final VoidCallback onClear;

  const _ZonaDropdown({
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showMultiSelectDialog(context, ref),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Zone',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.map_rounded),
          suffixIcon: Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(
          selectedIds.isEmpty
              ? 'Seleziona zone'
              : '${selectedIds.length} selezionate',
          style: TextStyle(
            color: selectedIds.isEmpty
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Future<void> _showMultiSelectDialog(BuildContext context, WidgetRef ref) async {
    final zoneAsync = ref.watch(zoneProvider);
    final selected = Set<String>.from(selectedIds);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Seleziona zone'),
              content: SizedBox(
                width: double.maxFinite,
                child: zoneAsync.when(
                  data: (zone) => SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: zone.map((z) {
                        final isSelected = selected.contains(z.id);
                        return CheckboxListTile(
                          title: Text(z.nome),
                          value: isSelected,
                          onChanged: (v) {
                            setStateDialog(() {
                              if (v == true) {
                                selected.add(z.id);
                              } else {
                                selected.remove(z.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Errore caricamento zone'),
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
                    onSelectionChanged(selected);
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
}