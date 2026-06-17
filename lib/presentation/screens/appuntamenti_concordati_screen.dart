import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/extensions/specializzazione_extension.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/fascia_oraria.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/core/models/specializzazione.dart';
import 'package:informatoreMS/core/models/zona.dart';
import 'package:informatoreMS/presentation/providers/medici_provider.dart';
import 'package:informatoreMS/presentation/providers/zone_provider.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';
import 'package:informatoreMS/presentation/providers/specializzazione_provider.dart';
import 'appuntamento_edit_screen.dart';
import 'package:uuid/uuid.dart';

/// Schermata per gestire gli appuntamenti concordati.
/// Layout moderno: ricerca, filtri rapidi, lista raggruppata per giorno.
class AppuntamentiConcordatiScreen extends ConsumerStatefulWidget {
  const AppuntamentiConcordatiScreen({super.key});

  @override
  ConsumerState<AppuntamentiConcordatiScreen> createState() => _AppuntamentiConcordatiScreenState();
}

class _AppuntamentiConcordatiScreenState extends ConsumerState<AppuntamentiConcordatiScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Filtro per stato: null = tutti, altrimenti stato specifico.
  StatoCalendario? _statoFilter;

  /// Filtro rapido per range date.
  _DateRangePreset _rangePreset = _DateRangePreset.all;

  /// Range personalizzato (usato quando _rangePreset == custom).
  (DateTime, DateTime)? _customRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Concordati'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filtri avanzati',
            onPressed: _showAdvancedFiltersDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterRow(),
          const Divider(height: 1),
          Expanded(child: _buildGroupedList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo'),
      ),
    );
  }

  // ── Barra di ricerca ────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Cerca medico, struttura, indirizzo...',
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

  // ── Riga di chip per stato e range rapido ──────────────────────────────
  Widget _buildFilterRow() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _statusChip(label: 'Tutti', value: null),
          _statusChip(label: 'Concordati', value: StatoCalendario.concordato, defaultSelected: true),
          _statusChip(label: 'Proposti', value: StatoCalendario.proposto),
          _statusChip(label: 'Confermati', value: StatoCalendario.confermato),
          _statusChip(label: 'Fatti', value: StatoCalendario.fatto),
          _statusChip(label: 'Annullati', value: StatoCalendario.annullato),
          const VerticalDivider(width: 16, indent: 8, endIndent: 8),
          _rangeChip(_DateRangePreset.all, 'Tutto'),
          _rangeChip(_DateRangePreset.today, 'Oggi'),
          _rangeChip(_DateRangePreset.week, 'Settimana'),
          _rangeChip(_DateRangePreset.month, 'Mese'),
          _rangeChip(_DateRangePreset.custom, 'Custom…'),
        ],
      ),
    );
  }

  Widget _statusChip({required String label, required StatoCalendario? value, bool defaultSelected = false}) {
    // Se nessun filtro esplicito e non è il default, mostra "Tutti" non selezionato
    final isActive = (value == null && _statoFilter == null) || _statoFilter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: FilterChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) => setState(() => _statoFilter = value),
      ),
    );
  }

  Widget _rangeChip(_DateRangePreset value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: _rangePreset == value,
        onSelected: (_) {
          if (value == _DateRangePreset.custom) {
            _showAdvancedFiltersDialog();
            return;
          }
          setState(() {
            _rangePreset = value;
            _customRange = null;
          });
        },
      ),
    );
  }

  // ── Lista raggruppata per giorno ───────────────────────────────────────
  Widget _buildGroupedList() {
    final calendarioAsync = ref.watch(calendarioProvider);
    final mediciAsync = ref.watch(mediciProvider);
    final specialMap = ref.watch(specializzazioneByIdProvider);
    final fasceById = ref.watch(fasciaByIdProvider);
    final zoneAsync = ref.watch(zoneProvider);

    return calendarioAsync.when(
      data: (appuntamenti) {
        final filtrati = _filter(appuntamenti);
        if (filtrati.isEmpty) {
          return _emptyState();
        }

        // Ordina per data crescente
        final ordinati = List<CalendarioAppuntamento>.from(filtrati)
          ..sort((a, b) => a.data.compareTo(b.data));

        // Raggruppa per giorno
        final gruppi = <DateTime, List<CalendarioAppuntamento>>{};
        for (final app in ordinati) {
          final key = app.soloData;
          gruppi.putIfAbsent(key, () => []).add(app);
        }
        final chiaviGiorni = gruppi.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: chiaviGiorni.length,
          itemBuilder: (context, i) {
            final giorno = chiaviGiorni[i];
            final apps = gruppi[giorno]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DateHeader(date: giorno, count: apps.length),
                ...apps.map((app) {
                  final medico = mediciAsync.valueOrNull
                      ?.where((m) => m.id == app.medicoId)
                      .firstOrNull;
                  return _AppuntamentoCard(
                    app: app,
                    medico: medico,
                    specializzazione: medico != null ? specialMap[medico.specializzazioneId] : null,
                    fasceById: fasceById,
                    zone: zoneAsync.asData?.value ?? const [],
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
                    onDelete: () => _deleteAppuntamento(app),
                  );
                }),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Errore: $err')),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'Nessun appuntamento trovato',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          if (_searchQuery.isNotEmpty || _statoFilter != null || _rangePreset != _DateRangePreset.all) ...[
            const SizedBox(height: 4),
            Text(
              'Prova a modificare i filtri',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _statoFilter = StatoCalendario.concordato;
                  _rangePreset = _DateRangePreset.all;
                  _customRange = null;
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset filtri'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Filtri ─────────────────────────────────────────────────────────────
  List<CalendarioAppuntamento> _filter(List<CalendarioAppuntamento> tutti) {
    Iterable<CalendarioAppuntamento> result = tutti;

    // Filtro stato (default: concordato)
    final stato = _statoFilter ?? StatoCalendario.concordato;
    result = result.where((a) => a.stato == stato);

    // Filtro range rapido
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final (DateTime start, DateTime end) = switch (_rangePreset) {
      _DateRangePreset.all => (
          DateTime(2000),
          DateTime(2100),
        ),
      _DateRangePreset.today => (today, today),
      _DateRangePreset.week => (
          today.subtract(const Duration(days: 7)),
          today.add(const Duration(days: 7)),
        ),
      _DateRangePreset.month => (
          DateTime(today.year, today.month, 1),
          DateTime(today.year, today.month + 1, 0),
        ),
      _DateRangePreset.custom => _customRange ?? (DateTime(2000), DateTime(2100)),
    };
    result = result.where((a) {
      final d = a.soloData;
      return !d.isBefore(start) && !d.isAfter(end);
    });

    // Filtro ricerca testo
    if (_searchQuery.isNotEmpty) {
      final mediciMap = ref.read(medicoByIdProvider);
      final fasceMap = ref.read(fasciaByIdProvider);
      result = result.where((app) {
        final medico = mediciMap[app.medicoId];
        final fascia = app.fasciaOrariaId != null
            ? fasceMap[app.fasciaOrariaId]
            : null;
        final haystack = [
          medico?.nome ?? '',
          medico?.telefono ?? '',
          fascia?.struttura ?? '',
          fascia?.indirizzo ?? '',
          app.note ?? '',
        ].join(' ').toLowerCase();
        return haystack.contains(_searchQuery);
      });
    }

    return result.toList();
  }

  Future<void> _deleteAppuntamento(CalendarioAppuntamento app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina appuntamento'),
        content: Text('Eliminare l\'appuntamento del ${app.soloData.formatItalia()} alle ${app.oraFormattata}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(eliminaAppuntamentoProvider)(app.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appuntamento eliminato')),
        );
      }
    }
  }

  // ── Dialog filtri avanzati (range personalizzato) ──────────────────────
  Future<void> _showAdvancedFiltersDialog() async {
    DateTime? startDate = _customRange?.$1;
    DateTime? endDate = _customRange?.$2;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Filtri avanzati'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Range date personalizzato',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Da',
                          value: startDate,
                          onPick: (picked) => setStateDialog(() => startDate = picked),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          label: 'A',
                          value: endDate,
                          onPick: (picked) => setStateDialog(() => endDate = picked),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _customRange = null;
                      _rangePreset = _DateRangePreset.all;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Reset'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      if (startDate != null && endDate != null) {
                        _customRange = (startDate!, endDate!);
                        _rangePreset = _DateRangePreset.custom;
                      } else {
                        _customRange = null;
                        _rangePreset = _DateRangePreset.all;
                      }
                    });
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

  // ── Dialog nuovo appuntamento ──────────────────────────────────────────
  Future<void> _showAddDialog() async {
    final mediciAsync = ref.read(mediciProvider);

    String? selectedMedicoId;
    String? selectedFasciaId;
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    Medico? selectedMedico;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            final fasceAsync = selectedMedicoId != null
                ? ref.watch(fasceOrarieMedicoProvider(selectedMedicoId!))
                : const AsyncData(<FasciaOraria>[]);

            return AlertDialog(
              title: const Text('Nuovo appuntamento'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Selezione medico
                      mediciAsync.when(
                        data: (medici) => _MedicoPicker(
                          selected: selectedMedico,
                          medici: medici,
                          onPick: (m) => setStateDialog(() {
                            selectedMedico = m;
                            selectedMedicoId = m.id;
                            selectedFasciaId = null;
                          }),
                          onClear: () => setStateDialog(() {
                            selectedMedico = null;
                            selectedMedicoId = null;
                            selectedFasciaId = null;
                          }),
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const Text('Errore caricamento medici'),
                      ),

                      const SizedBox(height: 16),

                      // ── Selezione fascia (obbligatoria)
                      if (selectedMedicoId != null) ...[
                        fasceAsync.when(
                          data: (fasce) {
                            if (fasce.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Nessuna fascia oraria per questo medico. Aggiungi almeno una fascia nell\'anagrafica del medico.',
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                                ),
                              );
                            }
                            return DropdownButtonFormField<String>(
                              initialValue: selectedFasciaId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Fascia oraria *',
                                helperText: 'Obbligatoria: serve per identificare struttura e indirizzo',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.schedule_rounded),
                              ),
                              items: fasce
                                  .map((f) => DropdownMenuItem<String>(
                                        value: f.id,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${f.inizio.formatTime()} – ${f.fine.formatTime()}${f.nr == 0 ? " (principale)" : ""}',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if ((f.struttura != null && f.struttura!.isNotEmpty) ||
                                                (f.indirizzo != null && f.indirizzo!.isNotEmpty))
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                  [
                                                    if (f.struttura != null && f.struttura!.isNotEmpty) f.struttura!,
                                                    if (f.indirizzo != null && f.indirizzo!.isNotEmpty) f.indirizzo!,
                                                  ].join(' — '),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setStateDialog(() => selectedFasciaId = v),
                              validator: (v) => v == null
                                  ? 'Seleziona la fascia oraria (struttura/indirizzo)'
                                  : null,
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Data
                      _DateField(
                        label: 'Data',
                        value: selectedDate,
                        onPick: (picked) => setStateDialog(() => selectedDate = picked),
                      ),

                      const SizedBox(height: 16),

                      // ── Orario
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (picked != null) {
                            setStateDialog(() => selectedTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Orario',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.access_time_rounded),
                          ),
                          child: Text(selectedTime?.formatTime() ?? 'Seleziona'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annulla'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Salva'),
                  onPressed: () async {
                    if (selectedMedico == null || selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seleziona medico e data')),
                      );
                      return;
                    }
                    if (selectedFasciaId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Seleziona la fascia oraria: è obbligatoria per identificare struttura e indirizzo'),
                        ),
                      );
                      return;
                    }
                    final dateTime = DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime?.hour ?? 9,
                      selectedTime?.minute ?? 0,
                    );
                    // Recupero la fascia selezionata per derivare anche il numero progressivo (backward compat)
                    final fasceMedico = ref.read(fasceOrarieMedicoProvider(selectedMedico!.id)).valueOrNull ?? [];
                    final fasciaSelezionata = fasceMedico.firstWhere(
                      (f) => f.id == selectedFasciaId,
                      orElse: () => fasceMedico.isNotEmpty ? fasceMedico.first : const FasciaOraria(
                        idMedico: '',
                        nr: 0,
                        minutiInizio: 0,
                        minutiFine: 0,
                        distrettoId: 0,
                        zonaId: '',
                      ),
                    );
                    await ref.read(salvaAppuntamentoProvider)(
                      CalendarioAppuntamento(
                        id: const Uuid().v4(),
                        medicoId: selectedMedico!.id,
                        data: dateTime,
                        stato: StatoCalendario.concordato,
                        dataCreazione: DateTime.now(),
                        fasciaOrariaId: selectedFasciaId, // <-- ID della fascia salvato
                        fasciaNumero: fasciaSelezionata.nr == 0 ? null : fasciaSelezionata.nr,
                      ),
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Appuntamento aggiunto')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers riusabili
// ────────────────────────────────────────────────────────────────────────────

enum _DateRangePreset { all, today, week, month, custom }

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final int count;

  const _DateHeader({required this.date, required this.count});

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    if (date.isAtSameMomentAs(today)) return 'Oggi';
    if (date.isAtSameMomentAs(yesterday)) return 'Ieri';
    if (date.isAtSameMomentAs(tomorrow)) return 'Domani';
    return '${_giornoSettimanaLabel(date.weekday)}, ${date.formatItalia()}';
  }

  static String _giornoSettimanaLabel(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'Lunedì',
      DateTime.tuesday => 'Martedì',
      DateTime.wednesday => 'Mercoledì',
      DateTime.thursday => 'Giovedì',
      DateTime.friday => 'Venerdì',
      DateTime.saturday => 'Sabato',
      DateTime.sunday => 'Domenica',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppuntamentoCard extends StatelessWidget {
  final CalendarioAppuntamento app;
  final Medico? medico;
  final Specializzazione? specializzazione;
  final Map<String, FasciaOraria> fasceById;
  final List<Zona> zone;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AppuntamentoCard({
    required this.app,
    required this.medico,
    required this.specializzazione,
    required this.fasceById,
    required this.zone,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Lookup O(1) via mappa (vedi `fasciaByIdProvider`) invece di una
    // scansione lineare su tutte le fasce: con 1630 fasce e molti
    // appuntamenti la scansione era O(n*m).
    final fascia = app.fasciaOrariaId != null
        ? fasceById[app.fasciaOrariaId]
        : null;
    final spec = specializzazione;
    final telefono = medico?.telefono?.trim();
    final hasTelefono = telefono != null && telefono.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Dismissible(
        key: ValueKey('app-${app.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_rounded, color: Colors.red.shade700),
        ),
        confirmDismiss: (_) async {
          onDelete();
          return false; // la cancellazione effettiva è gestita dalla conferma
        },
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Orario in primo piano a sinistra
                  Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          app.oraFormattata,
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Contenuto principale
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (spec != null) ...[
                              Icon(
                                spec.iconaSpecializzazione,
                                size: 16,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                medico?.nomeCompleto ?? 'Medico sconosciuto',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (spec != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            spec.nome,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (fascia?.struttura != null && fascia!.struttura!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.business_rounded, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  fascia.struttura!,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (fascia?.indirizzo != null && fascia!.indirizzo!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.place_rounded, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  fascia.indirizzo!,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (hasTelefono) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.phone_rounded, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  telefono,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today_rounded),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => onPick(DateTime(0)),
                )
              : const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(
          (value == null || value!.year < 1900) ? 'Seleziona' : value!.formatItalia(),
        ),
      ),
    );
  }
}

class _MedicoPicker extends StatefulWidget {
  final Medico? selected;
  final List<Medico> medici;
  final ValueChanged<Medico> onPick;
  final VoidCallback onClear;

  const _MedicoPicker({
    required this.selected,
    required this.medici,
    required this.onPick,
    required this.onClear,
  });

  @override
  State<_MedicoPicker> createState() => _MedicoPickerState();
}

class _MedicoPickerState extends State<_MedicoPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openPicker(BuildContext context) async {
    final picked = await showDialog<Medico>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            final filtered = _query.isEmpty
                ? widget.medici
                : widget.medici
                    .where((m) => m.nomeCompleto.toLowerCase().contains(_query.toLowerCase()))
                    .toList();
            return AlertDialog(
              title: const Text('Seleziona medico'),
              content: SizedBox(
                width: 360,
                height: 480,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Cerca...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setStateDialog(() => _query = v),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Nessun medico'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final m = filtered[i];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person_rounded, size: 18),
                                  ),
                                  title: Text(m.nomeCompleto),
                                  onTap: () => Navigator.pop(ctx, m),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Chiudi'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) widget.onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _openPicker(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Medico',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.person_search_rounded),
          suffixIcon: widget.selected != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: widget.onClear,
                )
              : const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(
          widget.selected?.nomeCompleto ?? 'Seleziona medico',
          style: TextStyle(
            color: widget.selected != null ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
