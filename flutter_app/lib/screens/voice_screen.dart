import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/stt_service.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  String _recognizedText = '';
  String _responseText = '';
  late AnimationController _animController;
  Timer? _modeTimer;

  late StreamSubscription _textSub;
  late StreamSubscription _responseSub;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat(reverse: true);

    final stt = context.read<SttService>();

    _textSub = stt.recognizedTextStream.listen((text) {
      if (mounted) setState(() => _recognizedText = text);
    });

    _responseSub = stt.responseStream.listen((resp) {
      if (!mounted) return;
      try {
        final json = jsonDecode(resp) as Map<String, dynamic>;
        final status = json['status'] as String? ?? '';
        if (status == 'ok' || status == 'error') {
          setState(() {
            _responseText = json['message'] as String? ?? resp;
            _isListening = false;
          });
        }
        // Bỏ qua nếu status không hợp lệ
      } catch (_) {
        // Bỏ qua data không phải JSON
      }
    });

    // Rebuild mỗi 2 giây để cập nhật mode
    _modeTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _textSub.cancel();
    _responseSub.cancel();
    _modeTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    final stt = context.read<SttService>();
    if (_isListening) {
      await stt.stopListening();
      setState(() => _isListening = false);
    } else {
      setState(() {
        _isListening = true;
        _recognizedText = '';
        _responseText = '';
      });
      stt.startListening(); // không await — stream chạy ngầm
    }
  }

  String _modeLabel(VoiceMode mode) {
    switch (mode) {
      case VoiceMode.local:
        return 'LOCAL';
      case VoiceMode.remote:
        return 'REMOTE';
      case VoiceMode.unavailable:
        return 'UNAVAILABLE';
    }
  }

  Color _modeColor(VoiceMode mode) {
    switch (mode) {
      case VoiceMode.local:
        return Colors.green;
      case VoiceMode.remote:
        return Colors.orange;
      case VoiceMode.unavailable:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stt = context.read<SttService>();
    final mode = stt.mode;
    final modeColor = _modeColor(mode);
    final modeLabel = _modeLabel(mode);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Điều Khiển Giọng Nói'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(
                modeLabel,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold),
              ),
              backgroundColor: modeColor.withOpacity(0.15),
              labelStyle: TextStyle(color: modeColor),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ConstrainedBox(
                constraints:
                BoxConstraints(minHeight: constraints.maxHeight - 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: mode == VoiceMode.unavailable
                            ? null
                            : _toggleListening,
                        child: _isListening
                            ? ScaleTransition(
                          scale: Tween(begin: 0.9, end: 1.08)
                              .animate(_animController),
                          child: const _MicCircle(
                            isListening: true,
                            color: Colors.blue,
                          ),
                        )
                            : _MicCircle(
                          isListening: false,
                          color: mode == VoiceMode.unavailable
                              ? Colors.grey
                              : Colors.grey[400]!,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: mode == VoiceMode.unavailable
                          ? null
                          : _toggleListening,
                      icon: Icon(_isListening ? Icons.stop : Icons.mic),
                      label: Text(
                        mode == VoiceMode.unavailable
                            ? 'Không có mic hoặc kết nối'
                            : _isListening
                            ? 'Dừng nghe'
                            : 'Bắt đầu nói',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                        _isListening ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isListening
                          ? 'Đang lắng nghe...'
                          : 'Nhấn nút để ra lệnh bằng giọng nói',
                      textAlign: TextAlign.center,
                      style:
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _isListening
                            ? Colors.blue
                            : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ModeDescription(mode: mode),
                    const SizedBox(height: 20),
                    if (_recognizedText.isNotEmpty) ...[
                      _ResultCard(
                        label: 'Bạn nói:',
                        text: _recognizedText,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_responseText.isNotEmpty) ...[
                      _ResultCard(
                        label: 'Kết quả:',
                        text: _responseText,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_isListening && _recognizedText.isNotEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Gemma đang xử lý...'),
                            ],
                          ),
                        ),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ví dụ lệnh',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            for (final e in _examples)
                              _CommandRow(emoji: e[0], text: e[1]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

const _examples = [
  ['💡', 'bật đèn / tắt đèn'],
  ['💧', 'tưới cây đi / tắt bơm đi'],
  ['🌫️', 'bật phun sương lên / tắt sương đi'],
  ['🌡️', 'cây héo rồi đó → tự hiểu bật bơm'],
  ['🚫', 'hôm nay trời sáng đừng bật đèn'],
];

class _ModeDescription extends StatelessWidget {
  final VoiceMode mode;
  const _ModeDescription({required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode == VoiceMode.local) {
      return Text(
        'Vosk offline trên RPi5 → Gemma 3 4B',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.green[600],
        ),
      );
    }
    if (mode == VoiceMode.remote) {
      return Text(
        'Android STT → MQTT → Gemma 3 4B',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.orange[700],
        ),
      );
    }
    return Text(
      'Voice hiện chưa khả dụng',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.red[600],
      ),
    );
  }
}

class _MicCircle extends StatelessWidget {
  final bool isListening;
  final Color color;
  const _MicCircle({required this.isListening, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(
        isListening ? Icons.mic : Icons.mic_none,
        size: 56,
        color: color,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  const _ResultCard(
      {required this.label, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  final String emoji;
  final String text;
  const _CommandRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}