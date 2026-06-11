import 'package:informatoreMS/core/models/zona.dart';

/// Provider mock statico per le zone.
class MockZonaProvider {
  MockZonaProvider._();

  static final List<Zona> zone = [
    const Zona(id: 'z1', nome: 'Centro Storico', coloreHex: '#FF6B6B'),
    const Zona(id: 'z2', nome: 'Periferia Nord', coloreHex: '#4ECDC4'),
    const Zona(id: 'z3', nome: 'Periferia Sud', coloreHex: '#45B7D1'),
    const Zona(id: 'z4', nome: 'Zona Ovest', coloreHex: '#96CEB4'),
  ];
}
