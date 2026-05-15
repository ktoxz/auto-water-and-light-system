import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/app_config.dart';
import '../models/sensor_data.dart';
import '../models/alert_model.dart';

class MqttService {
  late MqttServerClient _client;

  final _sensorController = StreamController<SensorData>.broadcast();
  final _alertController = StreamController<AlertModel>.broadcast();
  final _deviceStatusController = StreamController<Map<String, bool>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _voiceResponseController = StreamController<String>.broadcast();

  Stream<SensorData> get sensorStream => _sensorController.stream;
  Stream<AlertModel> get alertStream => _alertController.stream;
  Stream<Map<String, bool>> get deviceStatusStream => _deviceStatusController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get voiceResponseStream => _voiceResponseController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final Map<String, bool> _deviceStates = {
    'pump': false,
    'mist': false,
    'led': false,
  };
  Map<String, bool> get deviceStates => Map.unmodifiable(_deviceStates);

  MqttService();

  Future<void> connect() async {
    final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';

    _client = MqttServerClient.withPort(
      AppConfig.hiveMqHost,
      clientId,
      AppConfig.hiveMqPort,
    );

    _client.secure = true;
    _client.securityContext = SecurityContext.defaultContext;
    _client.keepAlivePeriod = 20;
    _client.autoReconnect = false; // tắt autoReconnect, tự reconnect thủ công
    _client.logging(on: true);    // bật log để debug
    _client.connectTimeoutPeriod = 5000; // 5 giây

    _client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withProtocolName('MQTT')      // MQTT v3.1.1
        .withProtocolVersion(4)        // 4 = v3.1.1
        .authenticateAs(AppConfig.hiveMqUsername, AppConfig.hiveMqPassword)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onBadCertificate = (dynamic cert) => true;

    try {
      // Timeout toàn bộ quá trình connect sau 8 giây
      await _client.connect().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('MQTT: connect() timed out');
          _client.disconnect();
        },
      );
      print('MQTT: connect() returned, state=${_client.connectionStatus?.state}');
    } catch (e) {
      print('MQTT: connect() error — $e');
      _isConnected = false;
      _connectionController.add(false);
      try { _client.disconnect(); } catch (_) {}
    }
  }

  void _onConnected() {
    print('MQTT: Connected!');
    _isConnected = true;
    _connectionController.add(true);
    _subscribeToTopics();
  }

  void _onDisconnected() {
    print('MQTT: Disconnected');
    _isConnected = false;
    _connectionController.add(false);
    // Thử reconnect sau 5 giây
    Future.delayed(const Duration(seconds: 5), connect);
  }

  void _subscribeToTopics() {
    final topics = [
      AppConfig.topicTemp,
      AppConfig.topicHumidity,
      AppConfig.topicSoil,
      AppConfig.topicPumpStatus,
      AppConfig.topicLedStatus,
      AppConfig.topicMistStatus,
      AppConfig.topicAlerts,
      AppConfig.topicVoiceResponse,
    ];

    for (final topic in topics) {
      _client.subscribe(topic, MqttQos.atLeastOnce);
    }

    _client.updates!.listen(_onMessageReceived);
  }

  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final topic = msg.topic;
      final publish = msg.payload as MqttPublishMessage;
      final raw = MqttPublishPayload.bytesToStringAsString(
        publish.payload.message!,
      );
      print('MQTT recv: $topic = $raw');
      _handleMessage(topic, raw);
    }
  }

  void _handleMessage(String topic, String payload) {
    try {
      if (topic == AppConfig.topicTemp) {
        _emitSensor(temperature: double.tryParse(payload) ?? 0);
      } else if (topic == AppConfig.topicHumidity) {
        _emitSensor(humidity: double.tryParse(payload) ?? 0);
      } else if (topic == AppConfig.topicSoil) {
        _emitSensor(soilMoisture: int.tryParse(payload) ?? 0);
      } else if (topic == AppConfig.topicPumpStatus) {
        _deviceStates['pump'] = payload.toUpperCase() == 'ON';
        _deviceStatusController.add(Map.from(_deviceStates));
      } else if (topic == AppConfig.topicLedStatus) {
        _deviceStates['led'] = payload.toUpperCase() == 'ON';
        _deviceStatusController.add(Map.from(_deviceStates));
      } else if (topic == AppConfig.topicMistStatus) {
        _deviceStates['mist'] = payload.toUpperCase() == 'ON';
        _deviceStatusController.add(Map.from(_deviceStates));
      } else if (topic == AppConfig.topicAlerts) {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        _alertController.add(AlertModel.fromJson(json));
      } else if (topic == AppConfig.topicVoiceResponse) {
        _voiceResponseController.add(payload);
      }
    } catch (e) {
      print('MQTT: parse error on $topic — $e');
    }
  }

  double _lastTemp = 0;
  double _lastHumidity = 0;
  int _lastSoil = 0;

  void _emitSensor({double? temperature, double? humidity, int? soilMoisture}) {
    if (temperature != null) _lastTemp = temperature;
    if (humidity != null) _lastHumidity = humidity;
    if (soilMoisture != null) _lastSoil = soilMoisture;

    _sensorController.add(SensorData(
      temperature: _lastTemp,
      humidity: _lastHumidity,
      soilMoisture: _lastSoil,
      timestamp: DateTime.now(),
    ));
  }

  void publishControl(String device, bool on) {
    String topic;
    switch (device) {
      case 'pump': topic = AppConfig.topicPumpControl; break;
      case 'mist': topic = AppConfig.topicMistControl; break;
      case 'led':  topic = AppConfig.topicLedControl;  break;
      default: return;
    }
    _publish(topic, on ? 'ON' : 'OFF');
  }

  void publishVoiceCommand(String text) {
    _publish(AppConfig.topicVoiceCommand, text);
  }

  void _publish(String topic, String payload) {
    if (!_isConnected) return;
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void disconnect() {
    try { _client.disconnect(); } catch (_) {}
    _sensorController.close();
    _alertController.close();
    _deviceStatusController.close();
    _connectionController.close();
    _voiceResponseController.close();
  }
}