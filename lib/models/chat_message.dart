import 'dart:math';

/// نقش پیام در گفتگوی عیب‌یابی
enum MessageRole { user, assistant, error }

/// مدل پیام چت
class ChatMessage {
  final String id;
  final String text;
  final MessageRole role;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.role,
    DateTime? timestamp,
    String? id,
  })  : id = id ??
            '${DateTime.now().microsecondsSinceEpoch}_${_randomSuffix()}',
        timestamp = timestamp ?? DateTime.now();

  static String _randomSuffix() =>
      Random().nextInt(99999).toString().padLeft(5, '0');

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isError => role == MessageRole.error;

  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
