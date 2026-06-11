import 'dart:convert';

/// Tipo di operazione pendente.
enum TipoOperazione { sposta, registraEsito }

/// Rappresenta un'operazione fatta offline che deve essere sincronizzata
/// quando torna la connessione.
class PendingOperation {
  final String id;
  final TipoOperazione tipo;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  const PendingOperation({
    required this.id,
    required this.tipo,
    required this.payload,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'payload': payload,
    'timestamp': timestamp.toIso8601String(),
  };

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: json['id'] as String,
      tipo: TipoOperazione.values.byName(json['tipo'] as String),
      payload: json['payload'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  String toRawJson() => jsonEncode(toJson());

  factory PendingOperation.fromRawJson(String raw) =>
      PendingOperation.fromJson(jsonDecode(raw));
}
