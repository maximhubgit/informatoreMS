import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';
import 'package:informatoreMS/presentation/providers/medici_provider.dart';
import 'package:informatoreMS/presentation/screens/storico_full_screen.dart';
import 'package:informatoreMS/presentation/screens/medici_list_screen.dart';
import 'package:informatoreMS/presentation/screens/prossimi_appuntamenti_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Medical Calendar',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gestisci appuntamenti medici e visualizza statistiche',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 24),

              // RIGA 1: Card medici e card appuntamenti
              Row(
                children: [
                  Expanded(child: _mediciCard(context)),
                  const SizedBox(width: 12),
                  Expanded(child: _appuntamentiStatsCard(context)),
                ],
              ),

              const SizedBox(height: 16),

              // RIGA 2: Card prossimi appuntamenti (larghezza piena)
              _prossimiAppuntamentiCard(context),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediciCard(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final mediciAsync = ref.watch(mediciProvider);
        return mediciAsync.when(
          data: (medici) => GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MediciListScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.medical_services,
                    size: 32,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${medici.length}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                      Text(
                        'Medici',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          loading: () => const Card(child: SizedBox(height: 80)),
          error: (_, __) => const Card(child: SizedBox(height: 80)),
        );
      },
    );
  }

  Widget _appuntamentiStatsCard(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final calendarioAsync = ref.watch(calendarioProvider);
        return calendarioAsync.when(
          data: (calendario) {
            final annoCorrente = DateTime.now().year;
            final trentaGiorniFa = DateTime.now().subtract(const Duration(days: 30));

            final appuntamentiAnno = calendario
                .where((s) => s.data.year == annoCorrente && s.stato == StatoCalendario.fatto)
                .length;

            final appuntamenti30gg = calendario
                .where((s) =>
                    s.data.isAfter(trentaGiorniFa) && s.stato == StatoCalendario.fatto)
                .length;

            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StoricoFullScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 32,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$appuntamentiAnno appuntamenti',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                ),
                          ),
                          Text(
                            'anno $annoCorrente',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$appuntamenti30gg ultimi 30 gg',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Card(child: SizedBox(height: 80)),
          error: (_, __) => const Card(child: SizedBox(height: 80)),
        );
      },
    );
  }

  Widget _prossimiAppuntamentiCard(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final calendarioAsync = ref.watch(calendarioProvider);

        return calendarioAsync.when(
          data: (appuntamenti) {
            final proposti = appuntamenti
                .where((a) => !a.stato.isConcluso)
                .toList()
              ..sort((a, b) => a.data.compareTo(b.data));

            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProssimiAppuntamentiScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Prossimi Appuntamenti',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (proposti.isEmpty)
                      Text(
                        'Nessun appuntamento futuro',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: proposti.length > 5 ? 5 : proposti.length,
                        itemBuilder: (context, index) {
                          final app = proposti[index];
                          return _buildListItem(context, app);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Card(child: SizedBox(height: 200)),
          error: (_, __) => const Card(child: SizedBox(height: 200)),
        );
      },
    );
  }

  Widget _buildListItem(BuildContext context, CalendarioAppuntamento app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: app.stato.colore.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: app.stato.colore,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              app.soloData.formatItalia(),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            app.oraFormattata,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: app.stato.colore.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              app.stato.label,
              style: TextStyle(
                fontSize: 10,
                color: app.stato.colore,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}