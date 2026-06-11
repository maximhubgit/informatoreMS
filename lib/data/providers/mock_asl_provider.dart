import 'package:informatoreMS/core/models/asl.dart';

/// Provider mock statico per le ASL.
class MockAslProvider {
  MockAslProvider._();

  static final List<Asl> aslList = [
    const Asl(codice: 1, descrizione: 'ASL Roma 1'),
    const Asl(codice: 2, descrizione: 'ASL Roma 2'),
    const Asl(codice: 3, descrizione: 'ASL Milano'),
    const Asl(codice: 4, descrizione: 'ASL Napoli'),
  ];
}