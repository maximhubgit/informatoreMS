import 'package:flutter/material.dart';
import 'package:informatoreMS/core/models/specializzazione.dart';

/// Extension per ottenere icona e colore in base alla specializzazione.
extension SpecializzazioneX on Specializzazione {
  IconData get iconaSpecializzazione => icona;

  Color get coloreSpecializzazione {
    return switch (nome) {
      'Cardiologia' => Colors.red.shade100,
      'Dermatologia' => Colors.green.shade100,
      'Ortopedia' => Colors.blue.shade100,
      'Pediatria' => Colors.pink.shade100,
      'Ginecologia' => Colors.purple.shade100,
      'Neurologia' => Colors.teal.shade100,
      'Medicina Generale' => Colors.orange.shade100,
      'Oculistica' => Colors.indigo.shade100,
      'Otorinolaringoiatria' => Colors.amber.shade100,
      'Endocrinologia' => Colors.cyan.shade100,
      _ => Colors.grey.shade100,
    };
  }
}
