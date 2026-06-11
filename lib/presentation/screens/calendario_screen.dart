import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/specializzazione.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';
import 'package:informatoreMS/presentation/providers/medici_provider.dart';
import 'package:informatoreMS/presentation/providers/specializzazione_provider.dart';
import 'package:informatoreMS/presentation/screens/storico_medico_screen.dart';
import 'package:informatoreMS/presentation/widgets/appuntamento_card.dart';

class CalendarioScreen extends ConsumerStatefulWidget {
  const CalendarioScreen({super.key});

  @override
  ConsumerState<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends ConsumerState<CalendarioScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final calendarioAsync = ref.watch(calendarioProvider);
    final appuntamentiGiorno = _selectedDay != null
        ? ref.watch(appuntamentiDelGiornoProvider(_selectedDay!))
        : <CalendarioAppuntamento>[];
    final medicoMap = ref.watch(medicoByIdProvider);
    final specializzazioniMap = ref.watch(specializzazioneByIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        centerTitle: true,
      ),
      body: calendarioAsync.when(
        data: (appuntamenti) {
          return Column(
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
                    _focusedDay = focused;
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
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      final giorno = DateTime(date.year, date.month, date.day);
                      final count = appuntamenti
                          .where((a) => a.soloData.isAtSameMomentAs(giorno))
                          .length;
                      if (count == 0) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 4,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
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
              // Lista appuntamenti
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: appuntamentiGiorno.length,
                  itemBuilder: (context, index) {
                    final app = appuntamentiGiorno[index];
                    final medico = medicoMap[app.medicoId];
                    final specializzazione = specializzazioniMap[medico?.specializzazioneId];
                    return AppuntamentoCard(
                      appuntamento: app,
                      nomeMedico: medico?.nomeCompleto,
                      specializzazione: specializzazione?.nome,
                      onMarkDone: () => _markDone(ref, app),
                      onMarkCancelled: () => _markCancelled(ref, app),
                      onMove: () => _showMoveDialog(context, ref, app),
                      onTap: () => _navigaStorico(context, app.medicoId),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
      ),
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

  void _navigaStorico(BuildContext context, String medicoId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoricoMedicoScreen(medicoId: medicoId),
      ),
    );
  }
}
