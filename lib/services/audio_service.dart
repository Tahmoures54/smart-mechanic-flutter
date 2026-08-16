import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ── تنظیمات ضبط ──
// ─────────────────────────────────────────────────────────────────────────────
class RecordingConfig {
  final Codec codec;
  final int bitRate;        // bps
  final int sampleRate;     // Hz
  final int numChannels;    // 1=mono, 2=stereo
  final Duration maxDuration;
  final Duration minDuration;

  const RecordingConfig({
    this.codec = Codec.aacADTS,
    this.bitRate = 128000,
    this.sampleRate = 44100,
    this.numChannels = 1,
    this.maxDuration = const Duration(minutes: 2),
    this.minDuration = const Duration(seconds: 2),
  });

  /// پیش‌فرض برای آنالیز موتور (کیفیت بالا)
  static const engineAnalysis = RecordingConfig(
    codec: Codec.aacADTS,
    bitRate: 192000,
    sampleRate: 44100,
    numChannels: 1,
    maxDuration: Duration(seconds: 30),
    minDuration: Duration(seconds: 3),
  );

  /// پیش‌فرض برای ضبط عمومی (حجم کمتر)
  static const general = RecordingConfig(
    codec: Codec.aacADTS,
    bitRate: 96000,
    sampleRate: 22050,
    numChannels: 1,
    maxDuration: Duration(minutes: 5),
    minDuration: Duration(seconds: 1),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ── اطلاعات ضبط ──
// ─────────────────────────────────────────────────────────────────────────────
class RecordingInfo {
  final String filePath;
  final Duration duration;
  final int fileSizeBytes;
  final DateTime startTime;
  final DateTime endTime;
  final RecordingConfig config;

  const RecordingInfo({
    required this.filePath,
    required this.duration,
    required this.fileSizeBytes,
    required this.startTime,
    required this.endTime,
    required this.config,
  });

  double get fileSizeKB => fileSizeBytes / 1024;
  double get fileSizeMB => fileSizeBytes / (1024 * 1024);

  bool get isValid =>
      duration >= config.minDuration && fileSizeBytes > 0;

  File get file => File(filePath);

  @override
  String toString() => 'RecordingInfo('
      'duration=${duration.inSeconds}s, '
      'size=${fileSizeKB.toStringAsFixed(1)}KB)';
}

// ─────────────────────────────────────────────────────────────────────────────
// ── وضعیت ضبط ──
// ─────────────────────────────────────────────────────────────────────────────
enum RecordingState {
  idle,       // آماده
  recording,  // در حال ضبط
  paused,     // متوقف موقت
  processing, // در حال پردازش
  done,       // تمام‌شده
  error;      // خطا

  bool get isActive => this == recording || this == paused;
  bool get canStart => this == idle || this == done || this == error;
  bool get canStop => this == recording || this == paused;
  bool get canPause => this == recording;
  bool get canResume => this == paused;
}

// ─────────────────────────────────────────────────────────────────────────────
// ── اینترفیس ──
// ─────────────────────────────────────────────────────────────────────────────
abstract interface class IAudioService {
  Future<void> init();
  Future<bool> requestPermission();
  Future<void> startRecording({RecordingConfig? config});
  Future<RecordingInfo?> stopRecording();
  Future<void> pauseRecording();
  Future<void> resumeRecording();
  Future<void> cancelRecording();
  Future<void> dispose();

  RecordingState get state;
  bool get isRecording;
  bool get isPaused;
  String? get filePath;

  Stream<Duration> get durationStream;
  Stream<double> get amplitudeStream; // 0.0 - 1.0
  Stream<RecordingState> get stateStream;
}

// ─────────────────────────────────────────────────────────────────────────────
// ── پیاده‌سازی ──
// ─────────────────────────────────────────────────────────────────────────────
class AudioService implements IAudioService {
  final FlutterSoundRecorder _recorder;

  // ── وضعیت داخلی ──
  RecordingState _state = RecordingState.idle;
  bool _isInitialized = false;
  Directory? _tempDir;
  String? _filePath;
  DateTime? _startTime;
  DateTime? _pauseTime;
  Duration _pausedDuration = Duration.zero;
  RecordingConfig _config = const RecordingConfig();

  // ── streams ──
  final _stateCtrl = StreamController<RecordingState>.broadcast();
  final _durationCtrl = StreamController<Duration>.broadcast();
  final _amplitudeCtrl = StreamController<double>.broadcast();

  // ── تایمر مدت ضبط ──
  Timer? _durationTimer;
  Timer? _maxDurationTimer;

  AudioService({FlutterSoundRecorder? recorder})
      : _recorder = recorder ?? FlutterSoundRecorder();

  // ─────────────────────────────────────────
  // ── Getters ──
  // ─────────────────────────────────────────
  @override
  RecordingState get state => _state;

  @override
  bool get isRecording => _state == RecordingState.recording;

  @override
  bool get isPaused => _state == RecordingState.paused;

  @override
  String? get filePath => _filePath;

  @override
  Stream<Duration> get durationStream => _durationCtrl.stream;

  @override
  Stream<double> get amplitudeStream => _amplitudeCtrl.stream;

  @override
  Stream<RecordingState> get stateStream => _stateCtrl.stream;

  /// مدت ضبط تا الان
  Duration get elapsed {
    if (_startTime == null) return Duration.zero;
    final base = DateTime.now().difference(_startTime!);
    return base - _pausedDuration;
  }

  // ─────────────────────────────────────────
  // ── مقداردهی اولیه ──
  // ─────────────────────────────────────────
  @override
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _tempDir = await getTemporaryDirectory();
      await _recorder.openRecorder();

      // ── stream سطح صدا از flutter_sound ──
      _recorder.onProgress!.listen((event) {
        if (event.decibels != null && !_amplitudeCtrl.isClosed) {
          // تبدیل dB به 0.0-1.0 (محدوده -60 تا 0 dB)
          final normalized = ((event.decibels! + 60) / 60).clamp(0.0, 1.0);
          _amplitudeCtrl.add(normalized);
        }
      });

      await _recorder.setSubscriptionDuration(
        const Duration(milliseconds: 100),
      );

      _isInitialized = true;
      debugPrint('[AudioService] مقداردهی اولیه موفق');
    } catch (e) {
      _isInitialized = false;
      debugPrint('[AudioService] خطا در مقداردهی: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────
  // ── درخواست مجوز ──
  // ─────────────────────────────────────────
  @override
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();

    if (status.isPermanentlyDenied) {
      debugPrint('[AudioService] مجوز میکروفون دائماً رد شده.');
      await openAppSettings();
    }

    return status.isGranted;
  }

  // ─────────────────────────────────────────
  // ── شروع ضبط ──
  // ─────────────────────────────────────────
  @override
  Future<void> startRecording({RecordingConfig? config}) async {
   _config = config ?? RecordingConfig.engineAnalysis;

    if (!_isInitialized) {
      throw AudioServiceException(
        'AudioService مقداردهی نشده. ابتدا init() را صدا بزنید.',
        AudioServiceError.notInitialized,
      );
    }

    if (!_state.canStart) {
      throw AudioServiceException(
        'ضبط در حال انجام است.',
        AudioServiceError.alreadyRecording,
      );
    }

    // ── بررسی مجوز ──
    final hasPermission = await Permission.microphone.isGranted;
    if (!hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        throw AudioServiceException(
          'مجوز دسترسی به میکروفون داده نشده است.',
          AudioServiceError.permissionDenied,
        );
      }
    }

    // ── بررسی فضای دیسک ──
    await _checkDiskSpace();

    try {
      // ── ساخت مسیر فایل ──
      final ts = DateTime.now().millisecondsSinceEpoch;
      _filePath = '${_tempDir!.path}/engine_$ts.aac';
      _startTime = DateTime.now();
      _pausedDuration = Duration.zero;

      await _recorder.startRecorder(
        toFile: _filePath,
        codec: _config.codec,
        bitRate: _config.bitRate,
        sampleRate: _config.sampleRate,
        numChannels: _config.numChannels,
      );

      _changeState(RecordingState.recording);
      _startDurationTimer();
      _startMaxDurationTimer();

      debugPrint('[AudioService] ضبط شروع شد: $_filePath');
    } catch (e) {
      _filePath = null;
      _startTime = null;
      _changeState(RecordingState.error);
      rethrow;
    }
  }

  // ─────────────────────────────────────────
  // ── توقف ضبط ──
  // ─────────────────────────────────────────
  @override
  Future<RecordingInfo?> stopRecording() async {
    if (!_state.canStop) {
      if (_filePath != null) {
        return _buildRecordingInfo();
      }
      return null;
    }

    _changeState(RecordingState.processing);
    _stopTimers();

    try {
      final recordedPath = await _recorder.stopRecorder();
      final path = recordedPath ?? _filePath;

      if (path == null) {
        _changeState(RecordingState.error);
        return null;
      }

      final file = File(path);
      if (!await file.exists()) {
        _changeState(RecordingState.error);
        return null;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        _changeState(RecordingState.error);
        throw AudioServiceException(
          'فایل ضبط شده خالی است.',
          AudioServiceError.emptyFile,
        );
      }

      final info = RecordingInfo(
        filePath: path,
        duration: elapsed,
        fileSizeBytes: fileSize,
        startTime: _startTime!,
        endTime: DateTime.now(),
        config: _config,
      );

      // ── بررسی حداقل مدت ──
      if (!info.isValid) {
        await _deleteFile(path);
        _changeState(RecordingState.idle);
        throw AudioServiceException(
          'مدت ضبط خیلی کوتاه است. حداقل '
          '${_config.minDuration.inSeconds} ثانیه ضبط کنید.',
          AudioServiceError.tooShort,
        );
      }

      _changeState(RecordingState.done);
      debugPrint('[AudioService] ضبط تمام شد: $info');
      return info;
    } catch (e) {
      if (e is! AudioServiceException) {
        _changeState(RecordingState.error);
      }
      rethrow;
    }
  }

  // ─────────────────────────────────────────
  // ── مکث ──
  // ─────────────────────────────────────────
  @override
  Future<void> pauseRecording() async {
    if (!_state.canPause) return;

    try {
      await _recorder.pauseRecorder();
      _pauseTime = DateTime.now();
      _stopDurationTimer();
      _changeState(RecordingState.paused);
      debugPrint('[AudioService] ضبط متوقف شد.');
    } catch (e) {
      debugPrint('[AudioService] خطا در مکث: $e');
    }
  }

  // ─────────────────────────────────────────
  // ── ادامه ──
  // ─────────────────────────────────────────
  @override
  Future<void> resumeRecording() async {
    if (!_state.canResume) return;

    try {
      await _recorder.resumeRecorder();

      // ── محاسبه مدت pause ──
      if (_pauseTime != null) {
        _pausedDuration += DateTime.now().difference(_pauseTime!);
        _pauseTime = null;
      }

      _startDurationTimer();
      _changeState(RecordingState.recording);
      debugPrint('[AudioService] ضبط از سر گرفته شد.');
    } catch (e) {
      debugPrint('[AudioService] خطا در ادامه: $e');
    }
  }

  // ─────────────────────────────────────────
  // ── لغو ──
  // ─────────────────────────────────────────
  @override
  Future<void> cancelRecording() async {
    _stopTimers();

    try {
      if (_recorder.isRecording || _recorder.isPaused) {
        await _recorder.stopRecorder();
      }
    } catch (_) {}

    await _deleteCurrentFile();
    _resetState();
    _changeState(RecordingState.idle);
    debugPrint('[AudioService] ضبط لغو شد.');
  }

  // ─────────────────────────────────────────
  // ── حذف فایل ضبط ──
  // ─────────────────────────────────────────
  Future<void> deleteRecordedFile() async {
    await _deleteCurrentFile();
  }

  Future<void> _deleteCurrentFile() async {
    if (_filePath != null) {
      await _deleteFile(_filePath!);
      _filePath = null;
    }
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[AudioService] فایل حذف شد: $path');
      }
    } catch (e) {
      debugPrint('[AudioService] خطا در حذف فایل: $e');
    }
  }

  // ─────────────────────────────────────────
  // ── بررسی فضای دیسک ──
  // ─────────────────────────────────────────
  Future<void> _checkDiskSpace() async {
    try {
      if (_tempDir == null) return;
      final stat = await _tempDir!.stat();
      // حداقل 50MB فضای آزاد
      const minRequired = 50 * 1024 * 1024;
      if (stat.size < minRequired) {
        throw AudioServiceException(
          'فضای ذخیره‌سازی کافی نیست.',
          AudioServiceError.insufficientStorage,
        );
      }
    } on AudioServiceException {
      rethrow;
    } catch (_) {
      // اگر بررسی ممکن نبود، ادامه بده
    }
  }

  // ─────────────────────────────────────────
  // ── تایمرها ──
  // ─────────────────────────────────────────
  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) {
        if (!_durationCtrl.isClosed) {
          _durationCtrl.add(elapsed);
        }
      },
    );
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _startMaxDurationTimer() {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(
      _config.maxDuration,
      () async {
        debugPrint('[AudioService] حداکثر زمان ضبط رسید. توقف خودکار...');
        await stopRecording();
      },
    );
  }

  void _stopTimers() {
    _durationTimer?.cancel();
    _maxDurationTimer?.cancel();
    _durationTimer = null;
    _maxDurationTimer = null;
  }

  // ─────────────────────────────────────────
  // ── کمکی ──
  // ─────────────────────────────────────────
  void _changeState(RecordingState newState) {
    _state = newState;
    if (!_stateCtrl.isClosed) {
      _stateCtrl.add(newState);
    }
  }

  void _resetState() {
    _startTime = null;
    _pauseTime = null;
    _pausedDuration = Duration.zero;
    _filePath = null;
  }

  RecordingInfo? _buildRecordingInfo() {
    if (_filePath == null || _startTime == null) return null;
    final file = File(_filePath!);
    return RecordingInfo(
      filePath: _filePath!,
      duration: elapsed,
      fileSizeBytes: file.existsSync() ? file.lengthSync() : 0,
      startTime: _startTime!,
      endTime: DateTime.now(),
      config: _config,
    );
  }

  // ─────────────────────────────────────────
  // ── dispose ──
  // ─────────────────────────────────────────
  @override
  Future<void> dispose() async {
    _stopTimers();

    try {
      if (_recorder.isRecording || _recorder.isPaused) {
        await _recorder.stopRecorder();
      }
      await _recorder.closeRecorder();
    } catch (e) {
      debugPrint('[AudioService] خطا در بستن recorder: $e');
    }

    await _deleteCurrentFile();
    _resetState();

    await Future.wait([
      _stateCtrl.close(),
      _durationCtrl.close(),
      _amplitudeCtrl.close(),
    ]);

    _isInitialized = false;
    debugPrint('[AudioService] dispose شد.');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── خطاهای اختصاصی ──
// ─────────────────────────────────────────────────────────────────────────────
enum AudioServiceError {
  notInitialized,
  permissionDenied,
  alreadyRecording,
  notRecording,
  emptyFile,
  tooShort,
  insufficientStorage,
  recorderError;

  String get message => switch (this) {
        AudioServiceError.notInitialized =>
          'سرویس صدا مقداردهی نشده است.',
        AudioServiceError.permissionDenied =>
          'مجوز میکروفون داده نشده است.',
        AudioServiceError.alreadyRecording =>
          'در حال ضبط هستید.',
        AudioServiceError.notRecording =>
          'ضبطی در جریان نیست.',
        AudioServiceError.emptyFile =>
          'فایل ضبط خالی است.',
        AudioServiceError.tooShort =>
          'مدت ضبط خیلی کوتاه است.',
        AudioServiceError.insufficientStorage =>
          'فضای کافی ندارید.',
        AudioServiceError.recorderError =>
          'خطا در ضبط‌کننده.',
      };
}

class AudioServiceException implements Exception {
  final String message;
  final AudioServiceError error;

  const AudioServiceException(this.message, this.error);

  @override
  String toString() => 'AudioServiceException(${error.name}): $message';
}
