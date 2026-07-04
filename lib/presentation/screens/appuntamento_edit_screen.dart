import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/presentation/providers/zone_provider.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';
import 'package:informatoreMS/presentation/providers/medici_provider.dart';

/// Schermata per modificare o eliminare un appuntamento concordato.
/// Mostra informazioni medico in sola lettura e permette modifica appuntamento.
class AppuntamentoEditScreen extends ConsumerStatefulWidget {
  final Medico medico;
  final CalendarioAppuntamento appuntamento;
  final bool salvaComeConcordato;

  const AppuntamentoEditScreen({
    super.key,
    required this.medico,
    required this.appuntamento,
    this.salvaComeConcordato = false,
  });

  @override
  ConsumerState<AppuntamentoEditScreen> createState() => _AppuntamentoEditScreenState();
}

class _AppuntamentoEditScreenState extends ConsumerState<AppuntamentoEditScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.appuntamento.soloData;
    _selectedTime = TimeOfDay.fromDateTime(widget.appuntamento.data);
  }

  @override
  Widget build(BuildContext context) {
    final zoneAsync = ref.watch(zoneProvider);
    // La zona è ora nella fascia oraria, prendiamo la prima (nr=0)
    final fasceAsync = ref.watch(fasceOrarieMedicoProvider(widget.medico.id));
    final zona = zoneAsync.when(
      data: (zone) {
        final fasciaPrincipale = fasceAsync.maybeWhen(
          data: (fasce) => fasce.where((f) => f.nr == 0).firstOrNull,
          orElse: () => null,
        );
        if (fasciaPrincipale != null) {
          return zone.where((z) => z.id == fasciaPrincipale.zonaId).firstOrNull;
        }
        return null;
      },
      loading: () => null,
      error: (_, __) => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifica Appuntamento'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _elimina,
          ),
        ],
      ),
      body: zoneAsync.when(
        data: (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Sezione medico in sola lettura
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medico',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.medico.nomeCompleto,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (zona != null) ...[
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: zona.colore,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            zona.nome,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildUltimaVisita(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Modifica data/orario
            Text(
              'Data e Orario',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selezionaData,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(_selectedDate?.formatItalia() ?? 'Seleziona data'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _selezionaOra,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Ora',
                        suffixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(_selectedTime?.formatTime() ?? 'Seleziona ora'),
                    ),
                  ),
                ),
              ],
            ),
            // Selezione fascia oraria
            fasceAsync.when(
              data: (fasce) {
                if (fasce.length <= 1) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Fascia Oraria',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: widget.appuntamento.fasciaNumero ?? 1,
                      decoration: const InputDecoration(labelText: 'Numero Fascia'),
                      items: fasce.asMap().entries.map((e) {
                        final index = e.key + 1; // Numero progressivo a partire da 1
                        final fascia = e.value;
                        return DropdownMenuItem(
                          value: index,
                          child: Text('Fascia $index (${fascia.inizio.formatTime()} - ${fascia.fine.formatTime()})'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(salvaAppuntamentoProvider)(
                            widget.appuntamento.copyWith(fasciaNumero: v == 1 ? null : v),
                          );
                        }
                      },
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _salva,
              child: const Text('Salva Modifiche'),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Errore: $err')),
      ),
    );
  }

  Widget _buildUltimaVisita() {
    // Trova l'ultima visita fatta per questo medico
    final calendarioAsync = ref.watch(calendarioProvider);

    return calendarioAsync.when(
      data: (appuntamenti) {
        final ultimaVisita = appuntamenti
            .where((a) => a.medicoId == widget.medico.id && a.stato == StatoCalendario.fatto)
            .toList()
          ..sort((a, b) => b.soloData.compareTo(a.soloData));

        if (ultimaVisita.isEmpty) {
          return Text(
            'Nessuna visita precedente',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
          );
        }

        return Text(
          'Ultima visita: ${ultimaVisita.first.soloData.formatItalia()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _selezionaData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selezionaOra() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _salva() async {
    if (_selectedDate == null || _selectedTime == null) return;

    final nuovaData = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final aggiornamento = widget.appuntamento.copyWith(data: nuovaData);
    // Se salvaComeConcordato è true e lo stato era "proposto", diventa "concordato"
    // Altrimenti mantiene lo stato esistente (confermato, fatto, ecc.)
    final salvataggio = widget.salvaComeConcordato && widget.appuntamento.stato == StatoCalendario.proposto
        ? aggiornamento.copyWith(stato: StatoCalendario.concordato)
        : aggiornamento;

    await ref.read(salvaAppuntamentoProvider)(salvataggio);

    ref.refresh(calendarioProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appuntamento aggiornato')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _elimina() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confermi l\'eliminazione?'),
        content: Text(
          'L\'appuntamento del ${widget.appuntamento.soloData.formatItalia()} verrà rimosso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (conferma == true && mounted) {
      await ref.read(calendarioRepositoryProvider).delete(widget.appuntamento.id);
      ref.refresh(calendarioProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appuntamento eliminato')),
      );
      Navigator.of(context).pop();
    }
  }
}