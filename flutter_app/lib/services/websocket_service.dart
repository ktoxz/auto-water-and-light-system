import 'dart:async';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _connectedHost;
  String? get connectedHost => _connectedHost;

  final _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  WebSocketService();

  /// Thử kết nối tới RPi5 — tự động thử nhiều địa chỉ
  Future<bool> tryConnect() async {
    final hosts = [
      'raspberrypi.local', // production — điện thoại cùng WiFi RPi5
      'pi-local',          // hostname thay thế
      '10.0.2.2',          // Android Studio emulator
      '10.0.3.2',          // Genymotion emulator
    ];

    for (final host in hosts) {
      try {
        final uri = Uri.parse('ws://$host:${AppConfig.websocketPort}');
        print('[WS] Trying $uri...');

        final channel = WebSocketChannel.connect(uri);
        await channel.ready.timeout(const Duration(seconds: 2));

        _channel = channel;
        _isConnected = true;
        _connectedHost = host;
        print('[WS] Connected to $host');
        _listenForResponses();
        return true;
      } catch (e) {
        print('[WS] Failed $host: $e');
        _channel = null;
        continue;
      }
    }

    _isConnected = false;
    _connectedHost = null;
    print('[WS] All hosts failed — Remote mode');
    return false;
  }

  void _listenForResponses() {
    _channel?.stream.listen(
          (data) {
        if (data is String && !_responseController.isClosed) {
          _responseController.add(data);
        }
      },
      onDone: () {
        print('[WS] Connection closed');
        _isConnected = false;
        _connectedHost = null;
      },
      onError: (e) {
        print('[WS] Connection error: $e');
        _isConnected = false;
        _connectedHost = null;
      },
      cancelOnError: true,
    );
  }

  /// Gửi text lệnh lên RPi5
  void sendText(String text) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(text);
  }

  /// Gửi audio chunk PCM 16kHz mono 16-bit lên RPi5 → Vosk
  void sendAudioChunk(Uint8List pcmBytes) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(pcmBytes);
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _connectedHost = null;
    if (!_responseController.isClosed) {
      _responseController.close();
    }
  }
}