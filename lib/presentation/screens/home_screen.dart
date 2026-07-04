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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informatore Medico Scentifico'),
        centerTitle: true,
      ),
      drawer: const AppDrawer(),
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
          label: 'Pianifica',
        ),
        NavigationDestination(
          icon: Icon(Icons.book_outlined),
          label: 'Gestisci',
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Drawer(
      width: 300,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header con gradiente ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cs.onPrimary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.onPrimary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.medical_services_rounded,
                      color: cs.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Informatore Medico Scentifico',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Informatore MS',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onPrimary.withValues(alpha: 0.8),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Corpo con sezioni scrollabile ──────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('Principale'),
                    _DrawerItem(
                      icon: Icons.table_chart_outlined,
                      label: 'Pianifica',
                      onTap: () => _openScreen(context, const ProssimiAppuntamentiScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.handshake_outlined,
                      label: 'Gestisci',
                      onTap: () => _openScreen(context, const AppuntamentiConcordatiScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.calendar_month_rounded,
                      label: 'Calendario',
                      onTap: () => _openScreen(context, const CalendarioMeseScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Report',
                      onTap: () => _openScreen(context, const ReportScreen()),
                    ),

                    const SizedBox(height: 12),
                    const _SectionLabel('Anagrafica'),
                    _DrawerItem(
                      icon: Icons.location_on_outlined,
                      label: 'Zone',
                      onTap: () => _openScreen(context, const ZoneScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.category_outlined,
                      label: 'Specializzazioni',
                      onTap: () => _openScreen(context, const SpecializzazioniScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.medical_services_outlined,
                      label: 'Medici',
                      onTap: () => _openScreen(context, const MediciListScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.account_balance_outlined,
                      label: 'ASL',
                      onTap: () => _openScreen(context, const AslScreen()),
                    ),
                    _DrawerItem(
                      icon: Icons.map_outlined,
                      label: 'Distretti',
                      onTap: () => _openScreen(context, const DistrettiScreen()),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Footer: Logout isolato ──────────────────────────────────────
            const Divider(height: 1),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: 'Logout',
              destructive: true,
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

/// Label di sezione (es. "PRINCIPALE", "ANAGRAFICA").
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Singola voce del drawer con icona in box arrotondato colorato.
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Color bgColor = destructive
        ? cs.errorContainer
        : cs.primaryContainer;
    final Color fgColor = destructive
        ? cs.onErrorContainer
        : cs.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: fgColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: destructive ? cs.error : cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
