import 'package:equatable/equatable.dart';

enum StatoAppuntamento {
  proposto,
  confermato,
  spostato,
  fatto,
  nonFatto,
}

extension StatoAppuntamentoX on StatoAppuntamento {
  String get label => switch (this) {
    StatoAppuntamento.proposto => 'Confermato',
    StatoAppuntamento.confermato => 'Confermato',
    StatoAppuntamento.spostato => 'Spostato',
    StatoAppuntamento.fatto => 'Fatto',
    StatoAppuntamento.nonFatto => 'Non fatto',
  };

  bool get isConcluso =>
      this == StatoAppuntamento.fatto || this == StatoAppuntamento.nonFatto;
}

class Appuntamento extends Equatable {
  final String id;
  final String medicoId;
  final DateTime dataOraInizio;
  final DateTime dataOraFine;
  final StatoAppuntamento stato;
  final String? note;

  const Appuntamento({
    required this.id,
    required this.medicoId,
    required this.dataOraInizio,
    required this.dataOraFine,
    required this.stato,
    this.note,
  });

  DateTime get data => DateTime(
        dataOraInizio.year,
        dataOraInizio.month,
        dataOraInizio.day,
      );

  Appuntamento copyWith({
    String? id,
    String? medicoId,
    DateTime? dataOraInizio,
    DateTime? dataOraFine,
    StatoAppuntamento? stato,
    String? note,
  }) {
    return Appuntamento(
      id: id ?? this.id,
      medicoId: medicoId ?? this.medicoId,
      dataOraInizio: dataOraInizio ?? this.dataOraInizio,
      dataOraFine: dataOraFine ?? this.dataOraFine,
      stato: stato ?? this.stato,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicoId': medicoId,
      'dataOraInizio': dataOraInizio.toIso8601String(),
      'dataOraFine': dataOraFine.toIso8601String(),
      'stato': stato.name,
      'note': note,
    };
  }

  factory Appuntamento.fromJson(Map<String, dynamic> json) {
    return Appuntamento(
      id: json['id'] as String,
      medicoId: json['medicoId'] as String,
      dataOraInizio: DateTime.parse(json['dataOraInizio'] as String),
      dataOraFine: DateTime.parse(json['dataOraFine'] as String),
      stato: StatoAppuntamento.values.byName(json['stato'] as String),
      note: json['note'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, medicoId, dataOraInizio, dataOraFine, stato, note];
}
