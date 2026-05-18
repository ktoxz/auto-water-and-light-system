import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alert_model.dart';
import '../services/mqtt_service.dart';
import '../widgets/alert_item.dart';
import '../responsive_utils.dart';

class AlertsScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const AlertsScreen({super.key, this.onNavigate});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final List<AlertModel> _alerts = [];
  int _unreadCount = 0;
  late StreamSubscription _alertSub;

  @override
  void initState() {
    super.initState();
    final mqtt = context.read<MqttService>();
    _alerts.addAll(mqtt.alertHistory);

    _alertSub = mqtt.alertStream.listen((alert) {
      if (mounted) {
        setState(() {
          _alerts.insert(0, alert);
          _unreadCount++;
        });
      }
    });
  }

  @override
  void dispose() {
    _alertSub.cancel();
    super.dispose();
  }

  void _markAllRead() => setState(() => _unreadCount = 0);

  void _clearAll() {
    context.read<MqttService>().clearAlertHistory();
    setState(() {
      _alerts.clear();
      _unreadCount = 0;
    });
  }

  int get _criticalCount =>
      _alerts.where((a) => a.type == AlertType.critical).length;
  int get _warningCount =>
      _alerts.where((a) => a.type == AlertType.warning).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cảnh Báo'),
            if (_unreadCount > 0) ...[
              SizedBox(width: ResponsiveUtils.getSpacing(context, type: 'md')),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getSpacing(context, type: 'md'),
                  vertical: ResponsiveUtils.getSpacing(context, type: 'xs'),
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getBorderRadius(context, size: 'large')),
                ),
                child: Text(
                  '$_unreadCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveUtils.getSmallSize(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_alerts.isNotEmpty)
            TextButton(onPressed: _markAllRead, child: const Text('Đọc tất cả')),
        ],
      ),
      body: _alerts.isEmpty
           ? Center(
         child: SingleChildScrollView(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(Icons.check_circle_outline,
                   size: ResponsiveUtils.getIconSize(context, purpose: 'large'),
                   color: Colors.green.withOpacity(0.5)),
               SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'lg')),
               Text('Không có cảnh báo',
                   style: Theme.of(context).textTheme.titleLarge?.copyWith(
                     fontSize: ResponsiveUtils.getTitleSize(context),
                   )),
               SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'md')),
               Text('Hệ thống hoạt động bình thường',
                   style: Theme.of(context)
                       .textTheme
                       .bodyMedium
                       ?.copyWith(
                         color: Colors.grey,
                         fontSize: ResponsiveUtils.getBodySize(context),
                       )),
               SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'md')),
               Text('Đang lắng nghe home/alerts...',
                   style: Theme.of(context)
                       .textTheme
                       .bodySmall
                       ?.copyWith(
                         color: Colors.grey[400],
                         fontSize: ResponsiveUtils.getSmallSize(context),
                       )),
             ],
           ),
         ),
       )
           : Column(
         children: [
           Padding(
             padding: EdgeInsets.symmetric(
               horizontal: ResponsiveUtils.getSpacing(context, type: 'md'),
               vertical: ResponsiveUtils.getSpacing(context, type: 'md'),
             ),
             child: SingleChildScrollView(
               scrollDirection: Axis.horizontal,
               child: Row(
                 children: [
                   _SummaryChip(
                       label: 'Lỗi', count: _criticalCount, color: Colors.red),
                   SizedBox(width: ResponsiveUtils.getSpacing(context, type: 'md')),
                   _SummaryChip(
                       label: 'Cảnh báo', count: _warningCount, color: Colors.orange),
                   SizedBox(width: ResponsiveUtils.getSpacing(context, type: 'md')),
                   _SummaryChip(
                       label: 'Tổng', count: _alerts.length, color: Colors.blue),
                   SizedBox(width: ResponsiveUtils.getSpacing(context, type: 'md')),
                   TextButton.icon(
                     onPressed: _clearAll,
                     icon: Icon(Icons.delete_sweep, size: ResponsiveUtils.getIconSize(context, purpose: 'small')),
                     label: const Text('Xóa tất cả'),
                     style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                   ),
                 ],
               ),
             ),
           ),
           Expanded(
             child: ListView.separated(
               padding: EdgeInsets.fromLTRB(
                 ResponsiveUtils.getSpacing(context, type: 'md'),
                 0,
                 ResponsiveUtils.getSpacing(context, type: 'md'),
                 ResponsiveUtils.getSpacing(context, type: 'lg'),
               ),
               itemCount: _alerts.length,
               separatorBuilder: (_, __) => SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'md')),
               itemBuilder: (context, index) {
                 return ConstrainedBox(
                   constraints: BoxConstraints(maxWidth: 600),
                   child: AlertItem(
                     alert: _alerts[index],
                     onDismiss: () => setState(() => _alerts.removeAt(index)),
                     onNavigate: widget.onNavigate,
                   ),
                 );
               },
             ),
           ),
         ],
       ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveUtils.getScale(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getSpacing(context, type: 'md'),
        vertical: ResponsiveUtils.getSpacing(context, type: 'sm'),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: (12 * scale).clamp(10, 14),
            ),
          ),
          SizedBox(width: ResponsiveUtils.getSpacing(context, type: 'sm')),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: (11 * scale).clamp(9, 13),
            ),
          ),
        ],
      ),
    );
  }
}
