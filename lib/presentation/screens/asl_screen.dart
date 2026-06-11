import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/asl.dart';
import 'package:informatoreMS/presentation/providers/asl_provider.dart';

class AslScreen extends ConsumerStatefulWidget {
  const AslScreen({super.key});

  @override
  ConsumerState<AslScreen> createState() => _AslScreenState();
}

class _AslScreenState extends ConsumerState<AslScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descrizioneCtrl;

  @override
  void initState() {
    super.initState();
    _descrizioneCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _descrizioneCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvaAsl() async {
    if (!_formKey.currentState!.validate()) return;

    final aslList = ref.read(aslProvider).valueOrNull ?? [];
    final nuovoCodice = aslList.isEmpty
        ? 1
        : (aslList.map((a) => a.codice).reduce((a, b) => a > b ? a : b) + 1);

    final asl = Asl(
      codice: nuovoCodice,
      descrizione: _descrizioneCtrl.text,
    );

    await ref.read(salvaAslProvider)(asl);
    _descrizioneCtrl.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ASL salvata')),
      );
    }
  }

  Future<void> _eliminaAsl(Asl asl) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confermi l\'eliminazione?'),
        content: Text('L\'ASL "${asl.descrizione}" verrà rimossa.'),
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
      await ref.read(eliminaAslProvider)(asl.codice);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ASL eliminata')),
      );
    }
  }

  void _mostraDialogAggiungi() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aggiungi ASL'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _descrizioneCtrl,
            decoration: const InputDecoration(labelText: 'Descrizione'),
            validator: (v) => v?.isEmpty ?? true ? 'Campo obbligatorio' : null,
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
              _salvaAsl();
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aslAsync = ref.watch(aslProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione ASL'),
        centerTitle: true,
      ),
      body: aslAsync.when(
        data: (aslList) {
          if (aslList.isEmpty) {
            return const Center(child: Text('Nessuna ASL presente'));
          }

          return ListView.separated(
            itemCount: aslList.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final asl = aslList[index];
              return ListTile(
                title: Text(asl.descrizione),
                subtitle: Text('Codice: ${asl.codice}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _eliminaAsl(asl),
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