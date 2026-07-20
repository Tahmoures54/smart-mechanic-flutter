import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String carName;
  final String initialUserMessage;
  final String aiResponse;

  const ChatScreen({
    super.key,
    required this.carName,
    required this.initialUserMessage,
    required this.aiResponse,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late List<Map<String, dynamic>> _messages;

  @override
  void initState() {
    super.initState();
    // بارگذاری چت‌های اولیه
    _messages = [
      {"isUser": true, "text": "ماشینم ${widget.carName} است.\nمشکل: ${widget.initialUserMessage}"},
      {"isUser": false, "text": widget.aiResponse},
    ];
  }

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty) return;
    
    // فعلا فقط پیام کاربر را به لیست اضافه می‌کنیم (برای پیاده‌سازی چت دوطرفه در آینده)
    setState(() {
      _messages.add({"isUser": true, "text": _chatController.text.trim()});
      _messages.add({"isUser": false, "text": "رفیق، فعلاً در این نسخه فقط تشخیص اولیه امکان‌پذیره. به زودی قابلیت چت پیوسته هم اضافه میشه! 🛠️"});
      _chatController.clear();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.secondary,
              child: const Icon(Icons.support_agent_rounded, color: Colors.black),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مکانیک هوشمند', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('آنلاین', style: TextStyle(fontSize: 12, color: Colors.greenAccent)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'];
                return _buildChatBubble(msg['text'], isUser, theme);
              },
            ),
          ),
          _buildChatInput(theme),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser, ThemeData theme) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primary.withOpacity(0.2) : theme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
          border: Border.all(
            color: isUser ? theme.colorScheme.primary.withOpacity(0.5) : theme.dividerColor,
          ),
        ),
        child: SelectableText(
          text,
          style: TextStyle(height: 1.6, fontSize: 14, color: isUser ? Colors.white : Colors.white70),
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  Widget _buildChatInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: 'سوال دیگری دارید؟...',
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
