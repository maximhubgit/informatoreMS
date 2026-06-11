import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider che traccia lo stato della connettività.
/// Ritorna true se c'è almeno una connessione attiva (non none).
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
});

/// Provider singolo che espone l'ultimo stato noto di connessione.
final isConnectedProvider = Provider<bool>((ref) {
  final async = ref.watch(connectivityProvider);
  return async.when(
    data: (d) => d,
    loading: () => true, // ottimistico di default
    error: (_, _) => true,
  );
});
