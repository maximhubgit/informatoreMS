import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/fascia_oraria.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/core/models/distretto.dart';
import 'package:informatoreMS/core/models/zona.dart';

/// Caso d'uso: esporta gli appuntamenti in un file Excel.
///
/// Colonne: Zona, Medico, Stato, Data Appuntamento, Lunedì, Martedì, Mercoledì, Giovedì, Venerdì, Struttura, Indirizzo, Telefono, Prodotti
/// Ordinamento: per data crescente, poi per ora crescente
/// Nelle colonne giorni: ora inizio-ora fine (es. "09:00-11:00")
/// Righe vuote tra giorni diversi.
class EsportaAppuntamentiUseCase {
  /// Genera un file Excel con gli appuntamenti specificati.
  Future<Uint8List> call({
    required List<CalendarioAppuntamento> appuntamenti,
    required Map<String, Medico> medicoMap,
    required Map<String, FasciaOraria> fasciaMap,
    required Map<String, Zona> zonaMap,
    required Map<int, Distretto> distrettoMap,
  }) async {
    final excel = Excel.createExcel();

    // Header - nuovo ordine: Zona, Medico, Stato, Data Appuntamento, giorni, Struttura, Indirizzo, Telefono, Prodotti
    final headers = [
      'Zona',
      'Medico',
      'Stato',
      'Data Appuntamento',
      'Lunedì',
      'Martedì',
      'Mercoledì',
      'Giovedì',
      'Venerdì',
      'Struttura',
      'Indirizzo',
      'Telefono',
      'Prodotti',
    ];

    // Scrivi header in prima riga
    excel.appendRow('Sheet1', headers);

    // Ordina per data crescente, poi per ora crescente
    final appuntamentiOrdinati = List<CalendarioAppuntamento>.from(appuntamenti)
      ..sort((a, b) {
        final dataCmp = a.soloData.compareTo(b.soloData);
        if (dataCmp != 0) return dataCmp;
        return a.oraFormattata.compareTo(b.oraFormattata);
      });

    String? giornoPrecedente;

    // Scrivi righe dati
    for (final app in appuntamentiOrdinati) {
      final medico = medicoMap[app.medicoId];
      final fascia = app.fasciaOrariaId != null ? fasciaMap[app.fasciaOrariaId] : null;

      // Zona: cerca nella fascia principale (nr=0) del medico
      String zonaNome = '';
      if (medico != null) {
        final fasceMedico = fasciaMap.values.where((f) => f.idMedico == medico.id).toList();
        FasciaOraria? fasciaPrincipale;
        fasciaPrincipale = fasceMedico.where((f) => f.nr == 0).firstOrNull;
        if (fasciaPrincipale == null || fasciaPrincipale.isFittizia) {
          fasciaPrincipale = fasceMedico.firstOrNull;
        }
        if (fasciaPrincipale != null && !fasciaPrincipale.isFittizia) {
          final zona = zonaMap[fasciaPrincipale.zonaId];
          zonaNome = zona?.nome ?? '';
        }
      }

      // Struttura e Indirizzo dalla fascia dell'appuntamento
      String struttura = '';
      String indirizzo = '';
      FasciaOraria? fasciaUsata = fascia;
      if (fasciaUsata == null && medico != null) {
        final fasceMedico = fasciaMap.values.where((f) => f.idMedico == medico.id).toList();
        fasciaUsata = fasceMedico.where((f) => !f.isFittizia).firstOrNull ?? fasceMedico.firstOrNull;
      }

      if (fasciaUsata != null) {
        struttura = fasciaUsata.struttura ?? '';
        indirizzo = fasciaUsata.indirizzo ?? '';
      }

      // Data formattata (solo giorno/mese/anno)
      final dataFormattata = '${app.data.day.toString().padLeft(2, '0')}/${app.data.month.toString().padLeft(2, '0')}/${app.data.year}';

      // Orario inizio e ora fine dalla fascia (se disponibile)
      final oraInizio = '${app.data.hour.toString().padLeft(2, '0')}:${app.data.minute.toString().padLeft(2, '0')}';
      String oraFine = '';
      if (fasciaUsata != null) {
        final h = fasciaUsata.minutiFine ~/ 60;
        final m = fasciaUsata.minutiFine % 60;
        oraFine = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }

      // Formato orario fascia: "09:00-11:00"
      final orarioFascia = oraFine.isNotEmpty ? '$oraInizio-$oraFine' : oraInizio;

      // Inserisci riga vuota se cambia giorno
      final giornoChiave = '${app.soloData.year}-${app.soloData.month}-${app.soloData.day}';
      if (giornoPrecedente != null && giornoPrecedente != giornoChiave) {
        excel.appendRow('Sheet1', List<String?>.filled(headers.length, null));
      }
      giornoPrecedente = giornoChiave;

      // Stato testuale
      final statoTestuale = app.stato.label;

      // Costruisci la riga con le colonne in ordine
      final row = List<String?>.filled(headers.length, null);
      row[0] = zonaNome; // Zona
      row[1] = medico?.nomeCompleto ?? 'Sconosciuto'; // Medico
      row[2] = statoTestuale; // Stato
      row[3] = dataFormattata; // Data Appuntamento

      // Metti l'orario fascia nella colonna del giorno (Lunedì-Venerdì)
      final giornoSettimana = app.data.weekday;
      if (giornoSettimana >= 1 && giornoSettimana <= 5) {
        row[3 + giornoSettimana] = orarioFascia;
      }

      row[9] = struttura; // Struttura
      row[10] = indirizzo; // Indirizzo
      row[11] = medico?.telefono ?? ''; // Telefono
      row[12] = medico?.prodotti ?? ''; // Prodotti

      excel.appendRow('Sheet1', row);
    }

    final result = excel.save();
    if (result == null) {
      throw Exception('Impossibile generare il file Excel');
    }
    return Uint8List.fromList(result.toList());
  }
}