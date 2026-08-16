import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../services/sound_analyzer.dart';
import 'chat_screen.dart';

class RecordScreen extends StatefulWidget {
  final String carName;
  final String carId;
  final String year; // ✅ اضافه شد

  const RecordScreen({
    super.key,
    required this.carName,
    required this.carId,
    required this.year, // ✅ اضافه شد
  });

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isProcessing = false;
  int _secondsElapsed = 0;
  Timer? _timer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    if (_isRecording) {
      context.read<AudioService>().stopRecording();
    }
    super.dispose();
  }

  void _startTimer() {
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsElapsed++);
    });
  }

  String get _formattedTime {
    final minutes = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _toggleRecording() async {
    final audioService = context.read<AudioService>();
    final soundAnalyzer = context.read<SoundAnalyzer>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (_isRecording) {
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      try {
        final file = await audioService.stopRecording();
        if (file == null) throw Exception('فایل صوتی ذخیره نشد.');

        final features = await soundAnalyzer.analyze(file.filePath);

        if (!mounted) return;

        final voiceMessage =
            "من صدای موتور ماشین رو با گوشی ضبط کردم.\n"
            "نتایج آنالیز صوتی نرم‌افزار اینه:\n"
            "- قدرت صدا (RMS): ${features.rms.toStringAsFixed(3)}\n"
            "- فرکانس غالب: ${features.dominantFrequency.toStringAsFixed(1)} هرتز\n"
            "لطفاً بر اساس این اطلاعات بگو مشکل چیه؟";

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              carName: widget.carName,
              carId: widget.carId,
              year: widget.year, // ✅ اضافه شد
              initialUserMessage: voiceMessage,
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'خطا: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      try {
        await audioService.startRecording();
        _startTimer();
        setState(() => _isRecording = true);
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('خطا در شروع ضبط: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('آنالیز صوتی موتور')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isRecording)
              Text(
                _formattedTime,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),

            const SizedBox(height: 40),

            ScaleTransition(
              scale: _isRecording
                  ? Tween(begin: 1.0, end: 1.15).animate(_animController)
                  : const AlwaysStoppedAnimation(1.0),
              child: GestureDetector(
                onTap: _isProcessing ? null : _toggleRecording,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording
                        ? Colors.red.shade600
                        : theme.colorScheme.secondary,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording
                                ? Colors.red
                                : theme.colorScheme.secondary)
                            .withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Icon(
                            _isRecording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
            Text(
              _isProcessing
                  ? 'در حال پردازش صدا...'
                  : (_isRecording
                      ? 'در حال ضبط، گوشی را نزدیک موتور نگه دارید'
                      : 'برای شروع تحلیل صوتی ضربه بزنید'),
              style: TextStyle(color: theme.hintColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
