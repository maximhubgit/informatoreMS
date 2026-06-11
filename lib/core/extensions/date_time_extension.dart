import 'package:flutter/material.dart';

/// Extension utili su [DateTime].
extension DateTimeX on DateTime {
  /// Ritorna una nuova [DateTime] con solo anno, mese e giorno (orario 00:00).
  DateTime get dateOnly => DateTime(year, month, day);

  /// Ritorna true se [this] e [other] rappresentano lo stesso giorno.
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Aggiunge [giorni] alla data corrente.
  DateTime addDays(int giorni) => add(Duration(days: giorni));

  /// Confronta solo la parte data (ignora orario).
  bool isBeforeOrSameDay(DateTime other) {
    final d = dateOnly;
    final o = other.dateOnly;
    return d.isBefore(o) || d.isAtSameMomentAs(o);
  }

  /// Formatta la data in italiano (es. 15/03/2026).
  String formatItalia() => '${_pad(day)}/${_pad(month)}/$year';

  /// Formatta l'orario (es. 09:30).
  String formatOrario() => '${_pad(hour)}:${_pad(minute)}';

  /// Minuti dalla mezzanotte.
  int get minutiDaMezzanotte => hour * 60 + minute;

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

/// Extension per formattare TimeOfDay.
extension TimeOfDayFormat on TimeOfDay {
  String formatTime() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
