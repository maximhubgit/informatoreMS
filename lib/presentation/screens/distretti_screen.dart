import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/distretto.dart';
import 'package:informatoreMS/presentation/providers/distretto_provider.dart';
import 'package:informatoreMS/presentation/providers/asl_provider.dart';

class DistrettiScreen extends ConsumerStatefulWidget {
  const DistrettiScreen({super.key});

  @override
  ConsumerState<DistrettiScreen> createState() => _DistrettiScreenState();
}

class _DistrettiScreenState extends ConsumerState<DistrettiScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descrizioneCtrl;
  late final TextEditingController _nrDistrettoCtrl;
  int? _selectedCodiceAsl;

  @override
  void initState() {
    super.initState();
    _descrizioneCtrl = TextEditingController();
    _nrDistrettoCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _descrizioneCtrl.dispose();
    _nrDistrettoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvaDistretto() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCodiceAsl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un\'ASL')),
      );
      return;
    }

    final distrettiList = ref.read(distrettoProvider).valueOrNull ?? [];
    final nuovoCodice = distrettiList.isEmpty
        ? 1
        : (distrettiList.map((d) => d.codice).reduce((a, b) => a > b ? a : b) + 1);

    final nrDistretto = int.parse(_nrDistrettoCtrl.text);
    final distretto = Distretto(
      codice: nuovoCodice,
      nrDistretto: nrDistretto,
      descrizione: _descrizioneCtrl.text,
      codiceAsl: _selectedCodiceAsl!,
    );

    await ref.read(salvaDistrettoProvider)(distretto);
    _descrizioneCtrl.clear();
    _nrDistrettoCtrl.clear();
    setState(() => _selectedCodiceAsl = null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Distretto salvato')),
      );
    }
  }

  Future<void> _eliminaDistretto(Distretto distretto) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confermi l\'eliminazione?'),
        content: Text('Il distretto "${distretto.descrizione}" verrà rimosso.'),
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
      await ref.read(eliminaDistrettoProvider)(distretto.codice);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Distretto eliminato')),
      );
    }
  }

  void _mostraDialogAggiungi() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Aggiungi Distretto'),
          content: Consumer(
            builder: (context, ref, _) {
              final aslAsync = ref.watch(aslProvider);

              return Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nrDistrettoCtrl,
                      decoration: const InputDecoration(labelText: 'Nr Distretto'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty ?? true ? 'Campo obbligatorio' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descrizioneCtrl,
                      decoration: const InputDecoration(labelText: 'Descrizione'),
                      validator: (v) => v?.isEmpty ?? true ? 'Campo obbligatorio' : null,
                    ),
                    const SizedBox(height: 16),
                    aslAsync.when(
                      data: (aslList) {
                        if (aslList.isEmpty) {
                          return const Text(
                            'Nessuna ASL disponibile. Aggiungine una prima.',
                            style: TextStyle(color: Colors.red),
                          );
                        }

                        return DropdownButtonFormField<int>(
                          value: _selectedCodiceAsl,
                          decoration: const InputDecoration(labelText: 'ASL'),
                          items: aslList.map((asl) => DropdownMenuItem(
                                value: asl.codice,
                                child: Text(asl.descrizione),
                              )).toList(),
                          onChanged: (v) => setState(() => _selectedCodiceAsl = v),
                          validator: (v) => v == null ? 'Seleziona un\'ASL' : null,
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Errore nel caricamento ASL'),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _nrDistrettoCtrl.clear();
                _descrizioneCtrl.clear();
                setState(() => _selectedCodiceAsl = null);
              },
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _salvaDistretto();
              },
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final distrettiAsync = ref.watch(distrettoProvider);
    final aslAsync = ref.watch(aslProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Distretti'),
        centerTitle: true,
      ),
      body: distrettiAsync.when(
        data: (distrettiList) {
          if (distrettiList.isEmpty) {
            return const Center(child: Text('Nessun distretto presente'));
          }

          return ListView.separated(
            itemCount: distrettiList.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final distretto = distrettiList[index];

              String? aslDescrizione;
              if (aslAsync.hasValue) {
                aslDescrizione = aslAsync.valueOrNull
                    ?.firstWhere((a) => a.codice == distretto.codiceAsl)
                    .descrizione;
              }

              return ListTile(
                title: Text(distretto.campoDescrittivo),
                subtitle: Text('ASL: ${aslDescrizione ?? "Codice ${distretto.codiceAsl}"}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _eliminaDistretto(distretto),
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