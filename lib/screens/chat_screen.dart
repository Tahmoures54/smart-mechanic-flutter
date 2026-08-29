import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/chat_message.dart';
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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  late final AnimationController _dotAnimCtrl;

  @override
  void initState() {
    super.initState();
    _dotAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _messages.add(
      ChatMessage(
        text:
            'ماشینم ${widget.carName} مدل ${widget.year} است.\n'
            'مشکل: ${widget.initialUserMessage}',
        role: MessageRole.user,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDiagnosis(widget.initialUserMessage);
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _dotAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDiagnosis(String description) async {
    if (!mounted) return;
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

      unawaited(auth.fetchProfile());

      if (!mounted) return;
      _addMessage(ChatMessage(text: result, role: MessageRole.assistant));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 402) {
        _addMessage(ChatMessage(
          text: 'اعتبار شما کافی نیست. لطفاً حساب خود را شارژ کنید.',
          role: MessageRole.error,
        ));
        _showNoCreditDialog();
      } else if (e.statusCode == 401) {
        await auth.logout();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        _addMessage(ChatMessage(text: e.message, role: MessageRole.error));
      }
    } catch (e) {
      debugPrint('Chat error: $e');
      if (!mounted) return;
      _addMessage(ChatMessage(
        text: 'خطا در ارتباط با سرور. لطفاً اینترنت خود را بررسی کنید.',
        role: MessageRole.error,
      ));
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _scrollToBottom();
      }
    }
  }

  void _addMessage(ChatMessage msg) {
    if (!mounted) return;
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;

    final auth = context.read<AuthProvider>();
    if (!auth.canDiagnose) {
      _showNoCreditDialog();
      return;
    }

    _addMessage(ChatMessage(text: text, role: MessageRole.user));
    _inputCtrl.clear();
    _focusNode.unfocus();
    _fetchDiagnosis(text);
  }

  void _retryLast() {
    if (_messages.isEmpty) return;
    if (_messages.last.isError) {
      setState(() => _messages.removeLast());
    }
    final lastUser = _messages.lastWhere(
      (m) => m.isUser,
      orElse: () => ChatMessage(
        text: widget.initialUserMessage,
        role: MessageRole.user,
      ),
    );
    _fetchDiagnosis(lastUser.text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients &&
          _scrollCtrl.position.hasContentDimensions) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('متن کپی شد'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareMessage(String text) {
    Share.share(
      'نتیجه عیب‌یابی ${widget.carName} (${widget.year}):\n\n$text',
      subject: 'عیب‌یابی مکانیک هوشمند',
    );
  }

  void _showNoCreditDialog() {
    if (!mounted) return;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('اعتبار کافی نیست'),
        content: const Text(
          'برای ادامه گفتگو، بسته اعتبار یا اشتراک طلایی بگیرید.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بعداً'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopScreen()),
              );
            },
            child: const Text('مشاهده بسته‌ها'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.secondary,
              radius: 18,
              child: Icon(
                Icons.support_agent_rounded,
                color: theme.colorScheme.onSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مکانیک هوشمند',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${widget.carName} · ${widget.year}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.hintColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Center(child: _buildCreditBadge(auth, theme)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList(theme)),
            if (_isTyping) _buildTypingBanner(theme),
            _buildInputArea(theme, auth, bottomInset),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditBadge(AuthProvider auth, ThemeData theme) {
    if (auth.isGoldenActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.5)),
        ),
        child: const Text(
          'طلایی',
          style: TextStyle(
            fontSize: 12,
            color: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final ok = auth.canDiagnose;
    final label = auth.paidCredits > 0
        ? '${auth.paidCredits} اعتبار'
        : (auth.remainingFree > 0
            ? '${auth.remainingFree} رایگان'
            : 'بدون اعتبار');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShopScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: ok
                ? Colors.green.withOpacity(0.12)
                : Colors.red.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ok ? Colors.green : Colors.redAccent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ok ? Colors.green : Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.secondary.withOpacity(0.08),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'در حال تحلیل مشکل شما...',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: ListView.builder(
        controller: _scrollCtrl,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        itemCount: _messages.length + (_isTyping ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _messages.length && _isTyping) {
            return _buildTypingIndicator(theme);
          }
          final msg = _messages[index];
          final isLast = index == _messages.length - 1;
          return _buildMessageItem(msg, isLast, theme);
        },
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg, bool isLast, ThemeData theme) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(msg.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      builder: (_, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg),
        child: Align(
          alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.88,
            ),
            decoration: BoxDecoration(
              color: _bubbleColor(msg, theme),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                bottomRight: Radius.circular(msg.isUser ? 4 : 18),
              ),
              border: Border.all(color: _bubbleBorder(msg, theme)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMessageContent(msg, theme),
                const SizedBox(height: 4),
                Text(
                  msg.timeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.hintColor.withOpacity(0.7),
                  ),
                ),
                if (msg.isError && isLast) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: _retryLast,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('تلاش مجدد'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage msg, ThemeData theme) {
    if (msg.isUser) {
      return SelectableText(
        msg.text,
        style: TextStyle(
          fontSize: 14,
          height: 1.55,
          color: theme.textTheme.bodyLarge?.color,
        ),
        textDirection: TextDirection.rtl,
      );
    }
    if (msg.isError) {
      return SelectableText(
        msg.text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.55,
          color: Colors.redAccent,
        ),
        textDirection: TextDirection.rtl,
      );
    }

    return MarkdownBody(
      data: msg.text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 14,
          height: 1.65,
          color: theme.textTheme.bodyLarge?.color,
        ),
        h1: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
          height: 1.8,
        ),
        h2: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
          height: 1.7,
        ),
        h3: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
          height: 1.6,
        ),
        listBullet: TextStyle(
          color: theme.colorScheme.secondary,
          fontSize: 14,
        ),
        strong: TextStyle(
          fontWeight: FontWeight.bold,
          color: theme.textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessage msg) {
    if (!mounted) return;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: theme.cardColor,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.copy_rounded, color: theme.colorScheme.secondary),
              title: const Text('کپی متن'),
              onTap: () {
                Navigator.pop(ctx);
                _copyMessage(msg.text);
              },
            ),
            if (msg.isAssistant)
              ListTile(
                leading: Icon(Icons.share_rounded, color: theme.colorScheme.secondary),
                title: const Text('اشتراک‌گذاری'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareMessage(msg.text);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Color _bubbleColor(ChatMessage msg, ThemeData theme) {
    if (msg.isError) return Colors.red.withOpacity(0.12);
    if (msg.isUser) {
      return theme.colorScheme.primary.withOpacity(
        theme.brightness == Brightness.dark ? 0.22 : 0.1,
      );
    }
    return theme.cardColor;
  }

  Color _bubbleBorder(ChatMessage msg, ThemeData theme) {
    if (msg.isError) return Colors.redAccent.withOpacity(0.35);
    if (msg.isUser) return theme.colorScheme.primary.withOpacity(0.3);
    return theme.dividerColor;
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _dotAnimCtrl,
                builder: (_, __) {
                  final delay = i / 3.0;
                  final rawT = (_dotAnimCtrl.value - delay + 1.0) % 1.0;
                  final scale = 0.5 + 0.5 * sin(rawT * pi);
                  final opacity = (0.4 + 0.6 * scale).clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: scale.clamp(0.35, 1.0),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary
                            .withOpacity(opacity),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              );
            }),
            const SizedBox(width: 8),
            Text(
              'در حال تحلیل...',
              style: TextStyle(color: theme.hintColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, AuthProvider auth, double bottomInset) {
    final canSend = !_isTyping && auth.canDiagnose;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? 4 : 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                focusNode: _focusNode,
                enabled: !_isTyping,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (canSend) _sendMessage();
                },
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: _isTyping
                      ? 'لطفاً صبر کنید...'
                      : 'سوال دیگری دارید؟',
                  hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
                  filled: true,
                  fillColor: theme.cardColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: theme.colorScheme.secondary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: Material(
                color: canSend
                    ? theme.colorScheme.secondary
                    : theme.disabledColor.withOpacity(0.35),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: canSend ? _sendMessage : null,
                  child: Center(
                    child: _isTyping
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onSecondary,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: canSend
                                ? theme.colorScheme.onSecondary
                                : theme.hintColor,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
