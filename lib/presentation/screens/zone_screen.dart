import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/zona.dart';
import 'package:informatoreMS/presentation/providers/zone_provider.dart';
import 'package:uuid/uuid.dart';

class ZoneScreen extends ConsumerWidget {
  const ZoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoneAsync = ref.watch(zoneProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zone'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(zoneProvider),
          ),
        ],
      ),
      body: zoneAsync.when(
        data: (zone) => zone.isEmpty
            ? const Center(child: Text('Nessuna zona registrata'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: zone.length,
                itemBuilder: (context, index) {
                  final zona = zone[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: zona.colore,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(zona.nome),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _modificaZona(context, ref, zona),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => _eliminaZona(context, ref, zona),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Errore: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(zoneProvider),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _aggiungiDZone(context, ref),
      ),
    );
  }

  void _aggiungiDZone(BuildContext context, WidgetRef ref) {
    final _nomeCtrl = TextEditingController();
    final _coloreCtrl = TextEditingController(text: '#4ECDC4');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aggiungi Zona'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: _coloreCtrl,
              decoration: const InputDecoration(labelText: 'Colore (hex)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              if (_nomeCtrl.text.isNotEmpty) {
                final zona = Zona(
                  id: const Uuid().v4(),
                  nome: _nomeCtrl.text,
                  coloreHex: _coloreCtrl.text,
                );
                await ref.read(salvaZonaProvider)(zona);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _modificaZona(BuildContext context, WidgetRef ref, Zona zona) {
    final _nomeCtrl = TextEditingController(text: zona.nome);
    final _coloreCtrl = TextEditingController(text: zona.coloreHex);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica Zona'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: _coloreCtrl,
              decoration: const InputDecoration(labelText: 'Colore (hex)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              if (_nomeCtrl.text.isNotEmpty) {
                final zonaAggiornata = zona.copyWith(
                  nome: _nomeCtrl.text,
                  coloreHex: _coloreCtrl.text,
                );
                await ref.read(salvaZonaProvider)(zonaAggiornata);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _eliminaZona(BuildContext context, WidgetRef ref, Zona zona) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confermi?'),
        content: Text('Vuoi eliminare la zona "${zona.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(eliminaZonaProvider)(zona.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}
