import 'package:flutter/material.dart';

import '../../models/chat_message.dart';

/// حباب چت ساده — برای پیام‌های متنی (کاربر/دستیار/سیستم).
/// برای نتیجهٔ ساختاریافتهٔ تشخیص از DiagnosisResultCard استفاده می‌شود.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.highlighted = false,
    this.onRetry,
  });

  final ChatMessage message;
  final bool highlighted;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;
    final isSystem = message.role == MessageRole.system;

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
      decoration: BoxDecoration(
        color: isSystem
            ? Colors.red.withOpacity(0.12)
            : isUser
                ? Colors.orange.withOpacity(0.22)
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: highlighted ? Border.all(color: Colors.orange.withOpacity(0.45), width: 1.2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            message.text,
            style: TextStyle(height: 1.55, fontSize: 14, color: isSystem ? Colors.redAccent.shade100 : null),
          ),
          if (isSystem && onRetry != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 14, color: Colors.redAccent),
                    SizedBox(width: 4),
                    Text('تلاش دوباره',
                        style: TextStyle(fontSize: 12.5, color: Colors.redAccent, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );
  }
}
