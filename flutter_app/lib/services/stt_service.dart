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

  bool _wsListenerAttached = false;
  bool _mqttListenerAttached = false;

  final _recognizedTextController = StreamController<String>.broadcast();
  final _responseController = StreamController<String>.broadcast();

  Stream<String> get recognizedTextStream => _recognizedTextController.stream;
  Stream<String> get responseStream => _responseController.stream;

  SttService({
    required WebSocketService wsService,
    required MqttService mqttService,
  })  : _wsService = wsService,
        _mqttService = mqttService;

  void _attachWsListener() {
    if (_wsListenerAttached) return;
    _wsListenerAttached = true;
    _wsService.responseStream.listen((r) {
      try {
        final json = jsonDecode(r) as Map<String, dynamic>;
        final text    = json['text']    as String? ?? '';
        final message = json['message'] as String? ?? r;
        if (text.isNotEmpty && !_recognizedTextController.isClosed) {
          _recognizedTextController.add(text);
        }
        if (!_responseController.isClosed) {
          _responseController.add(r); // gửi raw JSON để voice_screen parse
        }
      } catch (_) {
        if (!_responseController.isClosed) _responseController.add(r);
      }
    });
  }

  void _attachMqttListener() {
    if (_mqttListenerAttached) return;
    _mqttListenerAttached = true;
    _mqttService.voiceResponseStream.listen((r) {
      try {
        final json    = jsonDecode(r) as Map<String, dynamic>;
        final message = json['message'] as String? ?? r;
        if (!_responseController.isClosed) {
          _responseController.add(json.containsKey('status') ? r : '{"status":"ok","message":"$message"}');
        }
      } catch (_) {
        if (!_responseController.isClosed) _responseController.add(r);
      }
    });
  }

  /// Gọi khi app khởi động hoặc khi muốn redetect
  Future<VoiceMode> detectMode() async {
    final localOk = await _wsService.tryConnect();
    if (localOk) {
      _mode = VoiceMode.local;
      _attachWsListener();
      return _mode;
    }

    final androidOk = await _androidStt.initialize();
    if (androidOk) {
      _mode = VoiceMode.remote;
      _attachMqttListener();
      return _mode;
    }

    _mode = VoiceMode.unavailable;
    return _mode;
  }

  /// Switch thủ công giữa local và remote
  Future<VoiceMode> switchMode() async {
    if (_isListening) return _mode; // không switch khi đang nghe

    if (_mode == VoiceMode.local) {
      // Chuyển sang remote
      final androidOk = await _androidStt.initialize();
      _mode = androidOk ? VoiceMode.remote : VoiceMode.unavailable;
      if (_mode == VoiceMode.remote) _attachMqttListener();
    } else {
      // Chuyển sang local
      final localOk = await _wsService.tryConnect();
      if (localOk) {
        _mode = VoiceMode.local;
        _attachWsListener();
      } else {
        // Giữ remote nếu không connect được
        _mode = VoiceMode.remote;
      }
    }
    return _mode;
  }

  Future<void> startListening() async {
    if (_isListening) return;
    _isListening = true;

    if (_mode == VoiceMode.local) {
      await _startLocalListening();
    } else if (_mode == VoiceMode.remote) {
      await _startRemoteListening();
    }
  }

  Future<void> _startLocalListening() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) { _isListening = false; return; }

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