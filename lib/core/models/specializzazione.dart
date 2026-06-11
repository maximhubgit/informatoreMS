import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Specializzazione extends Equatable {
  final String id;
  final String nome;
  final IconData icona;

  const Specializzazione({
    required this.id,
    required this.nome,
    this.icona = Icons.local_hospital,
  });

  Specializzazione copyWith({
    String? id,
    String? nome,
    IconData? icona,
  }) {
    return Specializzazione(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      icona: icona ?? this.icona,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
    };
  }

  factory Specializzazione.fromJson(Map<String, dynamic> json) {
    // Converte stringa icona in IconData se presente
    final iconaString = json['icona'] as String?;
    IconData iconaData;
    if (iconaString != null) {
      iconaData = _iconFromString(iconaString);
    } else {
      iconaData = Icons.local_hospital;
    }

    return Specializzazione(
      id: json['id'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      icona: iconaData,
    );
  }

  static IconData _iconFromString(String iconName) {
    final icons = {
      'favorite': Icons.favorite,
      'medical_services': Icons.medical_services,
      'face_retouching_natural': Icons.face_retouching_natural,
      'child_care': Icons.child_care,
      'local_hospital': Icons.local_hospital,
    };
    return icons[iconName] ?? Icons.local_hospital;
  }

  @override
  List<Object?> get props => [id, nome, icona];
}
