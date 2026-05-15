import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config/app_config.dart';
import '../models/sensor_data.dart';
import '../models/alert_model.dart';

class MqttService {
  MqttServerClient? _client;
  StreamSubscription? _updatesSubscription;
  Timer? _reconnectTimer;

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
  bool _isConnecting = false;
  bool _disposed = false;
  bool get isConnected => _isConnected;

  final Map<String, bool> _deviceStates = {
    'pump': false,
    'mist': false,
    'led': false,
  };
  Map<String, bool> get deviceStates => Map.unmodifiable(_deviceStates);

  MqttService();

  Future<void> connect() async {
    if (_disposed || _isConnected || _isConnecting) return;

    _reconnectTimer?.cancel();
    _isConnecting = true;
    final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';

    final client = MqttServerClient.withPort(
      AppConfig.hiveMqHost,
      clientId,
      AppConfig.hiveMqPort,
    );
    _client = client;

    client.secure = true;
    client.securityContext = SecurityContext.defaultContext;
    client.keepAlivePeriod = 20;
    client.autoReconnect = false;
    client.logging(on: true);
    client.connectTimeoutPeriod = 30000;

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withProtocolName('MQTT')
        .withProtocolVersion(4)
        .authenticateAs(AppConfig.hiveMqUsername, AppConfig.hiveMqPassword)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;
    client.onBadCertificate = (dynamic cert) => true;

    try {
      await client.connect().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('MQTT: connect() timed out');
          client.disconnect();
          return client.connectionStatus;
        },
      );
      print('MQTT: connect() returned, state=${client.connectionStatus?.state}');
    } catch (e) {
      print('MQTT: connect() error — $e');
      _setConnected(false);
      try {
        client.disconnect();
      } catch (_) {}
    } finally {
      _isConnecting = false;
    }
  }

  void _onConnected() {
    print('MQTT: Connected!');
    _setConnected(true);
    _subscribeToTopics();
  }

  void _onDisconnected() {
    print('MQTT: Disconnected');
    _setConnected(false);
    _updatesSubscription?.cancel();
    _updatesSubscription = null;

    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void _setConnected(bool value) {
    _isConnected = value;
    if (!_connectionController.isClosed) {
      _connectionController.add(value);
    }
  }

  void _subscribeToTopics() {
    final client = _client;
    if (client == null) return;

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
      client.subscribe(topic, MqttQos.atLeastOnce);
    }

    _updatesSubscription?.cancel();
    _updatesSubscription = client.updates?.listen(_onMessageReceived);
  }

  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final topic = msg.topic;
      final publish = msg.payload as MqttPublishMessage;
      final raw = MqttPublishPayload.bytesToStringAsString(
        publish.payload.message,
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
        _emitDeviceStates();
      } else if (topic == AppConfig.topicLedStatus) {
        _deviceStates['led'] = payload.toUpperCase() == 'ON';
        _emitDeviceStates();
      } else if (topic == AppConfig.topicMistStatus) {
        _deviceStates['mist'] = payload.toUpperCase() == 'ON';
        _emitDeviceStates();
      } else if (topic == AppConfig.topicAlerts) {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        if (!_alertController.isClosed) {
          _alertController.add(AlertModel.fromJson(json));
        }
      } else if (topic == AppConfig.topicVoiceResponse) {
        if (!_voiceResponseController.isClosed) {
          _voiceResponseController.add(payload);
        }
      }
    } catch (e) {
      print('MQTT: parse error on $topic — $e');
    }
  }

  void _emitDeviceStates() {
    if (!_deviceStatusController.isClosed) {
      _deviceStatusController.add(Map.from(_deviceStates));
    }
  }

  double _lastTemp = 0;
  double _lastHumidity = 0;
  int _lastSoil = 0;

  void _emitSensor({double? temperature, double? humidity, int? soilMoisture}) {
    if (temperature != null) _lastTemp = temperature;
    if (humidity != null) _lastHumidity = humidity;
    if (soilMoisture != null) _lastSoil = soilMoisture;

    if (!_sensorController.isClosed) {
      _sensorController.add(SensorData(
        temperature: _lastTemp,
        humidity: _lastHumidity,
        soilMoisture: _lastSoil,
        timestamp: DateTime.now(),
      ));
    }
  }

  bool publishControl(String device, bool on) {
    final topic = switch (device) {
      'pump' => AppConfig.topicPumpControl,
      'mist' => AppConfig.topicMistControl,
      'led' => AppConfig.topicLedControl,
      _ => null,
    };
    if (topic == null) return false;
    return _publish(topic, on ? 'ON' : 'OFF');
  }

  bool publishVoiceCommand(String text) {
    return _publish(AppConfig.topicVoiceCommand, text);
  }

  bool _publish(String topic, String payload) {
    final client = _client;
    if (!_isConnected || client == null) return false;

    try {
      final builder = MqttClientPayloadBuilder()..addString(payload);
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      return true;
    } catch (e) {
      print('MQTT: publish error on $topic — $e');
      return false;
    }
  }

  void disconnect() {
    if (_disposed) return;
    _disposed = true;
    _reconnectTimer?.cancel();
    _updatesSubscription?.cancel();
    try {
      _client?.disconnect();
    } catch (_) {}
    _sensorController.close();
    _alertController.close();
    _deviceStatusController.close();
    _connectionController.close();
    _voiceResponseController.close();
  }
}
