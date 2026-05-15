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
  final _statusController = StreamController<String>.broadcast();
  final _voiceResponseController = StreamController<String>.broadcast();

  Stream<SensorData> get sensorStream => _sensorController.stream;
  Stream<AlertModel> get alertStream => _alertController.stream;
  Stream<Map<String, bool>> get deviceStatusStream async* {
    yield Map.from(_deviceStates);
    yield* _deviceStatusController.stream;
  }
  Stream<bool> get connectionStream async* {
    yield _isConnected;
    yield* _connectionController.stream;
  }
  Stream<String> get statusStream async* {
    yield _lastStatus;
    yield* _statusController.stream;
  }
  Stream<String> get voiceResponseStream => _voiceResponseController.stream;

  String _lastStatus = 'Chưa kết nối MQTT';
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
    _setStatus('Đang kết nối MQTT TLS ${AppConfig.hiveMqPort}');

    final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient.withPort(
      AppConfig.hiveMqHost,
      clientId,
      AppConfig.hiveMqPort,
    );
    _client = client;

    client.secure = true;
    client.securityContext = SecurityContext.defaultContext;
    client.keepAlivePeriod = 30;
    client.autoReconnect = false;
    client.logging(on: true);
    client.connectTimeoutPeriod = 15000;
    client.onBadCertificate = (dynamic cert) => true;

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withProtocolName('MQTT')
        .withProtocolVersion(4)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;

    try {
      final status = await client
          .connect(AppConfig.hiveMqUsername, AppConfig.hiveMqPassword)
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _setStatus('MQTT TLS timeout');
          client.disconnect();
          return client.connectionStatus;
        },
      );

      final state = status?.state ?? client.connectionStatus?.state;
      final returnCode = status?.returnCode ?? client.connectionStatus?.returnCode;
      final reason = status?.disconnectionOrigin ?? client.connectionStatus?.disconnectionOrigin;
      print('MQTT: returned, state=$state, returnCode=$returnCode, reason=$reason');

      if (state == MqttConnectionState.connected) {
        _setStatus('MQTT TLS đã kết nối HiveMQ');
        _setConnected(true);
        _subscribeToTopics();
      } else {
        _setStatus('MQTT TLS state=$state, code=$returnCode, reason=$reason');
        _setConnected(false);
        try {
          client.disconnect();
        } catch (_) {}
      }
    } catch (e) {
      print('MQTT: connect error — $e');
      _setStatus('MQTT TLS lỗi: $e');
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
    _setStatus('MQTT TLS đã kết nối HiveMQ');
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

  void _setStatus(String value) {
    _lastStatus = value;
    if (!_statusController.isClosed) {
      _statusController.add(value);
    }
  }

  void _subscribeToTopics() {
    final client = _client;
    if (client == null || client.connectionStatus?.state != MqttConnectionState.connected) return;

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
      client.subscribe(topic, MqttQos.atMostOnce);
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
      _setStatus('Nhận $topic = $raw');
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
      _setStatus('Lỗi parse $topic: $e');
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
      client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
      return true;
    } catch (e) {
      print('MQTT: publish error on $topic — $e');
      _setStatus('Lỗi publish $topic: $e');
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
    _statusController.close();
    _voiceResponseController.close();
  }
}
