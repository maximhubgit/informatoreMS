import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/domain/scheduler/calendar_scheduler.dart';

/// Caso d'uso: genera il calendario proposto per i medici selezionati.
/// I calcoli si basano sugli appuntamenti già salvati nel calendario
/// (quelli con stato fatto/annullato sono considerati storico).
class GeneraCalendarioUseCase {
  final CalendarScheduler _scheduler;

  GeneraCalendarioUseCase({CalendarScheduler? scheduler})
      : _scheduler = scheduler ?? CalendarScheduler();

  List<CalendarioAppuntamento> call({
    required List<Medico> medici,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    List<CalendarioAppuntamento> esistenti = const [],
  }) {
    return _scheduler.genera(
      medici: medici,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      esistenti: esistenti,
    );
  }
}
