import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// اینترفیس سرویس ضبط صدا (برای رعایت اصل وارونگی وابستگی - DIP)
abstract interface class IAudioService {
  Future<void> init();
  Future<bool> requestPermission();
  Future<void> startRecording();
  Future<File?> stopRecording();
  bool get isRecording;
  String? get filePath;
}

/// سرویس ضبط صدا
class AudioService implements IAudioService {
  final FlutterSoundRecorder _recorder;
  
  Directory? _tempDir;
  String? _filePath;
  bool _isInitialized = false;

  AudioService({FlutterSoundRecorder? recorder})
      : _recorder = recorder ?? FlutterSoundRecorder();

  @override
  bool get isRecording => _recorder.isRecording;

  @override
  String? get filePath => _filePath;

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _tempDir = await getTemporaryDirectory();
      await _recorder.openRecorder();
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    
    return status.isGranted;
  }

  @override
  Future<void> startRecording() async {
    if (!_isInitialized) {
      throw StateError(
        'AudioService هنوز مقداردهی اولیه نشده است. ابتدا init() را فراخوانی کنید.',
      );
    }
    
    final hasPermission = await Permission.microphone.isGranted;
    
    if (!hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        throw PermissionDeniedException('مجوز دسترسی به میکروفون داده نشده است');
      }
    }
    
    if (_recorder.isRecording) {
      throw StateError('در حال حاضر در حال ضبط صدا هستید.');
    }
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'recording_$timestamp.aac';
      
      _filePath = '${_tempDir!.path}/$fileName';
      
      await _recorder.startRecorder(
        toFile: _filePath,
        codec: Codec.aacADTS,
        bitRate: 128000, 
        numChannels: 1,   
      );
    } catch (e) {
      _filePath = null;
      rethrow;
    }
  }

  @override
  Future<File?> stopRecording() async {
    if (!_isInitialized) return null;
    
    if (!_recorder.isRecording) {
      if (_filePath != null) return File(_filePath!);
      return null;
    }
    
    try {
      final recordedPath = await _recorder.stopRecorder();
      if (recordedPath == null || _filePath == null) return null;
      
      final file = File(recordedPath);
      if (!await file.exists() || await file.length() == 0) return null;
      
      return file;
    } finally {
      // مسیر فایل را نگه می‌داریم تا بعدا بتوانیم آن را حذف کنیم
    }
  }

  Future<void> dispose() async {
    if (!_isInitialized) return;
    
    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }
      await _recorder.closeRecorder();
      await _deleteTempFile();
    } finally {
      _isInitialized = false;
      _filePath = null;
      _tempDir = null;
    }
  }

  Future<void> _deleteTempFile() async {
    if (_filePath == null) return;
    try {
      final file = File(_filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
  
  Future<void> deleteRecordedFile() async {
    await _deleteTempFile();
    _filePath = null;
  }
}

class PermissionDeniedException implements Exception {
  final String message;
  const PermissionDeniedException(this.message);
  
  @override
  String toString() => 'PermissionDeniedException: $message';
}
