import 'package:equatable/equatable.dart';

class Medico extends Equatable {
  final String id;
  final String nome;
  final String specializzazioneId;
  final int periodicitaGiorni;
  final String? calendarioAppuntamentoId; // Foreign key all'evento nel calendario
  final String? annotazioni; // Note libere per il medico
  final String? telefono; // Recapiti telefonici liberi (più numeri con annotazioni)
  final String? prodotti; // Prodotti/terapie associate

  const Medico({
    required this.id,
    required this.nome,
    required this.specializzazioneId,
    required this.periodicitaGiorni,
    this.calendarioAppuntamentoId,
    this.annotazioni,
    this.telefono,
    this.prodotti,
  });

  String get nomeCompleto => nome;

  Medico copyWith({
    String? id,
    String? nome,
    String? specializzazioneId,
    int? periodicitaGiorni,
    String? calendarioAppuntamentoId,
    String? annotazioni,
    String? telefono,
    String? prodotti,
  }) {
    return Medico(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      specializzazioneId: specializzazioneId ?? this.specializzazioneId,
      periodicitaGiorni: periodicitaGiorni ?? this.periodicitaGiorni,
      calendarioAppuntamentoId: calendarioAppuntamentoId ?? this.calendarioAppuntamentoId,
      annotazioni: annotazioni ?? this.annotazioni,
      telefono: telefono ?? this.telefono,
      prodotti: prodotti ?? this.prodotti,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'specializzazioneId': specializzazioneId,
      'periodicitaGiorni': periodicitaGiorni,
      'calendarioAppuntamentoId': calendarioAppuntamentoId,
      'annotazioni': annotazioni,
      'telefono': telefono,
      'prodotti': prodotti,
    };
  }

  factory Medico.fromJson(Map<String, dynamic> json) {
    return Medico(
      id: json['id'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      specializzazioneId: json['specializzazioneId'] as String? ?? json['specializzazione'] as String? ?? '',
      periodicitaGiorni: (json['periodicitaGiorni'] as num?)?.toInt() ?? 30,
      calendarioAppuntamentoId: json['calendarioAppuntamentoId'] as String?,
      annotazioni: json['annotazioni'] as String?,
      telefono: json['telefono'] as String?,
      prodotti: json['prodotti'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        nome,
        specializzazioneId,
        periodicitaGiorni,
        calendarioAppuntamentoId,
        annotazioni,
        telefono,
        prodotti,
      ];
}