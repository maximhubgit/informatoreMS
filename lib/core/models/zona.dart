import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Zona extends Equatable {
  final String id;
  final String nome;
  final String coloreHex;

  const Zona({
    required this.id,
    required this.nome,
    required this.coloreHex,
  });

  Color get colore {
    return Color(int.parse(coloreHex.replaceFirst('#', '0xFF')));
  }

  Zona copyWith({
    String? id,
    String? nome,
    String? coloreHex,
  }) {
    return Zona(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      coloreHex: coloreHex ?? this.coloreHex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'coloreHex': coloreHex,
    };
  }

  factory Zona.fromJson(Map<String, dynamic> json) {
    return Zona(
      id: json['id'] as String,
      nome: json['nome'] as String,
      coloreHex: json['coloreHex'] as String,
    );
  }

  @override
  List<Object?> get props => [id, nome, coloreHex];
}
