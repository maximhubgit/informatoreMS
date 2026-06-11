import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:informatoreMS/core/models/calendario_appuntamento.dart';

class AppuntamentoCard extends StatelessWidget {
  final CalendarioAppuntamento appuntamento;
  final String? nomeMedico;
  final String? specializzazione;
  final VoidCallback onMarkDone;
  final VoidCallback onMarkCancelled;
  final VoidCallback onMove;
  final VoidCallback? onDelete;
  final VoidCallback? onConfirm;
  final VoidCallback? onTap;

  const AppuntamentoCard({
    super.key,
    required this.appuntamento,
    this.nomeMedico,
    this.specializzazione,
    required this.onMarkDone,
    required this.onMarkCancelled,
    required this.onMove,
    this.onDelete,
    this.onConfirm,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isConcluso = appuntamento.stato.isConcluso;
    final mostraConferma = appuntamento.stato == StatoCalendario.proposto && onConfirm != null;
    final mostraElimina = onDelete != null && !isConcluso;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        enabled: !isConcluso,
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: mostraConferma && mostraElimina
              ? 1.0
              : mostraConferma || mostraElimina
                  ? 0.9
                  : 0.65,
          children: [
            if (mostraConferma)
              CustomSlidableAction(
                onPressed: (_) => onConfirm!(),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                borderRadius: BorderRadius.horizontal(
                  left: const Radius.circular(16),
                  right: mostraElimina ? const Radius.circular(0) : const Radius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle),
                    SizedBox(height: 4),
                    Text('Conferma', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            if (mostraElimina && !mostraConferma)
              CustomSlidableAction(
                onPressed: (_) => onDelete!(),
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete),
                    SizedBox(height: 4),
                    Text('Elimina', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            if (mostraElimina && mostraConferma)
              CustomSlidableAction(
                onPressed: (_) => onDelete!(),
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete),
                    SizedBox(height: 4),
                    Text('Elimina', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            CustomSlidableAction(
              onPressed: (_) => onMarkDone(),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              borderRadius: mostraConferma || mostraElimina
                  ? BorderRadius.zero
                  : const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check),
                  SizedBox(height: 4),
                  Text('Fatto', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) => onMarkCancelled(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel),
                  SizedBox(height: 4),
                  Text('Annullato', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) => onMove(),
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(16),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_calendar),
                  SizedBox(height: 4),
                  Text('Sposta', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isConcluso
                  ? Colors.grey.shade100
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isConcluso
                    ? Colors.grey.shade300
                    : appuntamento.stato.colore,
              ),
              boxShadow: !isConcluso
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Orario
                Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isConcluso
                        ? Colors.grey.shade200
                        : appuntamento.stato.colore.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        appuntamento.oraFormattata,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isConcluso
                              ? Colors.grey.shade600
                              : appuntamento.stato.colore,
                        ),
                      ),
                      Text(
                        appuntamento.stato.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: isConcluso
                              ? Colors.grey.shade500
                              : appuntamento.stato.colore.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Info medico
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomeMedico ?? 'Medico ${appuntamento.medicoId}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isConcluso ? Colors.grey.shade500 : null,
                              decoration: isConcluso
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specializzazione ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Stato badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: appuntamento.stato.colore.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _statoIcon(appuntamento.stato),
                    size: 18,
                    color: appuntamento.stato.colore,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _statoIcon(StatoCalendario stato) {
    return switch (stato) {
      StatoCalendario.proposto => Icons.event_note,
      StatoCalendario.confermato => Icons.event_available,
      StatoCalendario.concordato => Icons.event_available,
      StatoCalendario.fatto => Icons.check_circle,
      StatoCalendario.annullato => Icons.cancel,
    };
  }
}