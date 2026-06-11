import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';

class StoricoFullScreen extends ConsumerWidget {
  const StoricoFullScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarioAsync = ref.watch(calendarioProvider);
    final medicoMap = ref.watch(medicoByIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storico Appuntamenti'),
        centerTitle: true,
      ),
      body: calendarioAsync.when(
        data: (calendario) {
          // Filtriamo solo gli appuntamenti conclusi (fatto/annullato)
          final storico = calendario.where((a) => a.stato.isConcluso).toList();

          if (storico.isEmpty) {
            return _emptyState(context);
          }
          final sorted = List<CalendarioAppuntamento>.from(storico)
            ..sort((a, b) => b.data.compareTo(a.data));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final entry = sorted[index];
              final medico = medicoMap[entry.medicoId];
              return _buildStoricoTile(context, entry, medico?.nomeCompleto);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Errore: $err')),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Nessuno storico disponibile',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoricoTile(
    BuildContext context,
    CalendarioAppuntamento entry,
    String? nomeMedico,
  ) {
    final isFatto = entry.stato == StatoCalendario.fatto;
    final color = isFatto ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(
            isFatto ? Icons.check : Icons.close,
            color: color,
          ),
        ),
        title: Text(nomeMedico ?? 'Medico sconosciuto'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${entry.soloData.formatItalia()} alle ${entry.oraFormattata}'),
            Text('Stato: ${entry.stato.label}'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          _showDetailDialog(context, entry);
        },
      ),
    );
  }

  void _showDetailDialog(BuildContext context, CalendarioAppuntamento entry) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dettaglio Appuntamento'),
          content: Text('Data: ${entry.soloData.formatItalia()} '
              'alle ${entry.oraFormattata}\n'
              'Stato: ${entry.stato.label}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ],
        );
      },
    );
  }
}
