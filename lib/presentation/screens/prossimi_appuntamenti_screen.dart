import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/extensions/specializzazione_extension.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/core/models/specializzazione.dart';
import 'package:informatoreMS/core/models/zona.dart';
import 'package:informatoreMS/presentation/providers/zone_provider.dart';
import 'package:informatoreMS/presentation/providers/zone_selezionate_provider.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';
import 'package:informatoreMS/presentation/providers/medici_provider.dart';
import 'package:informatoreMS/presentation/providers/specializzazione_provider.dart';

class ProssimiAppuntamentiScreen extends ConsumerWidget {
  const ProssimiAppuntamentiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarioAsync = ref.watch(calendarioProvider);
    final zoneAsync = ref.watch(zoneProvider);
    final zoneSelezionate = ref.watch(zoneSelezionateProvider);
    final medicoMap = ref.watch(medicoByIdProvider);

    final maxMedici = ref.watch(maxMediciPerGiornoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prossimi Appuntamenti'),
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
        ],
      ),
      body: calendarioAsync.when(
        data: (appuntamenti) {
          // Costruisci un map medicoId -> zonaId della fascia principale
          final fasceAsyncValue = ref.watch(fasceOrarieProvider);
          final fasce = fasceAsyncValue.asData?.value ?? [];
          final zonaPerMedico = <String, String>{};
          for (final fascia in fasce.where((f) => f.nr == 0)) {
            zonaPerMedico[fascia.idMedico] = fascia.zonaId;
          }

          final proposti = zoneSelezionate.isEmpty
              ? appuntamenti
                  .where((a) => !a.stato.isConcluso)
                  .toList()
              : appuntamenti
                  .where((a) =>
                      !a.stato.isConcluso &&
                      zoneSelezionate.contains(zonaPerMedico[a.medicoId]))
                  .toList();

          if (proposti.isEmpty) {
            return _emptyState(context);
          }

          final sorted = List<CalendarioAppuntamento>.from(proposti)
            ..sort((a, b) => a.data.compareTo(b.data));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final app = sorted[index];
              final medico = medicoMap[app.medicoId];
              return _buildAppuntamentoTile(context, app, medico, ref);
            },
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

  Widget _buildAppuntamentoTile(
    BuildContext context,
    CalendarioAppuntamento app,
    Medico? medico,
    WidgetRef ref,
  ) {
    final specialMap = ref.watch(specializzazioneByIdProvider);
    final fasciaMap = ref.watch(fasciaByIdProvider);
    final specializzazione = medico != null ? specialMap[medico.specializzazioneId] : null;
    // Recupera struttura/indirizzo dalla fascia dell'appuntamento
    final fascia = app.fasciaOrariaId != null ? fasciaMap[app.fasciaOrariaId] : null;
    final hasFasciaInfo = fascia != null &&
        ((fascia.struttura != null && fascia.struttura!.isNotEmpty) ||
            (fascia.indirizzo != null && fascia.indirizzo!.isNotEmpty));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
            // Stato in alto a destra
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
          ],
        ),
        isThreeLine: hasFasciaInfo,
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Conferma appuntamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vuoi inserire nel calendario questo appuntamento?'),
              const SizedBox(height: 16),
              Text('${medico?.nomeCompleto ?? 'Medico'}'),
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
              const SizedBox(height: 8),
              Text('Stato: verrà impostato come "Confermato"'),
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
                // Conferma l'appuntamento come "proposto" (non concordato)
                // copyWith preserva fasciaOrariaId: l'appuntamento confermato
                // mantiene il legame con la fascia (quindi indirizzo/struttura).
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

                    // Se l'utente ha selezionato una nuova data completa
                    if (selectedDate != null) {
                      nuovaData = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime?.hour ?? app.data.hour,
                        selectedTime?.minute ?? app.data.minute,
                      );
                    }
                    // Se l'utente ha selezionato solo l'ora (stessa data)
                    else if (selectedTime != null) {
                      nuovaData = DateTime(
                        app.data.year,
                        app.data.month,
                        app.data.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                    }
                    // Nessuna modifica
                    else {
                      Navigator.pop(context);
                      return;
                    }

                    // Salva l'appuntamento con la nuova data
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filtra per Zona'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: zoneAsync.value!.map((zona) {
                final zoneSelezionate = ref.watch(zoneSelezionateProvider);
                final isSelected = zoneSelezionate.contains(zona.id);
                return CheckboxListTile(
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
                    ref.read(zoneSelezionateProvider.notifier).toggle(zona.id);
                  },
                );
              }).toList(),
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
                Navigator.pop(context);
              },
              child: const Text('Pulisci Filtri'),
            ),
          ],
        );
      },
    );
  }
}
