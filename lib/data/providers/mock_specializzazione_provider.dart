import 'package:flutter/material.dart';
import 'package:informatoreMS/core/models/specializzazione.dart';

/// Provider mock statico per le specializzazioni.
class MockSpecializzazioneProvider {
  MockSpecializzazioneProvider._();

  static final List<Specializzazione> specializzazioni = [
    const Specializzazione(
      id: 's1',
      nome: 'Cardiologia',
      icona: Icons.favorite,
    ),
    const Specializzazione(
      id: 's2',
      nome: 'Dermatologia',
      icona: Icons.spa,
    ),
    const Specializzazione(
      id: 's3',
      nome: 'Ortopedia',
      icona: Icons.accessibility_new,
    ),
    const Specializzazione(
      id: 's4',
      nome: 'Pediatria',
      icona: Icons.child_care,
    ),
    const Specializzazione(
      id: 's5',
      nome: 'Ginecologia',
      icona: Icons.pregnant_woman,
    ),
    const Specializzazione(
      id: 's6',
      nome: 'Neurologia',
      icona: Icons.psychology,
    ),
    const Specializzazione(
      id: 's7',
      nome: 'Medicina Generale',
      icona: Icons.medical_services,
    ),
    const Specializzazione(
      id: 's8',
      nome: 'Oculistica',
      icona: Icons.visibility,
    ),
    const Specializzazione(
      id: 's9',
      nome: 'Otorinolaringoiatria',
      icona: Icons.hearing,
    ),
    const Specializzazione(
      id: 's10',
      nome: 'Endocrinologia',
      icona: Icons.water_drop,
    ),
  ];
}
