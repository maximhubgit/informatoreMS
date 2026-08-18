import 'package:equatable/equatable.dart';

/// Area di visitazione: corrisponde alla collection Firestore 'aree'.
///
/// Il `documentId` è la chiave formattata a partire dal codice area
/// (es. codice 7 -> 'A007'); la sentinella -1 (non geolocalizzato) -> '0000'.
/// Il campo 'Area' del documento contiene il nome.
class Area extends Equatable {
  final String id; // documentId, es. 'A007' o '0000'
  final String nome; // campo 'Area' nel documento

  const Area({
    required this.id,
    required this.nome,
  });

  /// Id della sentinella "NON GEOLOCALIZZATO", protetta dalle operazioni CRUD.
  static const String idNonGeolocalizzato = '0000';

  /// Ricompone la chiave documento dall'id numerico dell'area,
  /// in modo coerente con `format_area_id` nello script Python:
  /// -1 -> '0000', altrimenti 'A' + numero a 3 cifre (es. 7 -> 'A007').
  static String formattaCodice(int codice) {
    if (codice == -1) return idNonGeolocalizzato;
    return 'A${codice.toString().padLeft(3, '0')}';
  }

  Area copyWith({
    String? id,
    String? nome,
  }) {
    return Area(
      id: id ?? this.id,
      nome: nome ?? this.nome,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Area': nome,
    };
  }

  @override
  List<Object?> get props => [id, nome];
}