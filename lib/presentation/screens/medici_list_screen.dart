import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/extensions/specializzazione_extension.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/core/models/specializzazione.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';
import 'package:informatoreMS/presentation/providers/medici_provider.dart';
import 'package:informatoreMS/presentation/providers/specializzazione_provider.dart';
import 'package:informatoreMS/presentation/providers/zone_provider.dart';
import 'package:informatoreMS/presentation/providers/zone_selezionate_provider.dart';
import 'medico_edit_screen.dart';

enum OrdinamentoMedico { alfabetico, prossimaVisita, zona }

final ordinamentoMedicoProvider = StateProvider<OrdinamentoMedico>((ref) => OrdinamentoMedico.alfabetico);

class MediciListScreen extends ConsumerWidget {
  const MediciListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediciAsync = ref.watch(mediciProvider);
    final calendarioAsync = ref.watch(calendarioProvider);
    final zoneSelezionate = ref.watch(zoneSelezionateProvider);
    final ordinamento = ref.watch(ordinamentoMedicoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medici'),
        centerTitle: true,
        actions: [
          PopupMenuButton<OrdinamentoMedico>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              ref.read(ordinamentoMedicoProvider.notifier).state = value;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: OrdinamentoMedico.alfabetico,
                child: Text('Ordine alfabetico'),
              ),
              const PopupMenuItem(
                value: OrdinamentoMedico.prossimaVisita,
                child: Text('Per prossima visita'),
              ),
              const PopupMenuItem(
                value: OrdinamentoMedico.zona,
                child: Text('Per zona'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MedicoEditScreen()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _zoneFilterChip(context, ref),
        ),
      ),
      body: mediciAsync.when(
        data: (medici) {
          // Costruisci un map medicoId -> zonaId della fascia principale
          final fasceAsyncValue = ref.watch(fasceOrarieProvider);
          final fasce = fasceAsyncValue.asData?.value ?? [];
          final zonaPerMedico = <String, String>{};
          for (final fascia in fasce.where((f) => f.nr == 0)) {
            zonaPerMedico[fascia.idMedico] = fascia.zonaId;
          }

          final mediciFiltrati = zoneSelezionate.isEmpty
              ? medici
              : medici.where((m) => zoneSelezionate.contains(zonaPerMedico[m.id])).toList();

          if (mediciFiltrati.isEmpty) {
            return _emptyState(context);
          }

          final mediciOrdinati = _ordinaMedici(
              mediciFiltrati, calendarioAsync.asData?.value ?? [], ordinamento, ref);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mediciOrdinati.length,
            itemBuilder: (context, index) {
              final medico = mediciOrdinati[index];
              return Dismissible(
                key: Key(medico.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Medico eliminato (mock)')),
                  );
                },
                child: _buildMedicoTile(
                    context, medico, calendarioAsync.asData?.value ?? [], ref),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Errore: $err')),
      ),
    );
  }

  Widget _zoneFilterChip(BuildContext context, WidgetRef ref) {
    final zoneAsync = ref.watch(zoneProvider);
    final zoneSelezionate = ref.watch(zoneSelezionateProvider);

    return zoneAsync.when(
      data: (zone) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: zone.map((z) {
            final isSelected = zoneSelezionate.contains(z.id);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(z.nome),
                selected: isSelected,
                onSelected: (_) {
                  ref.read(zoneSelezionateProvider.notifier).toggle(z.id);
                },
                selectedColor: z.colore.withValues(alpha: 0.3),
              ),
            );
          }).toList(),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  List<Medico> _ordinaMedici(
    List<Medico> medici,
    List<CalendarioAppuntamento> calendario,
    OrdinamentoMedico ordinamento,
    WidgetRef ref,
  ) {
    final result = List<Medico>.from(medici);

    // Costruisci un map medicoId -> zonaId della fascia principale
    final fasceAsyncValue = ref.read(fasceOrarieProvider);
    final fasce = fasceAsyncValue.asData?.value ?? [];
    final zonaPerMedico = <String, String>{};
    for (final fascia in fasce.where((f) => f.nr == 0)) {
      zonaPerMedico[fascia.idMedico] = fascia.zonaId;
    }

    switch (ordinamento) {
      case OrdinamentoMedico.alfabetico:
        result.sort((a, b) => a.nomeCompleto.compareTo(b.nomeCompleto));
      case OrdinamentoMedico.prossimaVisita:
        result.sort((a, b) {
          final aVisita = _calcolaProssimaVisita(a, calendario);
          final bVisita = _calcolaProssimaVisita(b, calendario);
          if (aVisita == null && bVisita == null) return 0;
          if (aVisita == null) return 1;
          if (bVisita == null) return -1;
          return aVisita.compareTo(bVisita);
        });
      case OrdinamentoMedico.zona:
        result.sort((a, b) {
          final aZona = zonaPerMedico[a.id] ?? '';
          final bZona = zonaPerMedico[b.id] ?? '';
          return aZona.compareTo(bZona);
        });
    }

    return result;
  }

  DateTime? _calcolaProssimaVisita(Medico medico, List<CalendarioAppuntamento> calendario) {
    // Prima controlla se c'è un appuntamento concordato nel calendario
    final concordato = calendario.where((a) =>
        a.medicoId == medico.id && a.stato == StatoCalendario.concordato).toList();
    if (concordato.isNotEmpty) {
      concordato.sort((a, b) => a.data.compareTo(b.data));
      return concordato.first.soloData;
    }

    // Poi cerca tra i proposti (non ancora confermati)
    final proposti = calendario.where((a) =>
        a.medicoId == medico.id && a.stato == StatoCalendario.proposto).toList();
    if (proposti.isNotEmpty) {
      proposti.sort((a, b) => a.data.compareTo(b.data));
      return proposti.first.soloData;
    }

    // Infine usa l'ultima visita fatta
    final ultimi = calendario
        .where((a) => a.medicoId == medico.id && a.stato == StatoCalendario.fatto)
        .toList();
    if (ultimi.isNotEmpty) {
      ultimi.sort((a, b) => b.data.compareTo(a.data));
      return ultimi.first.soloData.addDays(medico.periodicitaGiorni);
    }

    return null;
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun medico registrato',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicoTile(
    BuildContext context,
    Medico medico,
    List<CalendarioAppuntamento> calendario,
    WidgetRef ref,
  ) {
    final zoneMap = ref.read(zonaByIdProvider);
    final specializzazioniMap = ref.read(specializzazioneByIdProvider);
    final specializzazione = specializzazioniMap[medico.specializzazioneId];
    final prossimaVisita = _calcolaProssimaVisita(medico, calendario);

    // Prendi la zona dalla fascia principale (nr=0)
    final fasceAsyncValue = ref.read(fasceOrarieProvider);
    final fasce = fasceAsyncValue.asData?.value ?? [];
    final fasciaPrincipale = fasce.where((f) => f.idMedico == medico.id && f.nr == 0).firstOrNull;
    final zona = fasciaPrincipale != null ? zoneMap[fasciaPrincipale.zonaId] : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            specializzazione?.iconaSpecializzazione ?? Icons.local_hospital,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          medico.nomeCompleto,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(specializzazione?.nome ?? 'Specializzazione sconosciuta'),
            Text('Zona: ${zona?.nome ?? 'Sconosciuta'}'),
            if (fasciaPrincipale?.struttura != null && fasciaPrincipale!.struttura!.isNotEmpty)
              Text('Struttura: ${fasciaPrincipale.struttura}'),
            if (prossimaVisita != null)
              Text('Prossima visita: ${prossimaVisita.formatItalia()}'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MedicoEditScreen(medico: medico),
            ),
          );
        },
      ),
    );
  }
}
