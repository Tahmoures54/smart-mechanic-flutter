import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // ✅ افزودن پکیج دسترسی‌ها
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../services/sound_analyzer.dart';
import 'chat_screen.dart';

class RecordScreen extends StatefulWidget {
  final String carName;
  final String carId;
  final String year;

  const RecordScreen({
    super.key,
    required this.carName,
    required this.carId,
    required this.year,
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

  // ✅ حداکثر زمان مجاز برای ضبط (15 ثانیه برای آنالیز موتور کافی است)
  static const int _maxRecordingDuration = 15;

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
      setState(() {
        _secondsElapsed++;
        // ✅ توقف خودکار هنگام رسیدن به زمان maximal
        if (_secondsElapsed >= _maxRecordingDuration) {
          timer.cancel();
          _toggleRecording(); // توقف خودکار ضبط
        }
      });
    });
  }

  String get _formattedTime {
    final minutes = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ✅ متد کمکی برای نمایش Snackbar
  void _showSnack(String msg, {Color color = Colors.redAccent}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ✅ بررسی و درخواست دسترسی میکروفون
  Future<bool> _requestMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    if (status.isDenied || status.isPermanentlyDenied) {
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      return true;
    } else {
      _showSnack('دسترسی به میکروفون داده نشد. لطفاً از تنظیمات فعال کنید.');
      return false;
    }
  }

  Future<void> _toggleRecording() async {
    // جلوگیری از اجرای همزمان
    if (_isProcessing) return;

    final audioService = context.read<AudioService>();
    final soundAnalyzer = context.read<SoundAnalyzer>();

    if (_isRecording) {
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      try {
        final file = await audioService.stopRecording();
        if (file == null) throw Exception('فایل صوتی ذخیره نشد.');

        // آنالیز فایل صوتی
        final features = await soundAnalyzer.analyze(file.filePath);

        if (!mounted) return;

        // ساخت پیام مبتنی بر داده‌های استخراج شده
        final voiceMessage = "من صدای موتور ماشین رو با گوشی ضبط کردم.\n"
            "نتایج آنالیز صوتی نرم‌افزار اینه:\n"
            "- قدرت صدا (RMS): ${features.rms.toStringAsFixed(3)}\n"
            "- فرکانس غالب: ${features.dominantFrequency.toStringAsFixed(1)} هرتز\n"
            "لطفاً بر اساس این اطلاعات بگو مشکل چیا ممکنه باشه؟";

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              carName: widget.carName,
              carId: widget.carId,
              year: widget.year,
              initialUserMessage: voiceMessage,
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        _showSnack('خطا در پردازش صدا. لطفاً دوباره تلاش کنید.');
        setState(() => _isProcessing = false);
      }
    } else {
      // ✅ بررسی دسترسی قبل از شروع ضبط
      final hasPermission = await _requestMicPermission();
      if (!hasPermission) return;

      try {
        await audioService.startRecording();
        _startTimer();
        setState(() => _isRecording = true);
      } catch (e) {
        _showSnack('خطا در شروع ضبط صدا.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('آنالیز صوتی موتور'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── نمایش تایمر ──
            if (_isRecording || _isProcessing)
              Text(
                _formattedTime,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                ),
              ),

            const SizedBox(height: 40),

            // ── دکمه ضبط ──
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
            
            // ── متن وضعیت ──
            Text(
              _isProcessing
                  ? 'در حال پردازش صدا... لطفاً شکیبا باشید.'
                  : (_isRecording
                      ? 'در حال ضبط (حداکثر $_maxRecordingDuration ثانیه)'
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
