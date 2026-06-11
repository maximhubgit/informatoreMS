import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/providers/firebase_provider.dart';
import 'package:informatoreMS/presentation/providers/auth_provider.dart';
import 'package:informatoreMS/presentation/screens/home_screen.dart';
import 'package:informatoreMS/presentation/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.delayed(const Duration(milliseconds: 1)); // Per permettere l'inizializzazione
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Aspetta l'inizializzazione Firebase
    final firebaseInit = ref.watch(firebaseInitializationProvider);

    return firebaseInit.when(
      data: (_) {
        final isAuthenticated = ref.watch(isAuthenticatedProvider);

        return MaterialApp(
          title: 'informatoreMS',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4ECDC4),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            chipTheme: ChipThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),),
          ),
          home: isAuthenticated ? const HomeScreen() : const LoginScreen(),
        );
      },
      loading: () => const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, stack) => MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Errore inizializzazione Firebase')),
        ),
      ),
    );
  }
}
