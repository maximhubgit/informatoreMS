import 'package:informatoreMS/core/models/calendario_appuntamento.dart';

/// Contratto per il repository del calendario appuntamenti.
abstract class CalendarioRepository {
  Future<List<CalendarioAppuntamento>> getAll();
  Future<void> save(CalendarioAppuntamento appuntamento);
  Future<void> updateStato(String id, StatoCalendario nuovoStato);
  Future<void> delete(String id);
}
