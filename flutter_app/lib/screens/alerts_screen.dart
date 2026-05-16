import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alert_model.dart';
import '../services/mqtt_service.dart';
import '../widgets/alert_item.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

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

    // Load history từ MqttService — không mất khi chuyển tab
    _alerts.addAll(mqtt.alertHistory);

    // Lắng nghe alert mới
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
    // Xóa cả history trong MqttService
    context.read<MqttService>().alertHistory; // readonly
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_alerts.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Đọc tất cả'),
            ),
        ],
      ),
      body: _alerts.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: Colors.green.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('Không có cảnh báo',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Hệ thống hoạt động bình thường',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Đang lắng nghe home/alerts...',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[400]),
            ),
          ],
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _SummaryChip(
                    label: 'Lỗi',
                    count: _criticalCount,
                    color: Colors.red),
                const SizedBox(width: 8),
                _SummaryChip(
                    label: 'Cảnh báo',
                    count: _warningCount,
                    color: Colors.orange),
                const SizedBox(width: 8),
                _SummaryChip(
                    label: 'Tổng',
                    count: _alerts.length,
                    color: Colors.blue),
                const Spacer(),
                TextButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_sweep, size: 16),
                  label: const Text('Xóa tất cả'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              itemCount: _alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return AlertItem(
                  alert: _alerts[index],
                  onDismiss: () =>
                      setState(() => _alerts.removeAt(index)),
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

  const _SummaryChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}