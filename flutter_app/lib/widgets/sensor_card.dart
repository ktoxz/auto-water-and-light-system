import 'package:flutter/material.dart';
import '../responsive_utils.dart';

class SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final double progress; // 0.0 → 1.0
  final bool isWarning;

  const SensorCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.progress,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isWarning ? Colors.red : color;
    final borderRadius = ResponsiveUtils.getBorderRadius(context, size: 'large');

    return Card(
      elevation: isWarning ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: isWarning
            ? const BorderSide(color: Colors.red, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, type: 'lg')),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: effectiveColor,
                  size: ResponsiveUtils.getIconSize(context, purpose: 'normal'),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, type: 'md')),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: ResponsiveUtils.getSmallSize(context),
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isWarning)
                  Icon(Icons.warning_amber,
                      color: Colors.red,
                      size: ResponsiveUtils.getIconSize(context, purpose: 'small')),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: effectiveColor,
                        fontSize: ResponsiveUtils.getTitleSize(context),
                      ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, type: 'xs')),
                Padding(
                  padding: EdgeInsets.only(bottom: ResponsiveUtils.getSpacing(context, type: 'xs')),
                  child: Text(
                    unit,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: effectiveColor,
                          fontSize: ResponsiveUtils.getSmallSize(context),
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'md')),
            ClipRRect(
              borderRadius: BorderRadius.circular(ResponsiveUtils.getSpacing(context, type: 'xs')),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: effectiveColor.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
