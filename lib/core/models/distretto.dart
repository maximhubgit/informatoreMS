import 'package:equatable/equatable.dart';

class Distretto extends Equatable {
  final int codice;
  final int nrDistretto; // Numero del distretto
  final String descrizione;
  final int codiceAsl; // Foreign key all'ASL

  const Distretto({
    required this.codice,
    required this.nrDistretto,
    required this.descrizione,
    required this.codiceAsl,
  });

  String get campoDescrittivo => '$nrDistretto - $descrizione'; // Campo combinato per ricerche

  Distretto copyWith({
    int? codice,
    int? nrDistretto,
    String? descrizione,
    int? codiceAsl,
  }) {
    return Distretto(
      codice: codice ?? this.codice,
      nrDistretto: nrDistretto ?? this.nrDistretto,
      descrizione: descrizione ?? this.descrizione,
      codiceAsl: codiceAsl ?? this.codiceAsl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codice': codice,
      'nrDistretto': nrDistretto,
      'descrizione': descrizione,
      'codiceAsl': codiceAsl,
    };
  }

  factory Distretto.fromJson(Map<String, dynamic> json) {
    // Fallback per nrDistretto: usa il codice se non presente
    final nrDistrettoValue = json['nrDistretto'] ?? json['codice'];
    return Distretto(
      codice: json['codice'] is int
          ? json['codice'] as int
          : int.parse(json['codice'].toString()),
      nrDistretto: nrDistrettoValue is int
          ? nrDistrettoValue as int
          : int.parse(nrDistrettoValue.toString()),
      descrizione: json['descrizione'] as String,
      codiceAsl: json['codiceAsl'] is int
          ? json['codiceAsl'] as int
          : int.parse(json['codiceAsl'].toString()),
    );
  }

  @override
  List<Object?> get props => [codice, nrDistretto, descrizione, codiceAsl];
}