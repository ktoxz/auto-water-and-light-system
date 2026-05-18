import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';
import '../widgets/device_toggle.dart';
import '../widgets/mode_badge.dart';
import '../responsive_utils.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  Map<String, bool> _deviceStates = {'pump': false, 'mist': false, 'led': false};
  bool _autoMode = false;
  late StreamSubscription _deviceSub;

  @override
  void initState() {
    super.initState();
    final mqtt = context.read<MqttService>();
    _deviceStates = Map.from(mqtt.deviceStates);
    _deviceSub = mqtt.deviceStatusStream.listen((states) {
      if (mounted) setState(() => _deviceStates = states);
    });
  }

  @override
  void dispose() {
    _deviceSub.cancel();
    super.dispose();
  }

  void _sendCommand(String device, bool on) {
    final sent = context.read<MqttService>().publishControl(device, on);
    if (!sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MQTT chưa kết nối, chưa gửi được lệnh'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _emergencyStop() {
    final mqtt = context.read<MqttService>();
    final sent = [
      mqtt.publishControl('pump', false),
      mqtt.publishControl('mist', false),
      mqtt.publishControl('led', false),
    ].any((value) => value);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sent
            ? 'Đã gửi lệnh dừng tất cả thiết bị'
            : 'MQTT chưa kết nối, chưa gửi được lệnh'),
        backgroundColor: sent ? Colors.red : Colors.orange,
      ),
    );
  }

  void _waterNow() {
    final sent = context.read<MqttService>().publishControl('pump', true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sent
            ? 'Đã gửi lệnh bật máy bơm'
            : 'MQTT chưa kết nối, chưa gửi được lệnh'),
        backgroundColor: sent ? null : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Điều Khiển')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, type: 'lg')),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chế độ hoạt động',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getTitleSize(context))),
            SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'md')),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _autoMode = true),
                    child: ModeBadge(mode: 'Tự động', isActive: _autoMode),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, type: 'md')),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _autoMode = false),
                    child: ModeBadge(mode: 'Thủ công', isActive: !_autoMode),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'xxl')),
            Text('Thiết bị',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getTitleSize(context))),
            SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'md')),
            DeviceToggle(
              label: 'Máy bơm tưới',
              initialValue: _deviceStates['pump'] ?? false,
              icon: Icons.opacity,
              enabled: !_autoMode,
              onChanged: (val) => _sendCommand('pump', val),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'sm')),
            DeviceToggle(
              label: 'Máy phun sương',
              initialValue: _deviceStates['mist'] ?? false,
              icon: Icons.cloud,
              enabled: !_autoMode,
              onChanged: (val) => _sendCommand('mist', val),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'sm')),
            DeviceToggle(
              label: 'Đèn sợi tóc 12V',
              initialValue: _deviceStates['led'] ?? false,
              icon: Icons.light_mode,
              enabled: !_autoMode,
              onChanged: (val) => _sendCommand('led', val),
            ),
            if (_autoMode) ...[
              SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'sm')),
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, type: 'md')),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getBorderRadius(context, size: 'normal')),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: ResponsiveUtils.getIconSize(context, purpose: 'small'),
                        color: Colors.blue),
                    SizedBox(width: ResponsiveUtils.getSpacing(context, type: 'md')),
                    Expanded(
                      child: Text(
                        'Chế độ tự động: RPi5 điều khiển theo ngưỡng cảm biến',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue[700],
                          fontSize: ResponsiveUtils.getSmallSize(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'xxl')),
            Text('Hành động nhanh',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getTitleSize(context))),
            SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'md')),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _waterNow,
                    icon: const Icon(Icons.water),
                    label: const Text('Tưới ngay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.getSpacing(context, type: 'lg')),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, type: 'md')),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _emergencyStop,
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('Dừng tất cả'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          vertical: ResponsiveUtils.getSpacing(context, type: 'lg')),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, type: 'xxl')),
          ],
        ),
      ),
    );
  }
}