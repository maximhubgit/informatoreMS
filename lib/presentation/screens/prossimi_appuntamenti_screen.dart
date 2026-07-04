import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/extensions/specializzazione_extension.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/core/models/zona.dart';
import 'package:informatoreMS/presentation/providers/zone_provider.dart';
import 'package:informatoreMS/presentation/providers/zone_selezionate_provider.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';
import 'package:informatoreMS/presentation/providers/medici_provider.dart';
import 'package:informatoreMS/presentation/providers/specializzazione_provider.dart';
import 'package:informatoreMS/presentation/providers/distretto_provider.dart';
import 'package:informatoreMS/presentation/providers/distretti_selezionati_provider.dart';
import 'package:informatoreMS/core/models/distretto.dart';
import 'package:informatoreMS/domain/usecases/esporta_appuntamenti_usecase.dart';
import 'package:file_saver/file_saver.dart';

class ProssimiAppuntamentiScreen extends ConsumerWidget {
  const ProssimiAppuntamentiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarioAsync = ref.watch(calendarioProvider);
    final zoneAsync = ref.watch(zoneProvider);
    final zoneSelezionate = ref.watch(zoneSelezionateProvider);
    final distrettiSelezionati = ref.watch(distrettiSelezionatiProvider);
    final medicoMap = ref.watch(medicoByIdProvider);
    final zonaPerMedico = ref.watch(zonaPerMedicoProvider);
    final distrettoPerMedico = ref.watch(distrettoPerMedicoProvider);

