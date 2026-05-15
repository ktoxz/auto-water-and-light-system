import 'dart:async';
import 'dart:convert';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'websocket_service.dart';
import 'mqtt_service.dart';

enum VoiceMode { local, remote, unavailable }

class SttService {
  final WebSocketService _wsService;
  final MqttService _mqttService;

  final AudioRecorder _recorder = AudioRecorder();
  final stt.SpeechToText _androidStt = stt.SpeechToText();

  VoiceMode _mode = VoiceMode.unavailable;
  VoiceMode get mode => _mode;

  bool _isListening = false;
  bool get isListening => _isListening;

  final _recognizedTextController = StreamController<String>.broadcast();
  final _responseController = StreamController<String>.broadcast();

  Stream<String> get recognizedTextStream => _recognizedTextController.stream;
  Stream<String> get responseStream => _responseController.stream;

  SttService({
    required WebSocketService wsService,
    required MqttService mqttService,
  })  : _wsService = wsService,
        _mqttService = mqttService;

  /// Gọi một lần khi app khởi động để xác định mode
  Future<VoiceMode> detectMode() async {
    // Thử kết nối WebSocket tới RPi5
    final localOk = await _wsService.tryConnect();
    if (localOk) {
      _mode = VoiceMode.local;
      // Parse JSON response từ WebSocket
      _wsService.responseStream.listen((r) {
        try {
          final json = jsonDecode(r) as Map<String, dynamic>;
          final text = json['text'] as String? ?? '';
          final message = json['message'] as String? ?? r;
          if (text.isNotEmpty && !_recognizedTextController.isClosed) {
            _recognizedTextController.add(text);
          }
          if (!_responseController.isClosed) {
            _responseController.add(message);
          }
        } catch (_) {
          if (!_responseController.isClosed) {
            _responseController.add(r);
          }
        }
      });
      return _mode;
    }

    // Thử khởi tạo Android STT
    final androidOk = await _androidStt.initialize();
    if (androidOk) {
      _mode = VoiceMode.remote;
      // Forward response từ MQTT voice response
      _mqttService.voiceResponseStream.listen((r) {
        try {
          final json = jsonDecode(r) as Map<String, dynamic>;
          final message = json['message'] as String? ?? r;
          if (!_responseController.isClosed) {
            _responseController.add(message);
          }
        } catch (_) {
          if (!_responseController.isClosed) {
            _responseController.add(r);
          }
        }
      });
      return _mode;
    }

    _mode = VoiceMode.unavailable;
    return _mode;
  }

  /// Bắt đầu lắng nghe
  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;

    if (_mode == VoiceMode.local) {
      await _startLocalListening();
    } else if (_mode == VoiceMode.remote) {
      await _startRemoteListening();
    }
  }

  /// Local mode: record PCM → WebSocket → Vosk → Gemma trên RPi5
  Future<void> _startLocalListening() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _isListening = false;
      return;
    }

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      stream.listen(
            (chunk) => _wsService.sendAudioChunk(chunk),
        onDone: () => _isListening = false,
        onError: (_) => _isListening = false,
        cancelOnError: true,
      );
    } catch (e) {
      _isListening = false;
    }
  }

  /// Remote mode: Android STT → text → MQTT → RPi5 → Gemma
  Future<void> _startRemoteListening() async {
    try {
      await _androidStt.listen(
        localeId: 'vi_VN',
        onResult: (result) {
          if (result.finalResult) {
            final text = result.recognizedWords;
            if (text.isNotEmpty) {
              if (!_recognizedTextController.isClosed) {
                _recognizedTextController.add(text);
              }
              // Gửi text lên RPi5 qua MQTT → Gemma xử lý
              _mqttService.publishVoiceCommand(text);
            }
            _isListening = false;
          }
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: true,
      );
    } catch (e) {
      _isListening = false;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;

    if (_mode == VoiceMode.local) {
      await _recorder.stop();
    } else if (_mode == VoiceMode.remote) {
      await _androidStt.stop();
    }
  }

  void dispose() {
    _recorder.dispose();
    _recognizedTextController.close();
    _responseController.close();
  }
}