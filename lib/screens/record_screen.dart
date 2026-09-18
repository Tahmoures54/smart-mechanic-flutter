import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/sound_analyzer.dart';
import 'chat_screen.dart';

/// صفحه ضبط و آنالیز صوتی موتور.
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

// ---------------------------------------------------------------------------
// Exceptionهای داخلی برای مدیریت دقیق خطا
// ---------------------------------------------------------------------------

class _ShortRecordingException implements Exception {
  final int minSeconds;
  const _ShortRecordingException(this.minSeconds);
  @override
  String toString() =>
      'مدت ضبط خیلی کوتاه است. حداقل $minSeconds ثانیه ضبط کنید.';
}

class _RecordingSaveException implements Exception {
  const _RecordingSaveException();
  @override
  String toString() => 'فایل صوتی ذخیره نشد.';
}

class _MissingTokenException implements Exception {
  const _MissingTokenException();
  @override
  String toString() => 'لطفاً دوباره وارد شوید.';
}

class _RecordScreenState extends State<RecordScreen>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isProcessing = false;
  int _secondsElapsed = 0;
  Timer? _timer;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  static const Animation<double> _stillScale = AlwaysStoppedAnimation(1.0);

  /// نگهداری مرجع سرویس تا در dispose به context وابسته نباشیم.
  AudioService? _audioService;

  static const int _maxRecordingDuration = Constants.maxRecordingSeconds;
  static const int _minRecordingDuration = Constants.minRecordingSeconds;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // فقط یک‌بار بگیر؛ بعد از dispose دیگر context معتبر نیست.
    _audioService ??= context.read<AudioService>();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _animController.dispose();

    if (_isRecording) {
      final audio = _audioService;
      if (audio != null) {
        unawaited(
          audio.cancelRecording().catchError((Object e) {
            debugPrint('[RecordScreen] cancelRecording on dispose: $e');
          }),
        );
      }
    }
    _audioService = null;
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // تایمر
  // ---------------------------------------------------------------------------

  void _startTimer() {
    _timer?.cancel();
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsElapsed++);

      if (_secondsElapsed >= _maxRecordingDuration) {
        timer.cancel();
        _timer = null;
        // بیرون از setState تا از setState تودرتو جلوگیری شود.
        unawaited(_toggleRecording());
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String get _formattedTime {
    final minutes = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ---------------------------------------------------------------------------
  // کمکی‌ها
  // ---------------------------------------------------------------------------

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
    try {
      var status = await Permission.microphone.status;
      if (status.isGranted) return true;

      status = await Permission.microphone.request();
      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        if (!mounted) return false;
        final goToSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('دسترسی میکروفون'),
            content: const Text(
              'دسترسی میکروفون دائماً رد شده است. برای ادامه، از '
              'تنظیمات برنامه آن را فعال کنید.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('بعداً'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('باز کردن تنظیمات'),
              ),
            ],
          ),
        );
        if (goToSettings == true) {
          await openAppSettings();
        }
        return false;
      }

      _showSnack('دسترسی به میکروفون داده نشد.');
      return false;
    } catch (e) {
      debugPrint('[RecordScreen] permission error: $e');
      _showSnack('در بررسی مجوز میکروفون خطایی رخ داد.');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // منطق اصلی
  // ---------------------------------------------------------------------------

  Future<void> _toggleRecording() async {
    if (_isProcessing) return;

    // همه Providerها را قبل از await می‌گیریم.
    final audioService = _audioService ?? context.read<AudioService>();
    _audioService = audioService;
    final soundAnalyzer = context.read<SoundAnalyzer>();
    final authProvider = context.read<AuthProvider>();
    final apiService = context.read<ApiService>();

    if (_isRecording) {
      await _stopAndProcess(
        audioService: audioService,
        soundAnalyzer: soundAnalyzer,
        authProvider: authProvider,
        apiService: apiService,
      );
    } else {
      await _startRecording(audioService);
    }
  }

  Future<void> _startRecording(AudioService audioService) async {
    final hasPermission = await _requestMicPermission();
    if (!hasPermission || !mounted) return;

    try {
      await audioService.startRecording(
        config: RecordingConfig.engineAnalysis,
      );
      if (!mounted) return;

      _startTimer();
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('[RecordScreen] startRecording failed: $e');
      _showSnack('خطا در شروع ضبط صدا.');
    }
  }

  Future<void> _stopAndProcess({
    required AudioService audioService,
    required SoundAnalyzer soundAnalyzer,
    required AuthProvider authProvider,
    required ApiService apiService,
  }) async {
    _stopTimer();
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    try {
      final info = await audioService.stopRecording();
      if (info == null) throw const _RecordingSaveException();

      if (info.duration.inSeconds < _minRecordingDuration) {
        throw const _ShortRecordingException(_minRecordingDuration);
      }

      final token = authProvider.token;
      if (token == null || token.isEmpty) {
        throw const _MissingTokenException();
      }

      final features = await soundAnalyzer.analyze(info.filePath);
      if (!mounted) return;

      final audioFeatures = '''
RMS: ${features.rms.toStringAsFixed(4)}
Dominant frequency: ${features.dominantFrequency.toStringAsFixed(1)} Hz
Spectral centroid: ${features.spectralCentroid.toStringAsFixed(1)} Hz
Noise level: ${features.noiseLevel.label}
Zero crossing rate: ${features.zeroCrossingRate.toStringAsFixed(4)}
Spectral rolloff: ${features.spectralRolloff.toStringAsFixed(1)} Hz
SNR: ${features.snr.toStringAsFixed(1)} dB
'''.trim();

      final diagnosis = await apiService.uploadAudioAndDiagnoseDetailed(
        token,
        filePath: info.filePath,
        carId: widget.carId,
        year: widget.year,
        carName: widget.carName,
        audioFeatures: audioFeatures,
      );
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
            initialDiagnosisResult: diagnosis.result,
            initialDiagnosticId: diagnosis.diagnosticId,
            initialStructuredResult: diagnosis.structured,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('[RecordScreen] process failed: $e\n$st');
      if (!mounted) return;

      final msg = switch (e) {
        _ShortRecordingException() => e.toString(),
        _RecordingSaveException() => e.toString(),
        _MissingTokenException() => e.toString(),
        _ => 'خطا در پردازش صدا. لطفاً دوباره تلاش کنید.',
      };
      _showSnack(msg);

      setState(() {
        _isProcessing = false;
        _secondsElapsed = 0;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

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
                if (!_isRecording && !_isProcessing)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.secondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.secondary
                            .withOpacity(0.2),
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
                          'موتور را روشن کنید و گوشی را نزدیک محفظه موتور '
                          'نگه دارید.\n'
                          'حداقل $_minRecordingDuration و حداکثر '
                          '$_maxRecordingDuration ثانیه ضبط کنید.',
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

                ScaleTransition(
                  scale: _isRecording ? _scaleAnim : _stillScale,
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
