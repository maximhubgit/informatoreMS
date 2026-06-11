import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/presentation/providers/zone_provider.dart';
import 'package:informatoreMS/presentation/providers/medici_provider.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';
import 'appuntamento_edit_screen.dart';
import 'package:uuid/uuid.dart';

/// Schermata per gestire gli appuntamenti concordati.
/// Mostra una tabella con filtri avanzati.
class AppuntamentiConcordatiScreen extends ConsumerStatefulWidget {
  const AppuntamentiConcordatiScreen({super.key});

  @override
  ConsumerState<AppuntamentiConcordatiScreen> createState() => _AppuntamentiConcordatiScreenState();
}

class _AppuntamentiConcordatiScreenState extends ConsumerState<AppuntamentiConcordatiScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Appuntamenti Concordati'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Aggiungi appuntamento',
            onPressed: showAddDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Ricerca + filtri nella stessa riga
          buildSearchAndFilters(context),
          const Divider(height: 1),
          // Tabella appuntamenti
          Expanded(child: buildTable(context)),
        ],
      ),
    );
  }

  Widget buildSearchAndFilters(BuildContext context) {
    final zoneSelezionate = ref.watch(zoneSelezionateConcordatiProvider);
    final dateRange = ref.watch(dateRangeConcordatiProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Campo ricerca
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cerca medico',
                hintText: 'Nome medico...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(filtroRicercaConcordatiProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
              onChanged: (value) => ref.read(filtroRicercaConcordatiProvider.notifier).state = value,
            ),
          ),
          const SizedBox(width: 8),
          // Tasto filtri unico
          IconButton(
            icon: Badge(
              isLabelVisible: zoneSelezionate.isNotEmpty || dateRange != null,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'Filtri avanzati',
            onPressed: () => showAdvancedFiltersDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> showAdvancedFiltersDialog(BuildContext context) async {
    final zoneAsync = ref.read(zoneProvider);
    final zoneSelezionate = ref.read(zoneSelezionateConcordatiProvider);
    final dateRange = ref.read(dateRangeConcordatiProvider);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            DateTime? startDate = dateRange?.$1;
            DateTime? endDate = dateRange?.$2;

            return AlertDialog(
              title: const Text('Filtri Avanzati'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sezione Zone
                      const Text('Zone', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      zoneAsync.when(
                        data: (zone) => Wrap(
                          spacing: 8,
                          children: zone.map((zona) {
                            final isSelected = zoneSelezionate.contains(zona.id);
                            return FilterChip(
                              label: Text(zona.nome),
                              selected: isSelected,
                              onSelected: (v) {
                                final nuovaLista = List<String>.from(zoneSelezionate);
                                if (v) {
                                  nuovaLista.add(zona.id);
                                } else {
                                  nuovaLista.remove(zona.id);
                                }
                                ref.read(zoneSelezionateConcordatiProvider.notifier).state = nuovaLista;
                              },
                            );
                          }).toList(),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 24),
                      // Sezione Date
                      const Text('Range Date', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                );
                                if (picked != null) {
                                  setState(() => startDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Inizio'),
                                child: Text(startDate?.formatItalia() ?? 'Seleziona'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate ?? DateTime.now().add(const Duration(days: 30)),
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                                );
                                if (picked != null) {
                                  setState(() => endDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Fine'),
                                child: Text(endDate?.formatItalia() ?? 'Seleziona'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    ref.read(zoneSelezionateConcordatiProvider.notifier).state = [];
                    ref.read(dateRangeConcordatiProvider.notifier).state = null;
                    Navigator.pop(context);
                  },
                  child: const Text('Pulisci'),
                ),
                TextButton(
                  onPressed: () {
                    if (startDate != null && endDate != null) {
                      ref.read(dateRangeConcordatiProvider.notifier).state = (startDate!, endDate!);
                    } else {
                      ref.read(dateRangeConcordatiProvider.notifier).state = null;
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget buildTable(BuildContext context) {
    final calendarioAsync = ref.watch(calendarioProvider);
    final mediciAsync = ref.watch(mediciProvider);
    final filtroTesto = ref.watch(filtroRicercaConcordatiProvider);
    final zoneSelezionate = ref.watch(zoneSelezionateConcordatiProvider);
    final dateRange = ref.watch(dateRangeConcordatiProvider);
    final fasceAsync = ref.watch(fasceOrarieProvider);

    return calendarioAsync.when(
      data: (appuntamenti) {
        var concordati = appuntamenti
            .where((a) => a.stato == StatoCalendario.concordato)
            .toList();

        // Costruisci un map medicoId -> zonaId della fascia principale
        final fasce = fasceAsync.asData?.value ?? [];
        final zonaPerMedico = <String, String>{};
        for (final fascia in fasce.where((f) => f.nr == 0)) {
          zonaPerMedico[fascia.idMedico] = fascia.zonaId;
        }

        // Applica filtro testuale su medico
        if (filtroTesto.isNotEmpty) {
          final medicoMap = ref.read(medicoByIdProvider);
          concordati = concordati.where((a) {
            final medico = medicoMap[a.medicoId];
            return medico?.nomeCompleto.toLowerCase().contains(filtroTesto.toLowerCase()) ?? false;
          }).toList();
        }

        // Applica filtro zones
        if (zoneSelezionate.isNotEmpty) {
          concordati = concordati.where((a) {
            return zoneSelezionate.contains(zonaPerMedico[a.medicoId]);
          }).toList();
        }

        // Applica filtro date
        if (dateRange != null) {
          concordati = concordati.where((a) {
            final appData = a.soloData;
            return (appData.isAtSameMomentAs(dateRange.$1) || appData.isAfter(dateRange.$1)) &&
                (appData.isAtSameMomentAs(dateRange.$2) || appData.isBefore(dateRange.$2));
          }).toList();
        }

        if (concordati.isEmpty) {
          return Center(
            child: Text(
              'Nessun appuntamento concordato',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: concordati.length,
          itemBuilder: (context, index) {
            final app = concordati[index];
            return mediciAsync.when(
              data: (medici) {
                final medico = medici.where((m) => m.id == app.medicoId).firstOrNull;
                return buildAppuntamentoTile(context, app, medico);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Errore: $err')),
    );
  }

  Widget buildAppuntamentoTile(
    BuildContext context,
    CalendarioAppuntamento app,
    Medico? medico,
  ) {
    final zoneAsync = ref.watch(zoneProvider);

    // Prendi la zona dalla fascia principale del medico
    final fasceAsync = ref.watch(fasceOrarieProvider);
    final fasce = fasceAsync.asData?.value ?? [];
    final fasciaPrincipale = fasce.where((f) => f.idMedico == app.medicoId && f.nr == 0).firstOrNull;

    final zona = zoneAsync.when(
      data: (zone) => fasciaPrincipale != null ? zone.where((z) => z.id == fasciaPrincipale.zonaId).firstOrNull : null,
      loading: () => null,
      error: (_, __) => null,
    );

    // Conta appuntamenti con lo stesso stato per lo stesso giorno
    final calendario = ref.watch(calendarioProvider).valueOrNull ?? [];
    final stessoGiorno = calendario.where((a) => a.soloData.isAtSameMomentAs(app.soloData));
    final concordatiCount = stessoGiorno.where((a) => a.stato == StatoCalendario.concordato).length;
    final propostiCount = stessoGiorno.where((a) => a.stato == StatoCalendario.proposto).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          if (medico != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AppuntamentoEditScreen(
                  medico: medico,
                  appuntamento: app,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    medico?.nomeCompleto ?? 'Medico sconosciuto',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    app.soloData.formatItalia(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    app.oraFormattata,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (zona != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: zona.colore,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(zona.nome, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const Spacer(),
                  if (concordatiCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$concordatiCount',
                        style: TextStyle(
                          color: Colors.teal.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (concordatiCount > 0 && propostiCount > 0) const SizedBox(width: 4),
                  if (propostiCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$propostiCount',
                        style: TextStyle(
                          color: Colors.indigo.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showAddDialog() {
    final mediciAsync = ref.read(mediciProvider);

    showDialog(
      context: context,
      builder: (context) {
        String? selectedMedicoId;
        DateTime? selectedDate;
        TimeOfDay? selectedTime;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Nuovo Appuntamento'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ricerca medico
                      mediciAsync.when(
                        data: (medici) {
                          return SearchAnchor(
                            builder: (context, controller) => TextField(
                              decoration: InputDecoration(
                                labelText: 'Cerca medico',
                                prefixIcon: const Icon(Icons.search),
                                hintText: 'Nome medico...',
                                isDense: true,
                              ),
                              onChanged: (value) {
                                controller.openView();
                              },
                              onTap: () {
                                controller.openView();
                              },
                              onSubmitted: (value) {
                                controller.closeView(value);
                              },
                            ),
                            suggestionsBuilder: (context, controller) {
                              final query = controller.text.toLowerCase();
                              final filtered = query.isEmpty
                                  ? medici
                                  : medici.where((m) => m.nomeCompleto.toLowerCase().contains(query)).toList();

                              return filtered.map((medico) => ListTile(
                                    title: Text(medico.nomeCompleto),
                                    onTap: () {
                                      setState(() {
                                        selectedMedicoId = medico.id;
                                      });
                                      controller.closeView(medico.nomeCompleto);
                                    },
                                  ));
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                      // Data
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(selectedDate?.formatItalia() ?? 'Seleziona data'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Orario
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (picked != null) {
                            setState(() => selectedTime = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Orario',
                            suffixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(selectedTime?.formatTime() ?? 'Seleziona ora'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedMedicoId != null && selectedDate != null) {
                      final medici = mediciAsync.valueOrNull ?? [];
                      final medico = medici.where((m) => m.id == selectedMedicoId).firstOrNull;

                      if (medico != null) {
                        final dateTime = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                          selectedTime?.hour ?? 9,
                          selectedTime?.minute ?? 0,
                        );

                        await ref.read(salvaAppuntamentoProvider)(
                          CalendarioAppuntamento(
                            id: const Uuid().v4(),
                            medicoId: medico.id,
                            data: dateTime,
                            stato: StatoCalendario.concordato,
                            dataCreazione: DateTime.now(),
                          ),
                        );
                        ref.refresh(calendarioProvider);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Appuntamento aggiunto')),
                          );
                        }
                      }
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Provider per filtrare gli appuntamenti concordati per ricerca testuale.
final filtroRicercaConcordatiProvider = StateProvider<String>((ref) => '');

/// Provider per le zone selezionate nel filtro.
final zoneSelezionateConcordatiProvider = StateProvider<List<String>>((ref) => []);

/// Provider per il range date.
final dateRangeConcordatiProvider = StateProvider<(DateTime, DateTime)?>((ref) => null);