    final maxMedici = ref.watch(maxMediciPerGiornoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pianifica'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Imposta range date',
            onPressed: () {
              _showRangeDialog(context, ref);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Max $maxMedici medici/giorno',
            onPressed: () {
              _showMaxMediciDialog(context, ref);
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog(context, ref, zoneAsync);
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Esporta in Excel',
            onPressed: () {
              _esportaExcel(context, ref, calendarioAsync.valueOrNull ?? [], zoneSelezionate, zonaPerMedico);
            },
          ),
        ],
      ),
      body: calendarioAsync.when(
        data: (appuntamenti) {
          final bool hasFiltri = zoneSelezionate.isNotEmpty || distrettiSelezionati.isNotEmpty;
          final proposti = appuntamenti.where((a) {
            if (a.stato.isConcluso) return false;
            if (!hasFiltri) return true;
            // Filtro per zona
            if (zoneSelezionate.isNotEmpty &&
                !zoneSelezionate.contains(zonaPerMedico[a.medicoId])) {
              return false;
            }
            // Filtro per distretto
            if (distrettiSelezionati.isNotEmpty) {
              final distretto = distrettoPerMedico[a.medicoId];
              if (distretto == null || !distrettiSelezionati.contains(distretto.codice)) {
                return false;
              }
            }
            return true;
          }).toList();

          // Separa gli scaduti (concordati/confermati con data passata) dai futuri
          final scaduti = proposti.where((a) => a.isScaduto).toList();
          final futuri = proposti.where((a) => !a.isScaduto).toList();

          if (proposti.isEmpty) {
            return _emptyState(context);
          }

          final sortedFuturi = List<CalendarioAppuntamento>.from(futuri)
            ..sort((a, b) => a.data.compareTo(b.data));
          final sortedScaduti = List<CalendarioAppuntamento>.from(scaduti)
            ..sort((a, b) => a.data.compareTo(b.data));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (sortedScaduti.isNotEmpty) ...[
                _sectionHeader(
                  'Scaduti (${sortedScaduti.length})',
                  color: Colors.orange,
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(height: 8),
                ...sortedScaduti.map((app) {
                  final medico = medicoMap[app.medicoId];
                  return _buildAppuntamentoTile(context, app, medico, ref, isScaduto: true);
                }),
                const SizedBox(height: 16),
              ],
              ...sortedFuturi.map((app) {
                final medico = medicoMap[app.medicoId];
                return _buildAppuntamentoTile(context, app, medico, ref, isScaduto: false);
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Errore: $err')),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun appuntamento futuro',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  /// Header di sezione con colore di sfondo.
  Widget _sectionHeader(String title, {required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppuntamentoTile(
    BuildContext context,
    CalendarioAppuntamento app,
    Medico? medico,
    WidgetRef ref, {
    bool isScaduto = false,
  }) {
    final specialMap = ref.watch(specializzazioneByIdProvider);
    final fasciaMap = ref.watch(fasciaByIdProvider);
    final specializzazione = medico != null ? specialMap[medico.specializzazioneId] : null;
    final fascia = app.fasciaOrariaId != null ? fasciaMap[app.fasciaOrariaId] : null;
    final hasFasciaInfo = fascia != null &&
        ((fascia.struttura != null && fascia.struttura!.isNotEmpty) ||
            (fascia.indirizzo != null && fascia.indirizzo!.isNotEmpty));
    final telefono = medico?.telefono?.trim();
    final hasTelefono = telefono != null && telefono.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isScaduto ? Colors.orange.shade50 : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: specializzazione?.coloreSpecializzazione ?? Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            specializzazione?.iconaSpecializzazione ?? Icons.help,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 18,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                medico?.nomeCompleto ?? 'Medico sconosciuto',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: app.stato.colore.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                app.stato.label,
                style: TextStyle(
                  color: app.stato.colore,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    specializzazione?.nome ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${app.soloData.formatItalia()} ${app.oraFormattata}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            if (hasFasciaInfo) ...[
              const SizedBox(height: 4),
              if (fascia.struttura != null && fascia.struttura!.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.business_rounded, size: 12, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        fascia.struttura!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (fascia.indirizzo != null && fascia.indirizzo!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.place_rounded, size: 12, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          fascia.indirizzo!,
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
                ),
            ],
            if (hasTelefono) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.phone_rounded, size: 12, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      telefono,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
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
        isThreeLine: hasFasciaInfo || hasTelefono,
        trailing: Icon(
          app.stato == StatoCalendario.proposto
              ? Icons.add_circle_outline
              : Icons.chevron_right,
          color: app.stato == StatoCalendario.proposto
              ? Colors.blue
              : Colors.grey,
          size: 20,
        ),
        onTap: () {
          if (app.stato == StatoCalendario.proposto) {
            _showConfermaDialog(context, app, medico, ref);
          } else {
            _showActionsDialog(context, app, medico, ref);
          }
        },
      ),
    );
  }

  void _showConfermaDialog(
    BuildContext context,
    CalendarioAppuntamento app,
    Medico? medico,
    WidgetRef ref,
  ) {
    final fasciaMap = ref.read(fasciaByIdProvider);
    final fascia = app.fasciaOrariaId != null ? fasciaMap[app.fasciaOrariaId] : null;
    final hasFasciaInfo = (fascia?.struttura != null && fascia!.struttura!.isNotEmpty) ||
        (fascia?.indirizzo != null && fascia!.indirizzo!.isNotEmpty);
    final telefono = medico?.telefono?.trim();
    final hasTelefono = telefono != null && telefono.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Conferma appuntamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vuoi inserire nel calendario questo appuntamento?'),
              const SizedBox(height: 16),
              Text(medico?.nomeCompleto ?? 'Medico'),
              Text('Data: ${app.soloData.formatItalia()} alle ${app.oraFormattata}'),
              if (hasFasciaInfo) ...[
                if (fascia.struttura != null && fascia.struttura!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.business_rounded, size: 14, color: Colors.grey.shade700),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            fascia.struttura!,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (fascia.indirizzo != null && fascia.indirizzo!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.place_rounded, size: 14, color: Colors.grey.shade700),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            fascia.indirizzo!,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (hasTelefono) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.phone_rounded, size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          telefono,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text('Stato: verrà impostato come "Confermato"'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(salvaAppuntamentoProvider)(
                  app.copyWith(stato: StatoCalendario.confermato),
                );
                ref.refresh(calendarioProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appuntamento confermato')),
                );
              },
              child: const Text('Conferma'),
            ),
          ],
        );
      },
    );
  }

  void _showActionsDialog(
    BuildContext context,
    CalendarioAppuntamento app,
    Medico? medico,
    WidgetRef ref,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check, color: Colors.green),
                title: const Text('Segna come effettuato'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(salvaAppuntamentoProvider)(
                    app.copyWith(stato: StatoCalendario.fatto),
                  );
                  ref.refresh(calendarioProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Salvato')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Segna come annullato'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(salvaAppuntamentoProvider)(
                    app.copyWith(stato: StatoCalendario.annullato),
                  );
                  ref.refresh(calendarioProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Salvato')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar, color: Colors.orange),
                title: const Text('Modifica data/orario'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, app, medico, ref);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext context,
    CalendarioAppuntamento app,
    Medico? medico,
    WidgetRef ref,
  ) {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modifica data/orario'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data: ${selectedDate?.formatItalia() ?? app.soloData.formatItalia()}'),
                  Text('Ora: ${selectedTime?.formatTime() ?? app.oraFormattata}'),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Seleziona data'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? app.soloData,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: const Text('Seleziona ora'),
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ?? TimeOfDay.fromDateTime(app.data),
                      );
                      if (time != null) {
                        setState(() => selectedTime = time);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                TextButton(
                  onPressed: () async {
                    final DateTime nuovaData;

                    if (selectedDate != null) {
                      nuovaData = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime?.hour ?? app.data.hour,
                        selectedTime?.minute ?? app.data.minute,
                      );
                    } else if (selectedTime != null) {
                      nuovaData = DateTime(
                        app.data.year,
                        app.data.month,
                        app.data.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                    } else {
                      Navigator.pop(context);
                      return;
                    }

                    await ref.read(salvaAppuntamentoProvider)(
                      app.copyWith(data: nuovaData),
                    );

                    ref.refresh(calendarioProvider);
                    ref.refresh(mediciProvider);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Salvato')),
                      );
                    }
                    Navigator.pop(context);
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

  void _showRangeDialog(BuildContext context, WidgetRef ref) {
    final settimaneController = TextEditingController(text: '12');
    DateTime? dataPartenza = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Range Appuntamenti'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Data di partenza'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dataPartenza ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) {
                        setState(() {
                          dataPartenza = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(dataPartenza?.formatItalia() ?? 'Seleziona data'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Numero di settimane'),
                  TextField(
                    controller: settimaneController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Settimane',
                      suffixText: 'max 52',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                TextButton(
                  onPressed: () {
                    final settimane = int.tryParse(settimaneController.text) ?? 12;
                    if (dataPartenza != null) {
                      ref.read(calendarioRangeProvider.notifier).setRange(dataPartenza!, dataPartenza!.add(Duration(days: settimane * 7)));
                    }
                    Navigator.pop(context);
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

  void _showMaxMediciDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Medici per giorno'),
          content: const Text(
              'Numero massimo di medici che possono essere visitati in un giorno'),
          actions: [
            for (final n in [4, 6, 8, 10, 12])
              TextButton(
                onPressed: () {
                  ref.read(maxMediciPerGiornoProvider.notifier).state = n;
                  Navigator.pop(context);
                },
                child: Text('$n medici'),
              ),
          ],
        );
      },
    );
  }

  void _showFilterDialog(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Zona>> zoneAsync,
  ) {
    final distrettiAsync = ref.watch(distrettoProvider);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Filtra per Zona e Distretto'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Sezione Distretti - ordinate alfabeticamente
                    if (distrettiAsync.hasValue) ...[
                      const Text(
                        'Distretti',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ..._buildDistrettoFilterList(distrettiAsync.value!, ref, setStateDialog),
                      const SizedBox(height: 16),
                    ],
                    // Sezione Zone
                    if (zoneAsync.hasValue) ...[
                      const Text(
                        'Zone',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ..._buildZonaFilterList(zoneAsync.value!, ref, setStateDialog),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Chiudi'),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(zoneSelezionateProvider.notifier).clearAll();
                    ref.read(distrettiSelezionatiProvider.notifier).clearAll();
                    Navigator.pop(context);
                  },
                  child: const Text('Pulisci Filtri'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Esporta gli appuntamenti in un file Excel.
  void _esportaExcel(
    BuildContext context,
    WidgetRef ref,
    List<CalendarioAppuntamento> appuntamenti,
    Set<String> zoneSelezionate,
    Map<String, String> zonaPerMedico,
  ) async {
    // Filtra gli appuntamenti non conclusi
    final filtrati = zoneSelezionate.isEmpty
        ? appuntamenti.where((a) => !a.stato.isConcluso).toList()
        : appuntamenti
            .where((a) =>
                !a.stato.isConcluso && zoneSelezionate.contains(zonaPerMedico[a.medicoId]))
            .toList()
          ..sort((a, b) {
            // Ordina per data, poi per ora all'interno della stessa data
            final dataCmp = a.soloData.compareTo(b.soloData);
            if (dataCmp != 0) return dataCmp;
            return a.oraFormattata.compareTo(b.oraFormattata);
          });

    if (filtrati.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun appuntamento da esportare')),
      );
      return;
    }

    // Mostra dialog di caricamento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generazione file Excel...'),
          ],
        ),
      ),
    );

    try {
      // Prepara i dati necessari per l'export
      final fasciaMap = ref.read(fasciaByIdProvider);
      final zonaMap = ref.read(zonaByIdProvider);
      final distrettoMap = ref.read(distrettoByCodiceProvider);
      final medicoMapRaw = ref.read(medicoByIdProvider);

      // Risolvi i dati completi
      final medicoMap = <String, Medico>{};
      for (final app in filtrati) {
        if (medicoMapRaw[app.medicoId] != null) {
          medicoMap[app.medicoId] = medicoMapRaw[app.medicoId]!;
        }
      }

      // Genera il file Excel
      final useCase = EsportaAppuntamentiUseCase();
      final bytes = await useCase(
        appuntamenti: filtrati,
        medicoMap: medicoMap,
        fasciaMap: fasciaMap,
        zonaMap: zonaMap,
        distrettoMap: distrettoMap,
      );

      // Genera nome file con timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'appuntamenti_pianificati_$timestamp.xlsx';

      // Salva con FileSaver (cross-platform)
      await FileSaver.instance.saveFile(
        name: filename,
        bytes: bytes,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File salvato come: $filename'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante l\'esportazione: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Costruisce la lista dei filtri per zona.
  /// L'esclusività con i distretti è gestita da `onChanged`.
  List<Widget> _buildZonaFilterList(
    List<Zona> zone,
    WidgetRef ref,
    void Function(void Function()) setStateDialog,
  ) {
    final zoneSelezionate = ref.watch(zoneSelezionateProvider);
    final zoneList = List<Zona>.from(zone)..sort((a, b) => a.nome.compareTo(b.nome));
    return zoneList.map((zona) {
      final isSelected = zoneSelezionate.contains(zona.id);
      return CheckboxListTile(
        key: ValueKey('zona-${zona.id}'),
        value: isSelected,
        title: Text(zona.nome),
        secondary: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: zona.colore,
            shape: BoxShape.circle,
          ),
        ),
        onChanged: (v) {
          // Esclusività: pulisco i distretti quando seleziono una zona
          ref.read(distrettiSelezionatiProvider.notifier).clearAll();
          ref
              .read(zoneSelezionateProvider.notifier)
              .toggle(zona.id);
          setStateDialog(() {});
        },
      );
    }).toList();
  }

  /// Costruisce la lista dei filtri per distretto.
  /// L'esclusività con le zone è gestita da `onChanged`.
  List<Widget> _buildDistrettoFilterList(
    List<Distretto> distretti,
    WidgetRef ref,
    void Function(void Function()) setStateDialog,
  ) {
    final distrettiSelezionati = ref.watch(distrettiSelezionatiProvider);
    final distrettiList = List<Distretto>.from(distretti)..sort((a, b) => a.descrizione.compareTo(b.descrizione));
    return distrettiList.map((distretto) {
      final isSelected = distrettiSelezionati.contains(distretto.codice);
      return CheckboxListTile(
        key: ValueKey('distretto-${distretto.codice}'),
        value: isSelected,
        title: Text(distretto.descrizione),
        secondary: const Icon(Icons.map_outlined, size: 20),
        onChanged: (v) {
          // Esclusività: pulisco le zone quando seleziono un distretto
          ref.read(zoneSelezionateProvider.notifier).clearAll();
          ref
              .read(distrettiSelezionatiProvider.notifier)
              .toggle(distretto.codice);
          setStateDialog(() {});
        },
      );
    }).toList();
  }
}