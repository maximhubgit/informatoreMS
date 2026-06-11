import 'package:equatable/equatable.dart';

import 'appuntamento.dart';

class StoricoAppuntamento extends Equatable {
  final String id;
  final String medicoId;
  final String? appuntamentoId;
  final DateTime dataEseguita;
  final StatoAppuntamento stato;
  final DateTime timestamp;

  const StoricoAppuntamento({
    required this.id,
    required this.medicoId,
    this.appuntamentoId,
    required this.dataEseguita,
    required this.stato,
    required this.timestamp,
  });

  StoricoAppuntamento copyWith({
    String? id,
    String? medicoId,
    String? appuntamentoId,
    DateTime? dataEseguita,
    StatoAppuntamento? stato,
    DateTime? timestamp,
  }) {
    return StoricoAppuntamento(
      id: id ?? this.id,
      medicoId: medicoId ?? this.medicoId,
      appuntamentoId: appuntamentoId ?? this.appuntamentoId,
      dataEseguita: dataEseguita ?? this.dataEseguita,
      stato: stato ?? this.stato,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicoId': medicoId,
      'appuntamentoId': appuntamentoId,
      'dataEseguita': dataEseguita.toIso8601String(),
      'stato': stato.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory StoricoAppuntamento.fromJson(Map<String, dynamic> json) {
    return StoricoAppuntamento(
      id: json['id'] as String,
      medicoId: json['medicoId'] as String,
      appuntamentoId: json['appuntamentoId'] as String?,
      dataEseguita: DateTime.parse(json['dataEseguita'] as String),
      stato: StatoAppuntamento.values.byName(json['stato'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [id, medicoId, appuntamentoId, dataEseguita, stato, timestamp];
}
