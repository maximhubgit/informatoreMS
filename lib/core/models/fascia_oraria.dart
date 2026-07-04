import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Giorni della settimana come definiti da DateTime (1=Lunedì, 2=Martedì, ..., 7=Domenica).
enum GiornoSettimana {
  lunedi(1),
  martedi(2),
  mercoledi(3),
  giovedi(4),
  venerdi(5),
  sabato(6),
  domenica(7);

  final int value;
  const GiornoSettimana(this.value);

  String get label {
    return switch (this) {
      GiornoSettimana.lunedi => 'Lunedì',
      GiornoSettimana.martedi => 'Martedì',
      GiornoSettimana.mercoledi => 'Mercoledì',
      GiornoSettimana.giovedi => 'Giovedì',
      GiornoSettimana.venerdi => 'Venerica',
      GiornoSettimana.sabato => 'Sabato',
      GiornoSettimana.domenica => 'Domenica',
    };
  }

  static GiornoSettimana fromDateTime(DateTime date) {
    return GiornoSettimana.values.firstWhere((g) => g.value == date.weekday);
  }
}

/// Fascia oraria di disponibilità di un medico.
/// Ogni medico deve avere almeno una fascia con nr=0 (fascia principale).
class FasciaOraria extends Equatable {
  final String? id; // ID univoco della fascia (generato da Firestore o UUID)
  final String idMedico; // Foreign key al Medico
  final int nr; // Numero progressivo a partire da 0 per ogni medico (0 = principale)
  final int minutiInizio;
  final int minutiFine;
  final int slotDisponibili;
  final List<GiornoSettimana>? giorniSettimana; // null = tutti i giorni
  final int distrettoId; // Distretto specifico per questa fascia (obbligatorio)
  final String zonaId; // Zona specifica per questa fascia (obbligatorio)
  final String? struttura; // Struttura/ente dell'appartenenza
  final String? indirizzo; // Indirizzo specifico per questa fascia
  final int? tempoVisitaMinuti; // Durata visita in minuti (se diversa da quella di default)
  final bool deleted; // Se true, la fascia è cancellata logicamente (non usata per scheduler)
  final bool isFittizia; // Se true, fascia "segnaposto" usata solo per conservare i
                        // dati anagrafici del medico (indirizzo/struttura/zona/distretto)
                        // quando non ha orari reali. Sempre 00:00-00:00 domenica.
                        // Esclusa dalla pianificazione dello scheduler.

  const FasciaOraria({
    this.id,
    required this.idMedico,
    required this.nr,
    required this.minutiInizio,
    required this.minutiFine,
    this.slotDisponibili = 1,
    this.giorniSettimana,
    required this.distrettoId,
    required this.zonaId,
    this.struttura,
    this.indirizzo,
    this.tempoVisitaMinuti,
    this.deleted = false,
    this.isFittizia = false,
  });

  /// Se true, la fascia vale per tutti i giorni della settimana.
  bool get tuttiIGiorni => giorniSettimana == null || giorniSettimana!.isEmpty;

  /// Verifica se questa fascia oraria è valida per il giorno specificato.
  bool isValidaPer(DateTime giorno) {
    if (tuttiIGiorni) return true;
    return giorniSettimana!.contains(GiornoSettimana.fromDateTime(giorno));
  }

  TimeOfDay get inizio => TimeOfDay(
    hour: minutiInizio ~/ 60,
    minute: minutiInizio % 60,
  );

  TimeOfDay get fine => TimeOfDay(
    hour: minutiFine ~/ 60,
    minute: minutiFine % 60,
  );

  int get durataMinuti => minutiFine - minutiInizio;

