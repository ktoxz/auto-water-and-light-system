import 'dart:async';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  WebSocketService();

  /// Thử kết nối tới RPi5. Trả về true nếu thành công (local mode).
  Future<bool> tryConnect() async {
    try {
      final uri = Uri.parse(
        'ws://${AppConfig.rpiHost}:${AppConfig.websocketPort}',
      );
      _channel = WebSocketChannel.connect(uri);

      // Chờ kết nối thực sự (timeout 3 giây)
      await _channel!.ready.timeout(const Duration(seconds: 3));

      _isConnected = true;
      _listenForResponses();
      return true;
    } catch (_) {
      _isConnected = false;
      _channel = null;
      return false;
    }
  }

  void _listenForResponses() {
    _channel?.stream.listen(
      (data) {
        if (data is String) {
          _responseController.add(data);
        }
      },
      onDone: () {
        _isConnected = false;
      },
      onError: (_) {
        _isConnected = false;
      },
      cancelOnError: true,
    );
  }

  /// Gửi text lệnh lên RPi5 (dùng khi Android STT đã convert audio → text)
  void sendText(String text) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(text);
  }

  /// Gửi audio chunk (binary PCM 16kHz mono 16-bit) lên RPi5 → Vosk
  void sendAudioChunk(Uint8List pcmBytes) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(pcmBytes);
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _responseController.close();
  }
}
