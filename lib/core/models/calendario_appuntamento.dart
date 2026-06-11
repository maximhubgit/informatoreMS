import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Stato dell'appuntamento nel calendario.
enum StatoCalendario {
  proposto, // Generato dallo scheduler ma non confermato
  confermato, // Inserito manualmente dall'utente, confermato
  concordato, // Prefissato/confermato collegato all'anagrafica
  fatto, // Appuntamento effettuato
  annullato, // Appuntamento annullato
}

extension StatoCalendarioX on StatoCalendario {
  String get label => switch (this) {
        StatoCalendario.proposto => 'Proposto',
        StatoCalendario.confermato => 'Confermato',
        StatoCalendario.concordato => 'Concordato',
        StatoCalendario.fatto => 'Fatto',
        StatoCalendario.annullato => 'Annullato',
      };

  bool get isConcluso => this == StatoCalendario.fatto || this == StatoCalendario.annullato;

  Color get colore => switch (this) {
        StatoCalendario.proposto => Colors.blue,
        StatoCalendario.confermato => Colors.indigo,
        StatoCalendario.concordato => Colors.teal,
        StatoCalendario.fatto => Colors.green,
        StatoCalendario.annullato => Colors.red,
      };
}

/// Modello per un appuntamento nel calendario (storico + futuri + proposti).
///
/// Raccoglie tutti gli appuntamenti: storico, futuri, e quelli proposti
/// in base alla periodicità dei medici.
class CalendarioAppuntamento extends Equatable {
  final String id;
  final String medicoId;
  final DateTime data; // Data completa con ora
  final String? note;
  final StatoCalendario stato;
  final DateTime? dataCreazione;
  final int? fasciaNumero; // Numero progressivo della fascia oraria scelta (opzionale)

  const CalendarioAppuntamento({
    required this.id,
    required this.medicoId,
    required this.data,
    this.note,
    this.stato = StatoCalendario.proposto,
    this.dataCreazione,
    this.fasciaNumero,
  });

  // Estrae solo la data senza orario
  DateTime get soloData => DateTime(data.year, data.month, data.day);

  // Estrae solo l'ora (per visualizzazione)
  String get oraFormattata => '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';

  CalendarioAppuntamento copyWith({
    String? id,
    String? medicoId,
    DateTime? data,
    String? note,
    StatoCalendario? stato,
    DateTime? dataCreazione,
    int? fasciaNumero,
  }) {
    return CalendarioAppuntamento(
      id: id ?? this.id,
      medicoId: medicoId ?? this.medicoId,
      data: data ?? this.data,
      note: note ?? this.note,
      stato: stato ?? this.stato,
      dataCreazione: dataCreazione ?? this.dataCreazione,
      fasciaNumero: fasciaNumero ?? this.fasciaNumero,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicoId': medicoId,
      'data': data.toIso8601String(),
      'note': note,
      'stato': stato.name,
      'dataCreazione': dataCreazione?.toIso8601String(),
      'fasciaNumero': fasciaNumero,
    };
  }

  factory CalendarioAppuntamento.fromJson(Map<String, dynamic> json) {
    return CalendarioAppuntamento(
      id: json['id'] as String,
      medicoId: json['medicoId'] as String,
      data: DateTime.parse(json['data'] as String),
      note: json['note'] as String?,
      stato: StatoCalendario.values.byName(json['stato'] as String),
      dataCreazione: json['dataCreazione'] != null
          ? DateTime.parse(json['dataCreazione'] as String)
          : null,
      fasciaNumero: (json['fasciaNumero'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [id, medicoId, data, note, stato, dataCreazione, fasciaNumero];
}