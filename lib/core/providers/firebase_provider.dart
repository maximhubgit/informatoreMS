import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:informatoreMS/core/firebase_options.dart';

/// Provider per l'inizializzazione Firebase.
final firebaseInitializationProvider = FutureProvider<void>((ref) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // La persistenza offline è abilitata di default su mobile
  } catch (e) {
    // Firebase non configurato
    if (kIsWeb) {
      throw Exception('Firebase non configurato. Configurare firebase_options.dart per l\'uso web.');
    }
    // Su mobile, lascia proseguire con persistenza locale
  }
});

/// Provider per verificare se Firebase è stato inizializzato correttamente.
final isFirebaseInitializedProvider = Provider<bool>((ref) {
  final async = ref.watch(firebaseInitializationProvider);
  return async.hasValue && !async.hasError;
});
