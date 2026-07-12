import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';

class ResultScreen extends StatelessWidget {
  final String resultText;
  const ResultScreen({super.key, required this.resultText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text('نتیجه عیب‌یابی'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(resultText),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Markdown(
          data: resultText,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(color: Colors.white, fontSize: 16),
            h1: const TextStyle(color: Colors.orange, fontSize: 22),
            h2: const TextStyle(color: Colors.orange, fontSize: 20),
            strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
            code: const TextStyle(backgroundColor: Colors.grey),
          ),
        ),
      ),
    );
  }
}