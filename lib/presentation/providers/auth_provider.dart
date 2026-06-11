import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Stato di autenticazione.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Provider per gestire lo stato di login con Firebase Auth.
final authProvider = StateNotifierProvider<AuthNotifier, AuthStatus>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthStatus> {
  AuthNotifier() : super(AuthStatus.unauthenticated); // Parte sempre da non autenticato

  Future<void> login() async {
    // Login fittizio (mock) - non richiede credenziali reali
    try {
      // Prova a usare Firebase, ma in modalità mock va in catch
      await FirebaseAuth.instance.signInAnonymously();
      state = AuthStatus.authenticated;
    } catch (e) {
      // Modalità mock - sempre autenticato dopo aver premuto Accedi
      state = AuthStatus.authenticated;
    }
  }

  void logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      state = AuthStatus.unauthenticated;
    } catch (e) {
      // Mock mode
      state = AuthStatus.unauthenticated;
    }
  }

  /// Login con email/password (per futuro)
  Future<void> loginWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // Mock mode - always succeeds
      state = AuthStatus.authenticated;
    }
  }
}

/// Helper per controllare se l'utente è loggato.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) == AuthStatus.authenticated;
});
