import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'shop_screen.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  final String carName;
  final String carId;
  final String year;
  final String initialUserMessage;
  final bool isCustomCar;

  const ChatScreen({
    super.key,
    required this.carName,
    required this.carId,
    required this.year,
    required this.initialUserMessage,
    this.isCustomCar = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      "isUser": true,
      "text":
          "ماشینم ${widget.carName} مدل ${widget.year} است.\nمشکل: ${widget.initialUserMessage}"
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDiagnosis(widget.initialUserMessage);
    });
  }

  Future<void> _fetchDiagnosis(String description) async {
    setState(() => _isTyping = true);
    _scrollToBottom();

    final auth = context.read<AuthProvider>();
    final api = context.read<ApiService>();

    try {
      final result = await api.diagnose(
        auth.token!,
        widget.carId,
        description,
        year: widget.year,
        carName: widget.isCustomCar ? widget.carName : null,
      );

      auth.fetchProfile();

      if (!mounted) return;
      setState(() {
        _messages.add({"isUser": false, "text": result});
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 402) {
        _showErrorSystemMessage(
            'اعتبار شما کافی نیست. لطفاً حساب خود را شارژ کنید.');
        _showNoCreditDialog();
      } else if (e.statusCode == 401) {
        auth.logout();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        _showErrorSystemMessage(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSystemMessage(
          'خطا در ارتباط با سرور. لطفاً اینترنت خود را بررسی کنید.');
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _scrollToBottom();
      }
    }
  }

  void _showErrorSystemMessage(String error) {
    setState(() {
      _messages.add({"isUser": false, "isError": true, "text": "⚠️ خطا: $error"});
    });
  }

  void _retryLastRequest() {
    if (_messages.isEmpty) return;

    setState(() {
      _messages.removeLast();
    });

    String lastUserMsg = widget.initialUserMessage;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i]['isUser'] == true) {
        lastUserMsg = _messages[i]['text'];
        break;
      }
    }

    _fetchDiagnosis(lastUserMsg);
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();

    if (!auth.isGolden && auth.credits <= 0) {
      _showNoCreditDialog();
      return;
    }

    setState(() {
      _messages.add({"isUser": true, "text": text});
      _chatController.clear();
    });

    _fetchDiagnosis(text);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showNoCreditDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: Text('اعتبار ناکافی',
            style: TextStyle(color: theme.textTheme.titleLarge?.color)),
        content: Text(
            'برای ادامه گفتگو و عیب‌یابی دقیق، نیاز به تهیه اعتبار دارید.',
            style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopScreen()),
              );
            },
            child: const Text('تهیه اعتبار'),
          ),
        ],
      ),
    );
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
              child:
                  const Icon(Icons.support_agent_rounded, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مکانیک هوشمند',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '${widget.carName} · ${widget.year}',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
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
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator(theme);
                }

                final msg = _messages[index];
                final isLastMessage = index == _messages.length - 1;

                return _buildChatBubble(
                  msg['text'],
                  msg['isUser'] == true,
                  msg['isError'] == true,
                  isLastMessage,
                  theme,
                );
              },
            ),
          ),
          _buildChatInput(theme),
        ],
      ),
    );
  }

  Widget _buildChatBubble(
    String text,
    bool isUser,
    bool isError,
    bool isLastMessage,
    ThemeData theme,
  ) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary.withOpacity(0.2)
              : (isError ? Colors.red.withOpacity(0.15) : theme.cardColor),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
          border: Border.all(
            color: isUser
                ? theme.colorScheme.primary.withOpacity(0.5)
                : (isError
                    ? Colors.redAccent.withOpacity(0.5)
                    : theme.dividerColor),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isUser || isError
                ? SelectableText(
                    text,
                    style: TextStyle(
                      height: 1.6,
                      fontSize: 14,
                      color: isError
                          ? Colors.redAccent
                          : (isUser ? Colors.white : Colors.white70),
                    ),
                    textDirection: TextDirection.rtl,
                  )
                : MarkdownBody(
                    data: text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                          fontSize: 14, height: 1.6, color: Colors.white),
                      h1: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber),
                      h2: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange),
                      listBullet: const TextStyle(color: Colors.orange),
                    ),
                  ),
            if (isError && isLastMessage) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _retryLastRequest,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('تلاش مجدد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            Text('مکانیک هوشمند در حال بررسی...',
                style: TextStyle(color: theme.hintColor, fontSize: 12)),
          ],
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
              enabled: !_isTyping,
              decoration: InputDecoration(
                hintText: _isTyping ? 'لطفاً صبر کنید...' : 'سوال دیگری دارید؟...',
                filled: true,
                fillColor: theme.cardColor,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor:
                _isTyping ? theme.disabledColor : theme.colorScheme.primary,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _isTyping ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
