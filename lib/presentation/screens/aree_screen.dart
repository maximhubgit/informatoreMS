import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/area.dart';
import 'package:informatoreMS/presentation/providers/area_provider.dart';

class AreeScreen extends ConsumerStatefulWidget {
  const AreeScreen({super.key});

  @override
  ConsumerState<AreeScreen> createState() => _AreeScreenState();
}

class _AreeScreenState extends ConsumerState<AreeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvaArea() async {
    if (!_formKey.currentState!.validate()) return;

    final codice = ref.read(prossimoCodiceAreaProvider);
    final area = Area(
      id: Area.formattaCodice(codice),
      nome: _nomeCtrl.text.trim(),
    );

    await ref.read(salvaAreaProvider)(area);
    _nomeCtrl.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Area salvata')),
      );
    }
  }

  Future<void> _modificaArea(Area area) async {
    final ctrl = TextEditingController(text: area.nome);
    final nuovoNome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica Area'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nome area'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (nuovoNome != null && nuovoNome.trim().isNotEmpty && mounted) {
      await ref.read(salvaAreaProvider)(Area(id: area.id, nome: nuovoNome.trim()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Area aggiornata')),
      );
    }
  }

  Future<void> _eliminaArea(Area area) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confermi l\'eliminazione?'),
        content: Text('L\'area "${area.nome}" (${area.id}) verrà rimossa.'),
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
      await ref.read(eliminaAreaProvider)(area.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Area eliminata')),
      );
    }
  }

  void _mostraDialogAggiungi() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aggiungi Area'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Codice area calcolato automaticamente (solo informativo)
              Consumer(
                builder: (context, ref, _) {
                  final codice = ref.watch(prossimoCodiceAreaProvider);
                  return Text(
                    'Codice area: ${Area.formattaCodice(codice)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome area'),
                validator: (v) => v?.isEmpty ?? true ? 'Campo obbligatorio' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _salvaArea();
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final areeAsync = ref.watch(areaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Aree'),
        centerTitle: true,
      ),
      body: areeAsync.when(
        data: (aree) {
          if (aree.isEmpty) {
            return const Center(child: Text('Nessuna area presente'));
          }

          return ListView.separated(
            itemCount: aree.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final area = aree[index];
              final isProtetta = area.id == Area.idNonGeolocalizzato;
              return ListTile(
                title: Text(area.nome),
                subtitle: Text('Codice: ${area.id}'),
                trailing: isProtetta
                    ? const Icon(Icons.lock_outline, color: Colors.grey)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _modificaArea(area),
                            tooltip: 'Modifica',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminaArea(area),
                            tooltip: 'Elimina',
                          ),
                        ],
                      ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostraDialogAggiungi,
        child: const Icon(Icons.add),
      ),
    );
  }
}