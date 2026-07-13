import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String? _tempFilePath;

  Future<bool> init() async {
    await _recorder.initialize(
      mode: PlayerMode.record,
      codec: Codec.aac,
    );
    return true;
  }

  Future<bool> requestPermission() async {
    var status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<String> startRecording() async {
    if (!_isRecording) {
      final dir = await getTemporaryDirectory();
      _tempFilePath = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(
        toFile: _tempFilePath!,
        codec: Codec.aacADTS,
      );
      _isRecording = true;
    }
    return _tempFilePath!;
  }

  Future<void> stopRecording() async {
    if (_isRecording) {
      await _recorder.stopRecorder();
      _isRecording = false;
    }
  }

  Future<String?> getTempFilePath() => _tempFilePath;
  bool get isRecording => _isRecording;
}
