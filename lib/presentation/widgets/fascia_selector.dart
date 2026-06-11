import 'package:flutter/material.dart';
import 'package:informatoreMS/core/models/fascia_oraria.dart';
import 'package:informatoreMS/core/extensions/date_time_extension.dart';

class FasciaSelector extends StatelessWidget {
  final List<FasciaOraria> fasce;
  final int? selectedMinutes;
  final ValueChanged<int> onSelect;

  const FasciaSelector({
    super.key,
    required this.fasce,
    this.selectedMinutes,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (fasce.isEmpty) {
      return const Text('Nessuna fascia oraria disponibile');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: fasce.map((fascia) {
        return ActionChip(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${fascia.inizio.formatTime()} - ${fascia.fine.formatTime()}',
                style: TextStyle(
                  color: selectedMinutes == fascia.minutiInizio
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              if (!fascia.tuttiIGiorni)
                Text(
                  fascia.giorniSettimana!.map((g) => g.label.substring(0, 2)).join(', '),
                  style: TextStyle(
                    fontSize: 10,
                    color: selectedMinutes == fascia.minutiInizio
                        ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
          backgroundColor: selectedMinutes == fascia.minutiInizio
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          onPressed: () => onSelect(fascia.minutiInizio),
        );
      }).toList(),
    );
  }
}