import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// اینترفیس سرویس ضبط صدا (برای رعایت اصل وارونگی وابستگی - DIP)
abstract interface class IAudioRecorderService {
  Future<void> init();
  Future<bool> requestPermission();
  Future<void> startRecording();
  Future<File?> stopRecording();
  bool get isRecording;
  String? get filePath;
}

/// سرویس ضبط صدا
class AudioRecorderService implements IAudioRecorderService {
  final FlutterSoundRecorder _recorder;
  
  Directory? _tempDir;
  String? _filePath;
  bool _isInitialized = false;

  AudioRecorderService({FlutterSoundRecorder? recorder})
      : _recorder = recorder ?? FlutterSoundRecorder();

  @override
  bool get isRecording => _recorder.isRecording;

  @override
  String? get filePath => _filePath;

  /// مقداردهی اولیه سرویس (باز کردن ریکوردر)
  @override
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // دریافت مسیر temp
      _tempDir = await getTemporaryDirectory();
      
      // باز کردن ریکوردر (جایگزین initialize در نسخه 9.x+)
      await _recorder.openRecorder();
      
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  /// درخواست مجوز میکروفون
  @override
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    
    return status.isGranted;
  }

  /// شروع ضبط صدا
  @override
  Future<void> startRecording() async {
    // بررسی‌های اولیه
    if (!_isInitialized) {
      throw StateError(
        'AudioRecorderService هنوز مقداردهی اولیه نشده است. ابتدا init() را فراخوانی کنید.',
      );
    }
    
    // بررسی مجوز
    final hasPermission = await Permission.microphone.isGranted;
    
    if (!hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        throw PermissionDeniedException('مجوز دسترسی به میکروفون داده نشده است');
      }
    }
    
    // اگر در حال ضبط است، توقف نده و خطا نده. فقط از ادامه جلوگیری کن
    if (_recorder.isRecording) {
      throw StateError('در حال حاضر در حال ضبط صدا هستید.');
    }
    
    try {
      // ایجاد مسیر فایل موقت
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'recording_$timestamp.aac';
      
      _filePath = '${_tempDir!.path}/$fileName';
      
      // شروع ضبط
      await _recorder.startRecorder(
        toFile: _filePath,
        codec: Codec.aacADTS,
        bitRate: 128000, // بهینه‌سازی کیفیت/حجم
        numChannels: 1,   // برای تحلیل صدا موتور، مونو کافی است
      );
    } catch (e) {
      _filePath = null;
      rethrow;
    }
  }

  /// توقف ضبط و برگرداندن فایل
  /// 
  /// خروجی: فایل ضبط شده یا null در صورت عدم موفقیت
  @override
  Future<File?> stopRecording() async {
    if (!_isInitialized) return null;
    
    if (!_recorder.isRecording) {
      // اگر در حال ضبط نیست، فایل فعلی را برگردان (در صورت وجود)
      if (_filePath != null) return File(_filePath!);
      return null;
    }
    
    try {
      // توقف ضبط
      final recordedPath = await _recorder.stopRecorder();
      
      if (recordedPath == null || _filePath == null) return null;
      
      final file = File(recordedPath);
      
      // اعتبارسنجی فایل
      if (!await file.exists() || await file.length() == 0) return null;
      
      return file;
    } finally {
      // مسیر فایل را نگه می‌داریم تا بعدا بتوانیم آن را حذف کنیم
      // _filePath را پاک نکنیم! چون نیاز به حذف فایل بعد از آپلود داریم
    }
  }

  /// بستن ریکوردر و آزادسازی منابع
  /// 
  /// نکته: این متد در اینترفیس نیست چون مربوط به چرخه حیات پیاده‌سازی است
  Future<void> dispose() async {
    if (!_isInitialized) return;
    
    try {
      // اگر در حال ضبط است، ابتدا توقف کن
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }
      
      // بستن ریکوردر (آزادسازی منابع Native)
      await _recorder.closeRecorder();
      
      // حذف فایل موقت (اگر هنوز وجود دارد)
      await _deleteTempFile();
      
    } finally {
      _isInitialized = false;
      _filePath = null;
      _tempDir = null;
    }
  }

  /// حذف فایل موقت از روی دیسک
  Future<void> _deleteTempFile() async {
    if (_filePath == null) return;
    
    try {
      final file = File(_filePath!);
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // اگر فایل حذف نشد، لاگ نکنیم. مهم نیست
      // ممکن است توسط سیستم یا کاربر حذف شده باشد
    }
  }
  
  /// حذف فایل بعد از آپلود موفق به سرور
  Future<void> deleteRecordedFile() async {
    await _deleteTempFile();
    _filePath = null;
  }
}

/// Exception سفارشی برای خطای مجوز
class PermissionDeniedException implements Exception {
  final String message;
  const PermissionDeniedException(this.message);
  
  @override
  String toString() => 'PermissionDeniedException: $message';
}
