import 'package:flutter/material.dart';
import 'package:informatoreMS/core/models/zona.dart';

class ZonaChip extends StatelessWidget {
  final Zona zona;
  final bool isSelected;
  final VoidCallback onTap;

  const ZonaChip({
    super.key,
    required this.zona,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? zona.colore : zona.colore.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            zona.nome,
            style: TextStyle(
              color: isSelected ? Colors.white : zona.colore,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
