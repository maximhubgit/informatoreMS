import 'package:informatoreMS/core/models/specializzazione.dart';

/// Contratto per il repository delle specializzazioni.
abstract class SpecializzazioneRepository {
  Future<List<Specializzazione>> getAll();
}
