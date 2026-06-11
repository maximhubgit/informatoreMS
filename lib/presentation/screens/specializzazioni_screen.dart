import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:informatoreMS/core/models/specializzazione.dart';
import 'package:informatoreMS/presentation/providers/specializzazione_provider.dart';

class SpecializzazioniScreen extends ConsumerWidget {
  const SpecializzazioniScreen({super.key});

  void _mostraDialogSpecializzazione(
    BuildContext context,
    WidgetRef ref, {
    Specializzazione? specializzazione,
  }) {
    final nomeController = TextEditingController(text: specializzazione?.nome ?? '');
    final isEdit = specializzazione != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Modifica specializzazione' : 'Nuova specializzazione'),
        content: TextField(
          controller: nomeController,
          decoration: const InputDecoration(
            labelText: 'Nome specializzazione',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomeController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inserisci un nome')),
                );
                return;
              }

              final spec = isEdit
                  ? specializzazione!.copyWith(nome: nomeController.text)
                  : Specializzazione(
                      id: const Uuid().v4(),
                      nome: nomeController.text,
                    );

              if (isEdit) {
                await ref.read(aggiornaSpecializzazioneProvider)(spec);
              } else {
                await ref.read(salvaSpecializzazioneProvider)(spec);
              }

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(isEdit ? 'Salva' : 'Aggiungi'),
          ),
        ],
      ),
    );
  }

  void _confermaEliminazione(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina specializzazione'),
        content: const Text('Sei sicuro di voler eliminare questa specializzazione?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(eliminaSpecializzazioneProvider)(id);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specializzazioneAsync = ref.watch(specializzazioneProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Specializzazioni'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(specializzazioneProvider),
          ),
        ],
      ),
      body: specializzazioneAsync.when(
        data: (specializzazioni) {
          if (specializzazioni.isEmpty) {
            return const Center(child: Text('Nessuna specializzazione'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DataTable(
              columnSpacing: 24,
              headingRowColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.primaryContainer,
              ),
              columns: const [
                DataColumn(label: Text('Specializzazione')),
                DataColumn(label: Text('Icona')),
                DataColumn(label: Text('Azioni')),
              ],
              rows: specializzazioni.map((spec) {
                return DataRow(
                  cells: [
                    DataCell(Text(spec.nome)),
                    const DataCell(Icon(Icons.medical_services)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _mostraDialogSpecializzazione(
                              context,
                              ref,
                              specializzazione: spec,
                            ),
                            tooltip: 'Modifica',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () => _confermaEliminazione(context, ref, spec.id),
                            tooltip: 'Elimina',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Errore: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(specializzazioneProvider),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostraDialogSpecializzazione(context, ref),
        tooltip: 'Aggiungi specializzazione',
        child: const Icon(Icons.add),
      ),
    );
  }
}
