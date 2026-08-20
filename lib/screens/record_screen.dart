import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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

  static const int _maxRecordingDuration = 15;
  static const int _minRecordingDuration = 3;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    if (_isRecording) {
      // ایمن: اگر هنوز در حال ضبط است، متوقف کن
      try {
        context.read<AudioService>().stopRecording();
      } catch (_) {}
    }
    super.dispose();
  }

  void _startTimer() {
    _secondsElapsed = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsElapsed++;
        if (_secondsElapsed >= _maxRecordingDuration) {
          timer.cancel();
          _toggleRecording();
        }
      });
    });
  }

  String get _formattedTime {
    final minutes = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showSnack(String msg, {Color? color}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _requestMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    status = await Permission.microphone.request();

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      _showSnack('دسترسی میکروفون دائماً رد شده. از تنظیمات فعال کنید.');
      await openAppSettings();
    } else {
      _showSnack('دسترسی به میکروفون داده نشد.');
    }
    return false;
  }

  Future<void> _toggleRecording() async {
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
        final info = await audioService.stopRecording();
        if (info == null) {
          throw Exception('فایل صوتی ذخیره نشد.');
        }

        if (info.duration.inSeconds < _minRecordingDuration) {
          throw Exception(
            'مدت ضبط خیلی کوتاه است. حداقل $_minRecordingDuration ثانیه ضبط کنید.',
          );
        }

        final features = await soundAnalyzer.analyze(info.filePath);

        if (!mounted) return;

        final voiceMessage = '''
من صدای موتور ماشین رو با گوشی ضبط کردم.
نتایج آنالیز صوتی نرم‌افزار:
- قدرت صدا (RMS): ${features.rms.toStringAsFixed(3)}
- فرکانس غالب: ${features.dominantFrequency.toStringAsFixed(1)} هرتز
- مرکز طیف: ${features.spectralCentroid.toStringAsFixed(1)} هرتز
- سطح صدا: ${features.noiseLevel.label}

لطفاً بر اساس این اطلاعات بگو مشکل چیا ممکنه باشه؟
'''.trim();

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
        final msg = e.toString().contains('خیلی کوتاه')
            ? e.toString().replaceFirst('Exception: ', '')
            : 'خطا در پردازش صدا. لطفاً دوباره تلاش کنید.';
        _showSnack(msg);
        setState(() => _isProcessing = false);
      }
    } else {
      final hasPermission = await _requestMicPermission();
      if (!hasPermission) return;

      try {
        await audioService.startRecording(
          config: RecordingConfig.engineAnalysis,
        );
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
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // راهنما
                if (!_isRecording && !_isProcessing)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.secondary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: theme.colorScheme.secondary,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'موتور را روشن کنید و گوشی را نزدیک محفظه موتور نگه دارید.\n'
                          'حداقل $_minRecordingDuration و حداکثر $_maxRecordingDuration ثانیه ضبط کنید.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                // تایمر
                if (_isRecording || _isProcessing)
                  Text(
                    _formattedTime,
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                      color: _isRecording
                          ? Colors.red.shade400
                          : theme.colorScheme.secondary,
                    ),
                  ),

                const SizedBox(height: 36),

                // دکمه ضبط
                ScaleTransition(
                  scale: _isRecording
                      ? Tween(begin: 1.0, end: 1.12).animate(_animController)
                      : const AlwaysStoppedAnimation(1.0),
                  child: GestureDetector(
                    onTap: _isProcessing ? null : _toggleRecording,
                    child: Container(
                      width: 150,
                      height: 150,
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
                                .withOpacity(0.35),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isProcessing
                            ? const SizedBox(
                                width: 42,
                                height: 42,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : Icon(
                                _isRecording
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded,
                                color: Colors.white,
                                size: 68,
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  _isProcessing
                      ? 'در حال پردازش صدا... لطفاً شکیبا باشید.'
                      : (_isRecording
                          ? 'در حال ضبط (حداکثر $_maxRecordingDuration ثانیه)'
                          : 'برای شروع تحلیل صوتی ضربه بزنید'),
                  style: TextStyle(
                    color: theme.hintColor,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (_isRecording) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _secondsElapsed / _maxRecordingDuration,
                    backgroundColor: theme.dividerColor,
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
