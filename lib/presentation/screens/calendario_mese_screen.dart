import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/core/models/specializzazione.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';
import 'package:informatoreMS/presentation/providers/medici_provider.dart';
import 'package:informatoreMS/presentation/providers/specializzazione_provider.dart';
import 'package:informatoreMS/presentation/widgets/appuntamento_card.dart';

class CalendarioMeseScreen extends ConsumerStatefulWidget {
  const CalendarioMeseScreen({super.key});

  @override
  ConsumerState<CalendarioMeseScreen> createState() => _CalendarioMeseScreenState();
}

class _CalendarioMeseScreenState extends ConsumerState<CalendarioMeseScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final TextEditingController _searchController = TextEditingController();
  List<Medico> _mediciFiltrati = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calendarioAsync = ref.watch(calendarioProvider);
    final mediciAsync = ref.watch(mediciProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario Mese'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
      body: Column(
        children: [
          // Calendario
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 30)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) {
                setState(() => _focusedDay = focused);
              },
              calendarStyle: CalendarStyle(
                markerSize: 8,
                markersMaxCount: 3,
                markersAnchor: 1.0,
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                cellMargin: const EdgeInsets.all(6),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  final giorno = DateTime(date.year, date.month, date.day);
                  final contatore = ref.watch(contatoreDelGiornoProvider(giorno));

                  if (contatore.proposti == 0 && contatore.totaleConfermati == 0) {
                    return const SizedBox.shrink();
                  }

                  return Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (contatore.totaleConfermati > 0)
                          _buildBadge(contatore.totaleConfermati, Colors.teal),
                        if (contatore.proposti > 0) ...[
                          if (contatore.totaleConfermati > 0) const SizedBox(width: 4),
                          _buildBadge(contatore.proposti, Colors.blue),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Lista appuntamenti del giorno
          Expanded(
            child: calendarioAsync.when(
              data: (appuntamenti) {
                final appuntamentiGiorno = _selectedDay != null
                    ? ref.watch(appuntamentiDelGiornoProvider(_selectedDay!))
                    : [];

                return Column(
                  children: [
                    // Header giorno selezionato
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDay?.formatItalia() ?? '',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            '${appuntamentiGiorno.length} appuntamenti',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Lista appuntamenti con modifica
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: appuntamentiGiorno.length,
                        itemBuilder: (context, index) {
                          final app = appuntamentiGiorno[index];
                          final medicoMap = ref.watch(medicoByIdProvider);
                          final specialMap = ref.watch(specializzazioneByIdProvider);
                          final medico = medicoMap[app.medicoId];
                          final specializzazione = specialMap[medico?.specializzazioneId];

                          return AppuntamentoCard(
                            appuntamento: app,
                            nomeMedico: medico?.nomeCompleto,
                            specializzazione: specializzazione?.nome,
                            onMarkDone: () => _markDone(ref, app),
                            onMarkCancelled: () => _markCancelled(ref, app),
                            onMove: () => _showMoveDialog(context, ref, app),
                            onConfirm: app.stato == StatoCalendario.proposto
                                ? () => _confermaAppuntamento(ref, app)
                                : null,
                            onDelete: (app.stato == StatoCalendario.confermato || app.stato == StatoCalendario.concordato)
                                ? () => _eliminaAppuntamento(ref, app)
                                : null,
                          );
                        },
                      ),
                    ),

                    // Ricerca medico per aggiungere manualmente
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: _buildRicercaMedico(mediciAsync),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Errore: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(int count, Color color) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRicercaMedico(AsyncValue<List<Medico>> mediciAsync) {
    final specialMap = ref.watch(specializzazioneByIdProvider);

    return mediciAsync.when(
      data: (medici) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cerca medico per aggiungere...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _mediciFiltrati = []);
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              if (value.isEmpty) {
                setState(() => _mediciFiltrati = []);
                return;
              }
              setState(() {
                _mediciFiltrati = medici
                    .where((m) {
                      final specializzazione = specialMap[m.specializzazioneId];
                      return m.nomeCompleto.toLowerCase().contains(value.toLowerCase()) ||
                          (specializzazione?.nome.toLowerCase().contains(value.toLowerCase()) ?? false);
                    })
                    .take(5)
                    .toList();
              });
            },
          ),
          if (_mediciFiltrati.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _mediciFiltrati.length,
                itemBuilder: (context, index) {
                  final medico = _mediciFiltrati[index];
                  final specializzazione = specialMap[medico.specializzazioneId];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        medico.nomeCompleto.isNotEmpty
                            ? medico.nomeCompleto[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(medico.nomeCompleto),
                    subtitle: Text(specializzazione?.nome ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => _aggiungiMedico(context, ref, medico),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
      loading: () => const LinearProgressIndicator(),
      error: (err, stack) => Text('Errore caricamento medici: $err'),
    );
  }

  void _markDone(WidgetRef ref, CalendarioAppuntamento app) {
    ref.read(salvaAppuntamentoProvider)(
      app.copyWith(stato: StatoCalendario.fatto),
    );
    _showSnack('Appuntamento segnato come fatto', backgroundColor: Colors.green);
  }

  void _markCancelled(WidgetRef ref, CalendarioAppuntamento app) {
    ref.read(salvaAppuntamentoProvider)(
      app.copyWith(stato: StatoCalendario.annullato),
    );
    _showSnack('Appuntamento segnato come annullato', backgroundColor: Colors.red);
  }

  void _confermaAppuntamento(WidgetRef ref, CalendarioAppuntamento app) {
    ref.read(salvaAppuntamentoProvider)(
      app.copyWith(stato: StatoCalendario.confermato),
    );
    _showSnack('Appuntamento confermato', backgroundColor: Colors.blue);
  }

  void _eliminaAppuntamento(WidgetRef ref, CalendarioAppuntamento app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text('Vuoi eliminare l\'appuntamento con ${app.medicoId}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              ref.read(eliminaAppuntamentoProvider)(app.id);
              Navigator.of(context).pop();
              _showSnack('Appuntamento eliminato', backgroundColor: Colors.red);
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showMoveDialog(
    BuildContext context,
    WidgetRef ref,
    CalendarioAppuntamento app,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: app.soloData,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(app.data),
    );
    if (time == null || !context.mounted) return;

    final nuovaData = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );

    ref.read(salvaAppuntamentoProvider)(
      app.copyWith(data: nuovaData),
    );

    _showSnack(
      'Appuntamento spostato a ${nuovaData.formatItalia()} ${nuovaData.formatOrario()}',
    );
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
      ),
    );
  }

  void _aggiungiMedico(BuildContext context, WidgetRef ref, Medico medico) {
    showDialog(
      context: context,
      builder: (context) {
        TimeOfDay? oraSelezionata;

        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: Text('Aggiungi ${medico.nomeCompleto}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(_selectedDay?.formatItalia() ?? ''),
                  subtitle: const Text('Data selezionata'),
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(oraSelezionata?.formatTime() ?? 'Seleziona ora'),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) setStateDialog(() => oraSelezionata = time);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annulla'),
              ),
              TextButton(
                onPressed: oraSelezionata == null || _selectedDay == null
                    ? null
                    : () {
                        final nuovaData = DateTime(
                          _selectedDay!.year,
                          _selectedDay!.month,
                          _selectedDay!.day,
                          oraSelezionata!.hour,
                          oraSelezionata!.minute,
                        );
                        final nuovoAppuntamento = CalendarioAppuntamento(
                          id: '',
                          medicoId: medico.id,
                          data: nuovaData,
                          stato: StatoCalendario.confermato,
                        );
                        ref.read(salvaAppuntamentoProvider)(nuovoAppuntamento);
                        Navigator.of(context).pop();
                        _searchController.clear();
                        setState(() => _mediciFiltrati = []);
                        _showSnack('Appuntamento aggiunto per ${medico.nomeCompleto}', backgroundColor: Colors.green);
                      },
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        );
      },
    );
  }
}