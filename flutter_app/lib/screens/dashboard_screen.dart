import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../services/mqtt_service.dart';
import '../services/websocket_service.dart';
import '../widgets/sensor_card.dart';
import '../config/app_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  SensorData _sensor = SensorData(
    temperature: 0,
    humidity: 0,
    soilMoisture: 0,
    timestamp: DateTime.now(),
  );
  Map<String, bool> _deviceStates = {};
  bool _mqttConnected = false;
  bool _hasSensorData = false;
  bool _wsConnected = false;
  String _mqttStatus = 'Chưa kết nối MQTT';

  late StreamSubscription _sensorSub;
  late StreamSubscription _deviceSub;
  late StreamSubscription _connSub;
  late StreamSubscription _statusSub;
  Timer? _wsCheckTimer;

  @override
  void initState() {
    super.initState();
    final mqtt = context.read<MqttService>();
    final ws = context.read<WebSocketService>();

    _mqttConnected = mqtt.isConnected;
    _deviceStates = Map.from(mqtt.deviceStates);
    _wsConnected = ws.isConnected;

    _sensorSub = mqtt.sensorStream.listen((data) {
      if (mounted) setState(() {
        _sensor = data;
        _hasSensorData = true;
      });
    });

    _deviceSub = mqtt.deviceStatusStream.listen((states) {
      if (mounted) setState(() => _deviceStates = states);
    });

    _connSub = mqtt.connectionStream.listen((connected) {
      if (mounted) setState(() => _mqttConnected = connected);
    });

    _statusSub = mqtt.statusStream.listen((status) {
      if (mounted) setState(() => _mqttStatus = status);
    });

    // Check WebSocket status mỗi 3 giây
    _wsCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        final ws = context.read<WebSocketService>();
        setState(() => _wsConnected = ws.isConnected);
      }
    });
  }

  @override
  void dispose() {
    _sensorSub.cancel();
    _deviceSub.cancel();
    _connSub.cancel();
    _statusSub.cancel();
    _wsCheckTimer?.cancel();
    super.dispose();
  }

  bool get _tempWarning => _sensor.temperature > AppConfig.tempHigh;
  bool get _humLow => _sensor.humidity < AppConfig.humidityLow && _sensor.humidity > 0;
  bool get _humHigh => _sensor.humidity > AppConfig.humidityHigh;
  bool get _soilDry => _sensor.soilMoisture < AppConfig.soilDry && _sensor.soilMoisture > 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: _mqttConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  _mqttConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: _mqttConnected ? Colors.green : Colors.red,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _DeviceChip(label: 'Bơm', on: _deviceStates['pump'] ?? false, icon: Icons.opacity),
                  const SizedBox(width: 8),
                  _DeviceChip(label: 'Sương', on: _deviceStates['mist'] ?? false, icon: Icons.cloud),
                  const SizedBox(width: 8),
                  _DeviceChip(label: 'Đèn', on: _deviceStates['led'] ?? false, icon: Icons.light_mode),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Cảm Biến',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  SensorCard(
                    label: 'Nhiệt độ',
                    value: _sensor.temperature > 0
                        ? _sensor.temperature.toStringAsFixed(1)
                        : '--',
                    unit: '°C',
                    icon: Icons.thermostat,
                    color: Colors.red,
                    progress: _sensor.temperature / 50,
                    isWarning: _tempWarning,
                  ),
                  SensorCard(
                    label: 'Độ ẩm KK',
                    value: _sensor.humidity > 0
                        ? _sensor.humidity.toStringAsFixed(1)
                        : '--',
                    unit: '%',
                    icon: Icons.water_drop,
                    color: Colors.blue,
                    progress: _sensor.humidity / 100,
                    isWarning: _humLow || _humHigh,
                  ),
                  SensorCard(
                    label: 'Ẩm đất',
                    value: _sensor.soilMoisture > 0
                        ? '${_sensor.soilMoisture}'
                        : '--',
                    unit: '%',
                    icon: Icons.grass,
                    color: Colors.brown,
                    progress: _sensor.soilMoisture / 100,
                    isWarning: _soilDry,
                  ),
                  SensorCard(
                    label: 'Cập nhật',
                    value: _formatTime(_sensor.timestamp),
                    unit: '',
                    icon: Icons.schedule,
                    color: Colors.purple,
                    progress: 1.0,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kết nối hệ thống',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('HiveMQ Cloud', _mqttConnected),
                      _buildInfoRow('ESP32', _mqttConnected && (_hasSensorData || _deviceStates.isNotEmpty)),
                      _buildInfoRow('RPi5 Broker', _wsConnected),
                      const SizedBox(height: 8),
                      Text(
                        _mqttStatus,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, bool online) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Chip(
            label: Text(online ? 'Trực tuyến' : 'Offline'),
            backgroundColor: online
                ? Colors.green.withOpacity(0.15)
                : Colors.red.withOpacity(0.1),
            labelStyle: TextStyle(
              color: online ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DeviceChip extends StatelessWidget {
  final String label;
  final bool on;
  final IconData icon;

  const _DeviceChip({required this.label, required this.on, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: on ? Colors.green : Colors.grey),
      label: Text(label),
      backgroundColor: on
          ? Colors.green.withOpacity(0.1)
          : Colors.grey.withOpacity(0.1),
      labelStyle: TextStyle(
        color: on ? Colors.green : Colors.grey,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}