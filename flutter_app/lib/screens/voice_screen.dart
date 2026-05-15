import 'dart:async';
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
      if (mounted) {
        setState(() {
          _responseText = resp;
          _isListening = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _textSub.cancel();
    _responseSub.cancel();
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
      await stt.startListening();
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
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              label: Text(
                modeLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              backgroundColor: modeColor.withOpacity(0.15),
              labelStyle: TextStyle(color: modeColor),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Mic button với animation
                  GestureDetector(
                    onTap: mode == VoiceMode.unavailable ? null : _toggleListening,
                    child: _isListening
                        ? ScaleTransition(
                            scale: Tween(begin: 0.85, end: 1.15)
                                .animate(_animController),
                            child: _MicCircle(
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

                  const SizedBox(height: 20),
                  Text(
                    mode == VoiceMode.unavailable
                        ? 'Không có mic hoặc kết nối'
                        : _isListening
                            ? 'Đang lắng nghe...'
                            : 'Nhấn để bắt đầu nói',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _isListening ? Colors.blue : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  if (mode == VoiceMode.local) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Vosk offline trên RPi5 → Gemma 3 4B',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green[600],
                          ),
                    ),
                  ] else if (mode == VoiceMode.remote) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Android STT → MQTT → Gemma 3 4B',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange[700],
                          ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Kết quả nhận dạng
                  if (_recognizedText.isNotEmpty) ...[
                    _ResultCard(
                      label: 'Bạn nói:',
                      text: _recognizedText,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Phản hồi từ server
                  if (_responseText.isNotEmpty) ...[
                    _ResultCard(
                      label: 'Kết quả:',
                      text: _responseText,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Hướng dẫn lệnh
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
          ),
        ],
      ),
      floatingActionButton: mode != VoiceMode.unavailable
          ? FloatingActionButton.large(
              onPressed: _toggleListening,
              backgroundColor: _isListening ? Colors.red : Colors.blue,
              child: Icon(
                _isListening ? Icons.stop : Icons.mic,
                size: 32,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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

class _MicCircle extends StatelessWidget {
  final bool isListening;
  final Color color;

  const _MicCircle({required this.isListening, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(
        isListening ? Icons.mic : Icons.mic_none,
        size: 64,
        color: color,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _ResultCard({
    required this.label,
    required this.text,
    required this.color,
  });

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
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
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
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
