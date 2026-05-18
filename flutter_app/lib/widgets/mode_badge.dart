import 'package:flutter/material.dart';
import '../responsive_utils.dart';

class ModeBadge extends StatelessWidget {
  final String mode;
  final bool isActive;

  const ModeBadge({super.key, required this.mode, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getSpacing(context, type: 'md'), horizontal: ResponsiveUtils.getSpacing(context, type: 'lg')),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : Colors.grey.withOpacity(0.4),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Center(
        child: Text(
          mode,
          style: TextStyle(
            color: isActive ? color : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
