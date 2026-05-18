import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../responsive_utils.dart';

class AlertItem extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onDismiss;
  final Function(int)? onNavigate;

  const AlertItem({
    super.key,
    required this.alert,
    this.onDismiss,
    this.onNavigate,
  });

  Color get _color {
    switch (alert.type) {
      case AlertType.critical: return Colors.red;
      case AlertType.warning:  return Colors.orange;
      case AlertType.info:     return Colors.blue;
    }
  }

  IconData get _icon {
    switch (alert.type) {
      case AlertType.critical: return Icons.error;
      case AlertType.warning:  return Icons.warning_amber;
      case AlertType.info:     return Icons.info;
    }
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(alert.timestamp);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  int? get _targetScreen {
    final sensorAlerts = [
      'temp_high', 'soil_dry', 'soil_wet',
      'humidity_low', 'humidity_high',
    ];
    final controlAlerts = ['pump_safety', 'critical'];

    if (sensorAlerts.any((t) => alert.message.contains(t) ||
        alert.title.toLowerCase().contains('nhiệt') ||
        alert.title.toLowerCase().contains('đất') ||
        alert.title.toLowerCase().contains('độ ẩm'))) {
      return 0;
    }
    if (controlAlerts.any((t) => alert.message.contains(t) ||
        alert.title.toLowerCase().contains('bơm'))) {
      return 1;
    }
    return null;
  }

  String get _actionLabel {
    final screen = _targetScreen;
    if (screen == 0) return 'Xem Dashboard';
    if (screen == 1) return 'Điều khiển';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveUtils.getScale(context);
    return Dismissible(
      key: Key(alert.id.isEmpty ? alert.message : alert.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: ResponsiveUtils.getSpacing(context, type: 'lg')),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Colors.red,
          size: scale * 24,
        ),
      ),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _color.withOpacity(0.4), width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _targetScreen != null
              ? () {
            onDismiss?.call();
            onNavigate?.call(_targetScreen!);
          }
              : null,
          child: Padding(
            padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, type: 'md')),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, type: 'sm')),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _icon,
                    color: _color,
                    size: scale * 18,
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, type: 'md')),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: ResponsiveUtils.getBodySize(context),
                              ),
                            ),
                          ),
                          if (_targetScreen != null)
                            Icon(
                              Icons.arrow_forward_ios,
                              size: scale * 10,
                              color: Colors.grey[400],
                            ),
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'xs')),
                      Text(
                        alert.message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: ResponsiveUtils.getSmallSize(context),
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'xs')),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _timeAgo,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[400],
                              fontSize: (10 * scale).clamp(9, 12),
                            ),
                          ),
                          if (_actionLabel.isNotEmpty)
                            Text(
                              _actionLabel,
                              style: TextStyle(
                                fontSize: (10 * scale).clamp(9, 12),
                                color: _color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
