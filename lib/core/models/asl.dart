import 'package:equatable/equatable.dart';

class Asl extends Equatable {
  final int codice; // Auto-increment
  final String descrizione;

  const Asl({
    required this.codice,
    required this.descrizione,
  });

  Asl copyWith({
    int? codice,
    String? descrizione,
  }) {
    return Asl(
      codice: codice ?? this.codice,
      descrizione: descrizione ?? this.descrizione,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codice': codice,
      'descrizione': descrizione,
    };
  }

  factory Asl.fromJson(Map<String, dynamic> json) {
    return Asl(
      codice: json['codice'] is int
          ? json['codice'] as int
          : int.parse(json['codice'].toString()),
      descrizione: json['descrizione'] as String,
    );
  }

  @override
  List<Object?> get props => [codice, descrizione];
}