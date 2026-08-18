import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/fascia_oraria.dart';
import 'package:informatoreMS/core/models/zona.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';
import 'package:informatoreMS/presentation/providers/medici_provider.dart';
import 'package:informatoreMS/presentation/providers/zone_provider.dart';
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'BIOGENA',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                textAlign: TextAlign.center,
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
        final fasceAsync = ref.watch(fasceOrarieProvider);
        final zoneAsync = ref.watch(zoneProvider);

        return mediciAsync.when(
          data: (medici) => fasceAsync.when(
            data: (fasce) => zoneAsync.when(
              data: (zone) {
                // Medici attivi: hanno almeno una fascia con deleted=false e isFittizia=false
                final fasceAttive = fasce.where((f) => !f.deleted && !f.isFittizia).toList();
                final medicoIdsConFasciaAttiva = fasceAttive.map((f) => f.idMedico).toSet();
                final mediciAttivi = medici.where((m) => medicoIdsConFasciaAttiva.contains(m.id)).length;

                // Zone attive: zone collegate alle sole fascie attive
                final zoneIdsAttive = fasceAttive.map((f) => f.zonaId).toSet();
                final zoneAttive = zone.where((z) => zoneIdsAttive.contains(z.id)).length;

                // Distretti attivi: distretti legati alle zone attive
                final distrettiAttivi = fasceAttive.map((f) => f.distrettoId).toSet().length;

                return GestureDetector(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Intestazione con nr totale medici
                        Row(
                          children: [
                            Icon(
                              Icons.medical_services,
                              size: 32,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${medici.length}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontSize: 14,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Dott',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 3 righe di statistiche
                        _buildStatItem(
                          label: 'Medici attivi',
                          value: '$mediciAttivi',
                          context: context,
                          isSecondary: true,
                        ),
                        _buildStatItem(
                          label: 'Zone attive',
                          value: '$zoneAttive',
                          context: context,
                          isSecondary: true,
                        ),
                        _buildStatItem(
                          label: 'Distretti attivi',
                          value: '$distrettiAttivi',
                          context: context,
                          isSecondary: true,
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Card(child: SizedBox(height: 120)),
              error: (_, __) => const Card(child: SizedBox(height: 120)),
            ),
            loading: () => const Card(child: SizedBox(height: 120)),
            error: (_, __) => const Card(child: SizedBox(height: 120)),
          ),
          loading: () => const Card(child: SizedBox(height: 120)),
          error: (_, __) => const Card(child: SizedBox(height: 120)),
        );
      },
    );
  }

  /// Widget per una riga di statistica nella card.
  Widget _buildStatItem({required String label, required String value, required BuildContext context, bool isSecondary = false}) {
    final Color textColor = isSecondary
        ? Theme.of(context).colorScheme.onSecondaryContainer
        : Theme.of(context).colorScheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _appuntamentiStatsCard(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final calendarioAsync = ref.watch(calendarioProvider);
        final mediciAsync = ref.watch(mediciProvider);
        final fasceAsync = ref.watch(fasceOrarieProvider);

        return mediciAsync.when(
          data: (medici) => fasceAsync.when(
            data: (fasce) {
              // Medici attivi: hanno almeno una fascia con deleted=false e isFittizia=false
              final fasceAttive = fasce.where((f) => !f.deleted && !f.isFittizia).toList();
              final medicoIdsConFasciaAttiva = fasceAttive.map((f) => f.idMedico).toSet();
              final mediciAttivi = medici.where((m) => medicoIdsConFasciaAttiva.contains(m.id)).length;

              // Calcolo appuntamenti previsti: (365 / 45) intero * medici attivi
              final appuntamentiPrevisti = (365 ~/ 45) * mediciAttivi;

              return calendarioAsync.when(
                data: (calendario) {
                  final adesso = DateTime.now();
                  final annoCorrente = adesso.year;
                  final meseCorrente = adesso.month;
                  final settimanaCorrente = _settimanaCorrente(adesso);

                  final appuntamentiAnno = calendario
                      .where((s) =>
                          s.data.year == annoCorrente &&
                          s.stato == StatoCalendario.fatto)
                      .length;

                  final appuntamentiMese = calendario
                      .where((s) =>
                          s.data.year == annoCorrente &&
                          s.data.month == meseCorrente &&
                          s.stato == StatoCalendario.fatto)
                      .length;

                  final appuntamentiSettimana = calendario
                      .where((s) =>
                          s.data.isAfter(settimanaCorrente) &&
                          s.stato == StatoCalendario.fatto)
                      .length;

                  final appuntamentiLabel = '$appuntamentiAnno/$appuntamentiPrevisti app';

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 32,
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                appuntamentiLabel,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildStatItem(
                            label: 'Anno',
                            value: '$appuntamentiAnno',
                            context: context,
                            isSecondary: true,
                          ),
                          _buildStatItem(
                            label: 'Mese',
                            value: '$appuntamentiMese',
                            context: context,
                            isSecondary: true,
                          ),
                          _buildStatItem(
                            label: 'Settimana',
                            value: '$appuntamentiSettimana',
                            context: context,
                            isSecondary: true,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Card(child: SizedBox(height: 120)),
                error: (_, __) => const Card(child: SizedBox(height: 120)),
              );
            },
            loading: () => const Card(child: SizedBox(height: 120)),
            error: (_, __) => const Card(child: SizedBox(height: 120)),
          ),
          loading: () => const Card(child: SizedBox(height: 120)),
          error: (_, __) => const Card(child: SizedBox(height: 120)),
        );
      },
    );
  }

  /// Calcola l'inizio della settimana corrente (lunedì).
  DateTime _settimanaCorrente(DateTime now) {
    final giornoSettimana = now.weekday;
    final differenzaGiorni = giornoSettimana == 1 ? 0 : giornoSettimana - 1;
    return DateTime(now.year, now.month, now.day - differenzaGiorni);
  }

  Widget _prossimiAppuntamentiCard(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final calendarioAsync = ref.watch(calendarioProvider);
        final fasciaById = ref.watch(fasciaByIdProvider);
        final zonaById = ref.watch(zonaByIdProvider);

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
                          return _buildListItem(context, app, fasciaById, zonaById);
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

  Widget _buildListItem(BuildContext context, CalendarioAppuntamento app, Map<String, FasciaOraria> fasciaById, Map<String, Zona> zonaById) {
    final fascia = fasciaById[app.fasciaOrariaId ?? ''];
    final zona = fascia != null ? zonaById[fascia.zonaId] : null;
    final zonaNome = zona != null ? (zona.nome.length > 12 ? zona.nome.substring(0, 12) : zona.nome) : '';

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
            child: Row(
              children: [
                Text(
                  app.soloData.formatItalia(),
                  style: const TextStyle(fontSize: 13),
                ),
                if (zonaNome.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '[$zonaNome]',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
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