  FasciaOraria copyWith({
    String? id,
    String? idMedico,
    int? nr,
    int? minutiInizio,
    int? minutiFine,
    int? slotDisponibili,
    List<GiornoSettimana>? giorniSettimana,
    int? distrettoId,
    String? zonaId,
    String? struttura,
    String? indirizzo,
    int? tempoVisitaMinuti,
    bool? deleted,
    bool? isFittizia,
  }) {
    return FasciaOraria(
      id: id ?? this.id,
      idMedico: idMedico ?? this.idMedico,
      nr: nr ?? this.nr,
      minutiInizio: minutiInizio ?? this.minutiInizio,
      minutiFine: minutiFine ?? this.minutiFine,
      slotDisponibili: slotDisponibili ?? this.slotDisponibili,
      giorniSettimana: giorniSettimana ?? this.giorniSettimana,
      distrettoId: distrettoId ?? this.distrettoId,
      zonaId: zonaId ?? this.zonaId,
      struttura: struttura ?? this.struttura,
      indirizzo: indirizzo ?? this.indirizzo,
      tempoVisitaMinuti: tempoVisitaMinuti ?? this.tempoVisitaMinuti,
      deleted: deleted ?? this.deleted,
      isFittizia: isFittizia ?? this.isFittizia,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idMedico': idMedico,
      'nr': nr,
      'minutiInizio': minutiInizio,
      'minutiFine': minutiFine,
      'slotDisponibili': slotDisponibili,
      'giorniSettimana': giorniSettimana?.map((g) => g.name).toList(),
      'distrettoId': distrettoId,
      'zonaId': zonaId,
      'struttura': struttura,
      'indirizzo': indirizzo,
      'tempoVisitaMinuti': tempoVisitaMinuti,
      'deleted': deleted,
      'isFittizia': isFittizia,
    };
  }

  factory FasciaOraria.fromJson(Map<String, dynamic> json) {
    List<GiornoSettimana>? giorni;
    try {
      final giorniList = json['giorniSettimana'] as List<dynamic>?;
      if (giorniList != null) {
        giorni = giorniList
            .map((g) => GiornoSettimana.values.byName(g as String))
            .toList();
      }
    } catch (_) {
      giorni = null;
    }

    // Fallback per dati esistenti: supporta entrambi i formati
    // Nuovo formato: distrettoId, zonaId, struttura, indirizzo, tempoVisitaMinuti
    // Vecchio formato: idDistretto, distrettoIdEstido, zonaIdEsteso, strutturaEstesa, indirizzoEsteso
    int distrettoIdValue;
    try {
      // Prima prova con il nuovo campo distrettoId
      if (json['distrettoId'] != null) {
        distrettoIdValue = json['distrettoId'] is int
            ? json['distrettoId'] as int
            : int.parse(json['distrettoId'].toString());
      } else if (json['idDistretto'] != null) {
        // Poi con il vecchio idDistretto
        distrettoIdValue = json['idDistretto'] is int
            ? json['idDistretto'] as int
            : int.parse(json['idDistretto'].toString());
      } else {
        distrettoIdValue = 1;
      }
    } catch (_) {
      distrettoIdValue = 1;
    }

    return FasciaOraria(
      id: json['id'] as String?,
      idMedico: json['idMedico'] as String? ?? '',
      nr: (json['nr'] as num?)?.toInt() ?? 0,
      minutiInizio: (json['minutiInizio'] as num?)?.toInt() ?? 0,
      minutiFine: (json['minutiFine'] as num?)?.toInt() ?? 0,
      slotDisponibili: (json['slotDisponibili'] as num?)?.toInt() ?? 1,
      giorniSettimana: giorni,
      distrettoId: distrettoIdValue,
      zonaId: json['zonaId'] as String? ?? json['zonaIdEsteso'] as String? ?? '',
      struttura: json['struttura'] as String? ?? json['strutturaEstesa'] as String?,
      indirizzo: json['indirizzo'] as String? ?? json['indirizzoEsteso'] as String?,
      tempoVisitaMinuti: (json['tempoVisitaMinuti'] as num?)?.toInt() ??
          (json['tempoVisitaMinuti'] as num?)?.toInt(),
      deleted: json['deleted'] as bool? ?? false,
      isFittizia: json['isFittizia'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, idMedico, nr, minutiInizio, minutiFine, slotDisponibili, giorniSettimana, distrettoId, zonaId, struttura, indirizzo, tempoVisitaMinuti, deleted, isFittizia];
}