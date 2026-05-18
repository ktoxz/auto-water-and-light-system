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
        final data    = jsonDecode(r) as Map<String, dynamic>;
        final text    = data['text']    as String? ?? '';
        if (text.isNotEmpty && !_recognizedTextController.isClosed) {
          _recognizedTextController.add(text);
        }
        if (!_responseController.isClosed) {
          _responseController.add(r); // raw JSON → voice_screen parse
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
        final data = jsonDecode(r) as Map<String, dynamic>;
        // Đảm bảo có field status để voice_screen nhận đúng
        if (!data.containsKey('status')) {
          data['status'] = 'ok';
        }
        // Encode lại bằng jsonEncode — tránh lỗi UTF-8 khi build string thủ công
        final normalized = jsonEncode(data);
        if (!_responseController.isClosed) {
          _responseController.add(normalized);
        }
      } catch (_) {
        if (!_responseController.isClosed) _responseController.add(r);
      }
    });
  }

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

  Future<VoiceMode> switchMode() async {
    if (_isListening) return _mode;

    if (_mode == VoiceMode.local) {
      final androidOk = await _androidStt.initialize();
      _mode = androidOk ? VoiceMode.remote : VoiceMode.unavailable;
      if (_mode == VoiceMode.remote) _attachMqttListener();
    } else {
      final localOk = await _wsService.tryConnect();
      if (localOk) {
        _mode = VoiceMode.local;
        _attachWsListener();
      } else {
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
      _wsService.sendEndOfAudio();
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