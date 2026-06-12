import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';
import 'package:informatoreMS/core/models/distretto.dart';
import 'package:informatoreMS/core/models/fascia_oraria.dart';
import 'package:informatoreMS/core/models/medico.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';
import 'package:informatoreMS/presentation/providers/zone_provider.dart';
import 'package:informatoreMS/presentation/providers/calendario_provider.dart';
import 'package:informatoreMS/presentation/providers/medici_provider.dart';
import 'package:informatoreMS/presentation/providers/specializzazione_provider.dart';
import 'package:informatoreMS/presentation/providers/distretto_provider.dart';
import 'package:informatoreMS/presentation/screens/specializzazioni_screen.dart';
import 'package:uuid/uuid.dart';

class MedicoEditScreen extends ConsumerStatefulWidget {
  final Medico? medico;

  const MedicoEditScreen({super.key, this.medico});

  @override
  ConsumerState<MedicoEditScreen> createState() => _MedicoEditScreenState();
}

class _MedicoEditScreenState extends ConsumerState<MedicoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _periodicitaCtrl;
  late final TextEditingController _annotazioniCtrl;
  late final TextEditingController _prodottiCtrl;
  late String? _selectedSpecializzazioneId;
  late List<FasciaOraria> _fasce;

  @override
  void initState() {
    super.initState();
    final m = widget.medico;
    _nomeCtrl = TextEditingController(text: m?.nome ?? '');
    _periodicitaCtrl = TextEditingController(text: m?.periodicitaGiorni.toString() ?? '30');
    _annotazioniCtrl = TextEditingController(text: m?.annotazioni ?? '');
    _prodottiCtrl = TextEditingController(text: m?.prodotti ?? '');
    _selectedSpecializzazioneId = m?.specializzazioneId;
    _fasce = []; // Verranno caricate nel build
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _periodicitaCtrl.dispose();
    _annotazioniCtrl.dispose();
    _prodottiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specializzazioniAsync = ref.watch(specializzazioneProvider);
    final distrettiAsync = ref.watch(distrettoProvider);

    // Carica le fasce orarie del medico se in modifica
    final medicoId = widget.medico?.id ?? '';
    final fasceAsync = medicoId.isNotEmpty
        ? ref.watch(fasceOrarieMedicoProvider(medicoId))
        : const AsyncData(<FasciaOraria>[]);

    // Aggiorna _fasce quando i dati arrivano (con post frame callback per evitare setState durante build)
    if (fasceAsync.hasValue && _fasce.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _fasce = List<FasciaOraria>.from(fasceAsync.value!);
          });
        }
      });
    }

    // Debug: log errori
    if (fasceAsync.hasError) {
      print('ERRORE fasceOrarieMedicoProvider: ${fasceAsync.error}');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medico == null ? 'Nuovo Medico' : 'Modifica Medico'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (v) => v?.isEmpty ?? true ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 16),
            specializzazioniAsync.when(
              data: (specializzazioni) {
                // Verifica che il valore selezionato esista nella lista
                final validValue = _selectedSpecializzazioneId != null &&
                    specializzazioni.any((s) => s.id == _selectedSpecializzazioneId)
                    ? _selectedSpecializzazioneId
                    : null;

                if (specializzazioni.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nessuna specializzazione disponibile',
                        style: TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SpecializzazioniScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Aggiungi specializzazioni'),
                      ),
                    ],
                  );
                }

                return DropdownButtonFormField<String>(
                  value: validValue,
                  decoration: const InputDecoration(labelText: 'Specializzazione'),
                  items: specializzazioni.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Row(
                          children: [
                            Icon(s.icona, size: 18, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(s.nome),
                          ],
                        ),
                      )).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedSpecializzazioneId = v;
                      });
                    }
                  },
                  validator: (v) => v == null ? 'Seleziona una specializzazione' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _periodicitaCtrl,
              decoration: const InputDecoration(labelText: 'Periodicità (giorni)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _annotazioniCtrl,
              decoration: const InputDecoration(labelText: 'Annotazioni'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _prodottiCtrl,
              decoration: const InputDecoration(labelText: 'Prodotti'),
            ),
            const SizedBox(height: 16),
            _buildFasceSection(distrettiAsync),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _salva,
              child: Text(widget.medico == null ? 'Aggiungi Medico' : 'Salva Modifiche'),
            ),
            if (widget.medico != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _elimina,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Elimina Medico'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFasceSection(AsyncValue<List<Distretto>> distrettiAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fasce Orarie',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Le fasce orarie sono obbligatorie e contengono tutti i dettagli (distretto, zona, struttura, indirizzo, durata).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
        ),
        const SizedBox(height: 8),
        if (_fasce.isEmpty)
          Text(
            'Nessuna fascia oraria aggiunta',
            style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        ..._fasce.asMap().entries.map((entry) {
          final index = entry.key;
          final fascia = entry.value;

          // Troviamo il distretto associato a questa fascia
          String? distrettoLabel;
          String? zonaLabel;
          if (distrettiAsync.hasValue) {
            try {
              final d = distrettiAsync.valueOrNull!
                  .firstWhere((d) => d.codice == fascia.distrettoId);
              distrettoLabel = d.campoDescrittivo;
            } catch (_) {
              distrettoLabel = 'Dist. ${fascia.distrettoId}';
            }
          }

          // Troviamo la zona associata a questa fascia
          final zoneAsync = ref.watch(zoneProvider);
          if (zoneAsync.hasValue) {
            try {
              final z = zoneAsync.valueOrNull!
                  .firstWhere((z) => z.id == fascia.zonaId);
              zonaLabel = z.nome;
            } catch (_) {
              zonaLabel = null;
            }
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Text(
                '${fascia.inizio.formatTime()} - ${fascia.fine.formatTime()}${fascia.nr == 0 ? ' (principale)' : ' (nr=${fascia.nr})'}',
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fascia.tuttiIGiorni
                        ? 'Tutti i giorni'
                        : fascia.giorniSettimana!
                            .map((g) => g.label)
                            .join(', '),
                  ),
                  if (distrettoLabel != null || zonaLabel != null)
                    Text(
                      '${distrettoLabel != null ? 'Distretto: $distrettoLabel' : ''}${distrettoLabel != null && zonaLabel != null ? ' • ' : ''}${zonaLabel != null ? 'Zona: $zonaLabel' : ''}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _modificaFascia(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final fasciaId = fascia.id;
                      if (fasciaId != null) {
                        await ref.read(eliminaFasciaOrariaProvider)(fasciaId);
                      }
                      if (mounted) {
                        setState(() => _fasce.removeAt(index));
                      }
                    },
                  ),
                ],
              ),
              children: [
                if (fascia.struttura != null || fascia.indirizzo != null || fascia.tempoVisitaMinuti != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fascia.struttura != null)
                          Text('Struttura: ${fascia.struttura}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        if (fascia.indirizzo != null)
                          Text('Indirizzo: ${fascia.indirizzo}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        if (fascia.tempoVisitaMinuti != null)
                          Text('Durata: ${fascia.tempoVisitaMinuti} min', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: _aggiungiFascia,
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi Fascia'),
        ),
      ],
    );
  }

  Future<void> _aggiungiFascia() async {
    // Determina se usare i valori della fascia principale (nr=0)
    // Usa try-catch per gestire il caso in cui firstWhere non trova elementi
    FasciaOraria? fasciaPrincipale;
    try {
      fasciaPrincipale = _fasce.firstWhere((f) => f.nr == 0);
    } catch (_) {
      fasciaPrincipale = null;
    }
    final usaNaDettagliPrincipale = fasciaPrincipale != null && _fasce.isNotEmpty;

    // Mostra dialog per scegliere tra "richiama" o "nuovi dettagli"
    final Map<String, dynamic>? dettagliFascia;
    if (usaNaDettagliPrincipale) {
      final scelta = await showDialog<bool>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Dettagli fascia'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Richiama dati fascia principale'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Imposta dettagli specifici'),
            ),
          ],
        ),
      );

      if (scelta == true) {
        // Usa i valori della fascia principale
        dettagliFascia = {
          'distrettoId': fasciaPrincipale!.distrettoId,
          'zonaId': fasciaPrincipale.zonaId,
          'struttura': fasciaPrincipale.struttura,
          'indirizzo': fasciaPrincipale.indirizzo,
          'tempoVisitaMinuti': fasciaPrincipale.tempoVisitaMinuti,
        };
      } else if (scelta == false) {
        // Mostra dialog per nuovi dettagli
        dettagliFascia = await _selezionaDettagliFasciaCompleta();
      } else {
        return; // Annullato
      }
    } else {
      // Prima fascia - richiedi sempre tutti i dettagli
      dettagliFascia = await _selezionaDettagoCompletaPrimaFascia();
    }

    if (dettagliFascia == null || !mounted) return;

    // Usa i giorni selezionati nel dialog (se presenti) o chiedi all'utente
    List<GiornoSettimana>? giorniSelezionati = dettagliFascia['giorniSettimana'] as List<GiornoSettimana>?;

    // Se non ci sono giorni nel dialog, chiedi ora
    if (dettagliFascia['giorniSettimana'] == null) {
      final sceltaGiorni = await showDialog<bool>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Selezione giorni'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tutti i giorni della settimana'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Giorni specifici della settimana'),
            ),
          ],
        ),
      );

      if (sceltaGiorni == false) {
        giorniSelezionati = await _selezionaGiorni();
        if (giorniSelezionati == null || giorniSelezionati.isEmpty) return;
      }
    }

    final timeInizio = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (timeInizio == null || !mounted) return;

    final timeFine = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (timeFine == null || !mounted) return;

    // Calcola il nr progressivo: usa 0 se è la prima fascia, altrimenti max+1
    final nr = _fasce.isEmpty
        ? 0
        : (_fasce.map((f) => f.nr).reduce((a, b) => a > b ? a : b) + 1);

    if (mounted) {
      setState(() {
        _fasce.add(FasciaOraria(
          id: const Uuid().v4(),
          idMedico: widget.medico?.id ?? '',
          nr: nr,
          minutiInizio: timeInizio.hour * 60 + timeInizio.minute,
          minutiFine: timeFine.hour * 60 + timeFine.minute,
          giorniSettimana: giorniSelezionati,
          distrettoId: dettagliFascia!['distrettoId'] as int,
          zonaId: dettagliFascia['zonaId'] as String,
          struttura: dettagliFascia['struttura'] as String?,
          indirizzo: dettagliFascia['indirizzo'] as String?,
          tempoVisitaMinuti: dettagliFascia['tempoVisitaMinuti'] as int?,
        ));
      });
    }
  }

  /// Mostra un dialog per selezionare i giorni della settimana.
  Future<List<GiornoSettimana>?> _selezionaGiorni() async {
    final result = await showDialog<List<GiornoSettimana>?>(
      context: context,
      builder: (context) {
        final tempSelezionati = <GiornoSettimana>[];
        return AlertDialog(
          title: const Text('Seleziona i giorni'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Wrap(
                spacing: 8,
                children: GiornoSettimana.values.map((giorno) {
                  final isSelected = tempSelezionati.contains(giorno);
                  return FilterChip(
                    label: Text(giorno.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      setDialogState(() {
                        if (selected) {
                          tempSelezionati.add(giorno);
                        } else {
                          tempSelezionati.remove(giorno);
                        }
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, tempSelezionati),
              child: const Text('Conferma'),
            ),
          ],
        );
      },
    );

    return result;
  }

  /// Mostra un dialog per selezionare tutti i dettagli della fascia oraria (per nuove fasce).
  Future<Map<String, dynamic>?> _selezionaDettagliFasciaCompleta() async {
    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        int? selectedDistretto;
        String? selectedZonaId;
        String? struttura;
        String? indirizzo;
        int? tempoVisitaMinuti;

        return AlertDialog(
          title: const Text('Dettagli fascia'),
          content: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                final distrettiAsync = ref.watch(distrettoProvider);
                final zoneAsync = ref.watch(zoneProvider);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Distretto
                    distrettiAsync.when(
                      data: (distretti) => DropdownButtonFormField<int>(
                        value: selectedDistretto,
                        decoration: const InputDecoration(labelText: 'Distretto'),
                        items: distretti.map((d) => DropdownMenuItem(
                              value: d.codice,
                              child: Text(d.campoDescrittivo),
                            )).toList(),
                        onChanged: (v) => selectedDistretto = v,
                        validator: (v) => v == null ? 'Seleziona un distretto' : null,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Errore caricamento distretti'),
                    ),
                    const SizedBox(height: 12),
                    // Zona
                    zoneAsync.when(
                      data: (zone) => DropdownButtonFormField<String>(
                        value: selectedZonaId,
                        decoration: const InputDecoration(labelText: 'Zona'),
                        items: zone.map((z) => DropdownMenuItem(
                              value: z.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: z.colore,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(z.nome),
                                ],
                              ),
                            )).toList(),
                        onChanged: (v) => selectedZonaId = v,
                        validator: (v) => v == null ? 'Seleziona una zona' : null,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Errore caricamento zone'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Struttura'),
                      onChanged: (v) => struttura = v,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Indirizzo'),
                      onChanged: (v) => indirizzo = v,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Durata visita (min)'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => tempoVisitaMinuti = int.tryParse(v),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Annulla')),
            TextButton(
              onPressed: () {
                if (selectedDistretto != null && selectedZonaId != null) {
                  Navigator.pop(context, {
                    'distrettoId': selectedDistretto,
                    'zonaId': selectedZonaId,
                    'struttura': struttura,
                    'indirizzo': indirizzo,
                    'tempoVisitaMinuti': tempoVisitaMinuti,
                  });
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Mostra un dialog per selezionare tutti i dettagli della prima fascia.
  Future<Map<String, dynamic>?> _selezionaDettagoCompletaPrimaFascia() async {
    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        int? selectedDistretto;
        String? selectedZonaId;
        String? struttura;
        String? indirizzo;
        int? tempoVisitaMinuti;
        List<GiornoSettimana> giorniSelezionati = [];

        return AlertDialog(
          title: const Text('Dettagli fascia principale'),
          content: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                final distrettiAsync = ref.watch(distrettoProvider);
                final zoneAsync = ref.watch(zoneProvider);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    distrettiAsync.when(
                      data: (distretti) => DropdownButtonFormField<int>(
                        value: selectedDistretto,
                        decoration: const InputDecoration(labelText: 'Distretto'),
                        items: distretti.map((d) => DropdownMenuItem(
                              value: d.codice,
                              child: Text(d.campoDescrittivo),
                            )).toList(),
                        onChanged: (v) => selectedDistretto = v,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Errore caricamento distretti'),
                    ),
                    const SizedBox(height: 12),
                    zoneAsync.when(
                      data: (zone) => DropdownButtonFormField<String>(
                        value: selectedZonaId,
                        decoration: const InputDecoration(labelText: 'Zona'),
                        items: zone.map((z) => DropdownMenuItem(
                              value: z.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: z.colore,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(z.nome),
                                ],
                              ),
                            )).toList(),
                        onChanged: (v) => selectedZonaId = v,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Errore caricamento zone'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Struttura'),
                      onChanged: (v) => struttura = v,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Indirizzo'),
                      onChanged: (v) => indirizzo = v,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Durata visita (min)',
                        hintText: '30',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => tempoVisitaMinuti = int.tryParse(v),
                    ),
                    const SizedBox(height: 16),
                    const Text('Giorni della settimana:', style: TextStyle(fontWeight: FontWeight.bold)),
                    StatefulBuilder(
                      builder: (context, setDialogState) {
                        return Wrap(
                          spacing: 8,
                          children: GiornoSettimana.values.map((giorno) {
                            final isSelected = giorniSelezionati.contains(giorno);
                            return FilterChip(
                              label: Text(giorno.label.substring(0, 2)),
                              selected: isSelected,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    giorniSelezionati.add(giorno);
                                  } else {
                                    giorniSelezionati.remove(giorno);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Annulla')),
            TextButton(
              onPressed: () {
                if (selectedDistretto != null && selectedZonaId != null) {
                  Navigator.pop(context, {
                    'distrettoId': selectedDistretto,
                    'zonaId': selectedZonaId,
                    'struttura': struttura,
                    'indirizzo': indirizzo,
                    'tempoVisitaMinuti': tempoVisitaMinuti,
                    'giorniSettimana': giorniSelezionati.isEmpty ? null : giorniSelezionati,
                  });
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Modifica una fascia esistente.
  Future<void> _modificaFascia(int index) async {
    final fascia = _fasce[index];
    // Trova la fascia principale se esiste (per il pulsante "richiama")
    FasciaOraria? fasciaPrincipale;
    try {
      fasciaPrincipale = _fasce.firstWhere((f) => f.nr == 0);
    } catch (_) {
      fasciaPrincipale = null;
    }

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        int? selectedDistretto = fascia.distrettoId;
        String? selectedZonaId = fascia.zonaId;
        String? struttura = fascia.struttura;
        String? indirizzo = fascia.indirizzo;
        int? tempoVisitaMinuti = fascia.tempoVisitaMinuti;

        // Giorni della settimana
        final giorniSelezionati = List<GiornoSettimana>.from(fascia.giorniSettimana ?? GiornoSettimana.values);

        return AlertDialog(
          title: const Text('Modifica fascia'),
          content: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                final distrettiAsync = ref.watch(distrettoProvider);
                final zoneAsync = ref.watch(zoneProvider);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    distrettiAsync.when(
                      data: (distretti) => DropdownButtonFormField<int>(
                        value: selectedDistretto,
                        decoration: const InputDecoration(labelText: 'Distretto'),
                        items: distretti.map((d) => DropdownMenuItem(
                              value: d.codice,
                              child: Text(d.campoDescrittivo),
                            )).toList(),
                        onChanged: (v) => selectedDistretto = v,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Errore'),
                    ),
                    const SizedBox(height: 12),
                    zoneAsync.when(
                      data: (zone) => DropdownButtonFormField<String>(
                        value: selectedZonaId,
                        decoration: const InputDecoration(labelText: 'Zona'),
                        items: zone.map((z) => DropdownMenuItem(
                              value: z.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: z.colore,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(z.nome),
                                ],
                              ),
                            )).toList(),
                        onChanged: (v) => selectedZonaId = v,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Errore'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: struttura ?? '',
                      decoration: const InputDecoration(labelText: 'Struttura'),
                      onChanged: (v) => struttura = v.isNotEmpty ? v : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: indirizzo ?? '',
                      decoration: const InputDecoration(labelText: 'Indirizzo'),
                      onChanged: (v) => indirizzo = v.isNotEmpty ? v : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: tempoVisitaMinuti?.toString() ?? '',
                      decoration: const InputDecoration(labelText: 'Durata visita (min)'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => tempoVisitaMinuti = int.tryParse(v),
                    ),
                    const SizedBox(height: 16),
                    const Text('Giorni della settimana:'),
                    StatefulBuilder(
                      builder: (context, setDialogState) {
                        return Wrap(
                          spacing: 8,
                          children: GiornoSettimana.values.map((giorno) {
                            final isSelected = giorniSelezionati.contains(giorno);
                            return FilterChip(
                              label: Text(giorno.label.substring(0, 2)),
                              selected: isSelected,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    giorniSelezionati.add(giorno);
                                  } else {
                                    giorniSelezionati.remove(giorno);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Annulla')),
            TextButton(
              onPressed: () {
                if (selectedDistretto != null && selectedZonaId != null) {
                  Navigator.pop(context, {
                    'distrettoId': selectedDistretto,
                    'zonaId': selectedZonaId,
                    'struttura': struttura,
                    'indirizzo': indirizzo,
                    'tempoVisitaMinuti': tempoVisitaMinuti,
                    'giorniSettimana': giorniSelezionati.isEmpty ? null : giorniSelezionati,
                  });
                }
              },
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _fasce[index] = fascia.copyWith(
          distrettoId: result['distrettoId'] as int,
          zonaId: result['zonaId'] as String,
          struttura: result['struttura'] as String?,
          indirizzo: result['indirizzo'] as String?,
          tempoVisitaMinuti: result['tempoVisitaMinuti'] as int?,
          giorniSettimana: result['giorniSettimana'] as List<GiornoSettimana>?,
        );
      });
    }
  }

  void _salva() async {
    if (!_formKey.currentState!.validate()) return;

    final medicoId = widget.medico?.id ?? const Uuid().v4();

    // Salviamo il medico (solo nome, specializzazione, periodicità, annotazioni, prodotti)
    final nuovoMedico = (widget.medico ?? Medico(
      id: medicoId,
      nome: '',
      specializzazioneId: '',
      periodicitaGiorni: 30,
    )).copyWith(
      nome: _nomeCtrl.text,
      specializzazioneId: _selectedSpecializzazioneId!,
      periodicitaGiorni: int.parse(_periodicitaCtrl.text),
      annotazioni: _annotazioniCtrl.text.isNotEmpty ? _annotazioniCtrl.text : null,
      prodotti: _prodottiCtrl.text.isNotEmpty ? _prodottiCtrl.text : null,
    );

    await ref.read(salvaMedicoProvider)(nuovoMedico);

    // Salviamo le fasce orarie nella collection separata
    for (final fascia in _fasce) {
      final fasciaConId = (fascia.id == null || fascia.id!.isEmpty)
          ? fascia.copyWith(id: const Uuid().v4(), idMedico: medicoId)
          : fascia.copyWith(idMedico: medicoId);
      await ref.read(salvaFasciaOrariaProvider)(fasciaConId);
    }

    // Invalida il provider specifico del medico per ricaricare le fasce
    ref.invalidate(fasceOrarieMedicoProvider(medicoId));
    _completaSalvataggio();
  }

  void _completaSalvataggio() {
    ref.invalidate(mediciProvider);
    ref.invalidate(calendarioProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvataggio completato')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _elimina() async {
    if (widget.medico == null) return;

    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confermi l\'eliminazione?'),
        content: Text('Il medico ${widget.medico!.nomeCompleto} verrà rimosso.'),
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
      await ref.read(medicoRepositoryProvider).delete(widget.medico!.id);
      // Elimina anche le fasce orarie associate
      await ref.read(fasciaOrariaRepositoryProvider).deleteByMedicoId(widget.medico!.id);
      ref.invalidate(mediciProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medico eliminato')),
      );
      Navigator.of(context).pop();
    }
  }
}