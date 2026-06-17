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
    // Login anonimo via Firebase Auth.
    // Eventuali errori (es. Auth non abilitato, network) vengono propagati
    // alla UI che li mostra all'utente.
    await FirebaseAuth.instance.signInAnonymously();
    state = AuthStatus.authenticated;
  }

  Future<void> logout() async {
    // Tenta il sign-out Firebase. Se per qualsiasi motivo fallisce
    // (es. già disconnesso), lo stato locale viene comunque portato a
    // "unauthenticated" per riflettere ciò che l'utente vede.
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Ignora: lo stato locale viene aggiornato comunque.
    }
    state = AuthStatus.unauthenticated;
  }

  /// Login con email/password.
  Future<void> loginWithEmail(String email, String password) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
  }
}

/// Helper per controllare se l'utente è loggato.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) == AuthStatus.authenticated;
});
