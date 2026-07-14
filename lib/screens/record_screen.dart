import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../services/sound_analyzer.dart';
import '../models/audio_features.dart';
import 'result_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    if (_isRecording) {
      context.read<AudioService>().stopRecording(); // ignore: use_build_context_synchronously
    }
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final audioService = context.read<AudioService>();
    final soundAnalyzer = context.read<SoundAnalyzer>();

    if (_isRecording) {
      try {
        setState(() {
          _isRecording = false;
          _isProcessing = true;
        });
        
        final filePath = await audioService.stopRecording();
        if (filePath == null) {
          throw Exception('فایل صوتی ذخیره نشد.');
        }

        final AudioFeatures features = await soundAnalyzer.analyze(filePath);

        if (!mounted) return;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              resultText: features.toJson().toString(), 
              audioFeatures: features,
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _errorMessage = 'خطا در تحلیل صدا: $e';
          });
        }
      }
    } else {
      try {
        await audioService.startRecording();
        setState(() {
          _isRecording = true;
          _errorMessage = null;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'خطا در شروع ضبط: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ضبط صدای خودرو'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            GestureDetector(
              onTap: _isProcessing ? null : _toggleRecording,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? Colors.red : theme.colorScheme.secondary,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? Colors.red : theme.colorScheme.secondary).withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 48,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isRecording ? 'در حال ضبط... برای توقف ضربه بزنید' : 'برای شروع ضبط، ضربه بزنید',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onBackground),
            ),
          ],
        ),
      ),
    );
  }
}
