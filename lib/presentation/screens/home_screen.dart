import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/presentation/providers/auth_provider.dart';
import 'package:informatoreMS/presentation/screens/dashboard_screen.dart';
import 'package:informatoreMS/presentation/screens/prossimi_appuntamenti_screen.dart';
import 'package:informatoreMS/presentation/screens/report_screen.dart';
import 'package:informatoreMS/presentation/screens/zone_screen.dart';
import 'package:informatoreMS/presentation/screens/specializzazioni_screen.dart';
import 'package:informatoreMS/presentation/screens/medici_list_screen.dart';
import 'package:informatoreMS/presentation/screens/appuntamenti_concordati_screen.dart';
import 'package:informatoreMS/presentation/screens/calendario_mese_screen.dart';
import 'package:informatoreMS/presentation/screens/asl_screen.dart';
import 'package:informatoreMS/presentation/screens/distretti_screen.dart';
import 'package:informatoreMS/data/seed_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario Medico'),
        centerTitle: true,
      ),
      drawer: AppDrawer(),
      body: const DashboardScreen(),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

class BottomNavBar extends ConsumerWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationBar(
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProssimiAppuntamentiScreen()),
            );
            break;
          case 1:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppuntamentiConcordatiScreen()),
            );
            break;
          case 2:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CalendarioMeseScreen()),
            );
            break;
          case 3:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportScreen()),
            );
            break;
        }
      },
      selectedIndex: 0,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.table_chart_outlined),
          label: 'Pianificazioni',
        ),
        NavigationDestination(
          icon: Icon(Icons.book_outlined),
          label: 'Concordati',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_today),
          label: 'Calendario',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          label: 'Report',
        ),
      ],
    );
  }
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(context),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Zone'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ZoneScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Specializzazioni'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SpecializzazioniScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.medical_services_outlined),
            title: const Text('Medici'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MediciListScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('ASL'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AslScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Distretti'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DistrettiScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.book_outlined),
            title: const Text('Appuntamenti Concordati'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppuntamentiConcordatiScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Calendario'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalendarioMeseScreen()),
              );
            },
          ),
          const Divider(),
          if (!kReleaseMode) _buildSeedTile(context, ref),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}

Widget _buildHeader(BuildContext context) {
  return DrawerHeader(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.medical_services,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 48,
        ),
        const SizedBox(height: 8),
        Text(
          'Calendario Medico',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
        ),
      ],
    ),
  );
}

Widget _buildSeedTile(BuildContext context, WidgetRef ref) {
  return ListTile(
    leading: const Icon(Icons.download, color: Colors.orange),
    title: const Text('Seed Database'),
    onTap: () {
      Navigator.pop(context);
      ref.read(seedDatabaseProvider)(context);
    },
  );
}
