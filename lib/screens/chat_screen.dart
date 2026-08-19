import 'dart:async';
import 'dart:math'; // ✅ ایمپورت استاندارد کتابخانه ریاضی دارت
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'shop_screen.dart';
import 'login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ── مدل پیام ──
// ─────────────────────────────────────────────────────────────────────────────
enum MessageRole { user, assistant, error }

class ChatMessage {
  final String id;
  final String text;
  final MessageRole role;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.role,
    DateTime? timestamp,
  })  : id = DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get isError => role == MessageRole.error;

  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── ChatScreen ──
// ─────────────────────────────────────────────────────────────────────────────
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

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
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
        text: 'ماشینم ${widget.carName} مدل ${widget.year} است.\n'
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

  // ─────────────────────────────────────────
  // ── ارسال به API ──
  // ─────────────────────────────────────────
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

      // آپدیت پروفایل بدون مسدود کردن صفحه
      unawaited(auth.fetchProfile());

      if (!mounted) return;
      _addMessage(ChatMessage(text: result, role: MessageRole.assistant));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 402) {
        // ✅ اصلاح شد: حذف کلمه const
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
    } catch (_) {
      if (!mounted) return;
      // ✅ اصلاح شد: حذف کلمه const
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
    setState(() => _messages.add(msg));
  }

  // ─────────────────────────────────────────
  // ─ـ ارسال پیام کاربر ──
  // ─────────────────────────────────────────
  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isGoldenActive && auth.credits <= 0) {
      _showNoCreditDialog();
      return;
    }

    _addMessage(ChatMessage(text: text, role: MessageRole.user));
    _inputCtrl.clear();
    _focusNode.unfocus();
    _fetchDiagnosis(text);
  }

  // ─────────────────────────────────────────
  // ─ـ تلاش مجدد ──
  // ─────────────────────────────────────────
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

  // ─────────────────────────────────────────
  // ─ـ scroll ──
  // ─────────────────────────────────────────
  void _scrollToBottom() {
    // ✅ استفاده از PostFrameCallback به جای Delay برای دقت بالاتر
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─────────────────────────────────────────
  // ─ـ کپی متن ──
  // ─────────────────────────────────────────
  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('متن کپی شد'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─────────────────────────────────────────
  // ─ـ اشتراک‌گذاری ──
  // ─────────────────────────────────────────
  void _shareMessage(String text) {
    Share.share(
      '🔧 نتیجه عیب‌یابی ${widget.carName} (${widget.year}):\n\n$text',
      subject: 'عیب‌یابی مکانیک هوشمند',
    );
  }

  // ─────────────────────────────────────────
  // ─ـ دیالوگ اعتبار ناکافی ──
  // ─────────────────────────────────────────
  void _showNoCreditDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'اعتبار ناکافی',
          style: TextStyle(color: theme.textTheme.titleLarge?.color),
        ),
        content: Text(
          'برای ادامه گفتگو، نیاز به تهیه اعتبار دارید.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
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

  // ─────────────────────────────────────────
  // ─ـ build ──
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.secondary,
              radius: 18,
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.black,
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.carName} · ${widget.year}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!auth.isGoldenActive)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: auth.credits > 0
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: auth.credits > 0 ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${auth.credits} اعتبار',
                    style: TextStyle(
                      fontSize: 12,
                      color: auth.credits > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: Text('⭐ طلایی',
                    style: TextStyle(fontSize: 12, color: Colors.amber)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCarInfoBanner(theme),
            Expanded(child: _buildMessageList(theme)),
            _buildInputArea(theme),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // ─ـ نوار اطلاعات خودرو ──
  // ─────────────────────────────────────────
  Widget _buildCarInfoBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.primary.withOpacity(0.07),
      child: Row(
        children: [
          Icon(
            Icons.directions_car_rounded,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.carName} · ${widget.year}',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${_messages.where((m) => m.isUser).length} پیام ارسالی',
            style: TextStyle(fontSize: 11, color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // ─ـ لیست پیام‌ها ──
  // ─────────────────────────────────────────
  Widget _buildMessageList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollCtrl,
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
    );
  }

  // ─────────────────────────────────────────
  // ─ـ آیتم پیام با انیمیشن و long press ──
  // ─────────────────────────────────────────
  Widget _buildMessageItem(ChatMessage msg, bool isLast, ThemeData theme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg),
        child: Align(
          alignment:
              msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: _bubbleColor(msg, theme),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(msg.isUser ? 18 : 2),
                bottomRight: Radius.circular(msg.isUser ? 2 : 18),
              ),
              border: Border.all(color: _bubbleBorder(msg, theme)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMessageContent(msg, theme),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Spacer(),
                    Text(
                      msg.timeLabel,
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.hintColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                if (msg.isError && isLast) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _retryLast,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('تلاش مجدد'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.redAccent),
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

  // ─────────────────────────────────────────
  // ─ـ محتوای پیام (Markdown) ──
  // ─────────────────────────────────────────
  Widget _buildMessageContent(ChatMessage msg, ThemeData theme) {
    if (msg.isUser) {
      return SelectableText(
        msg.text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Colors.white,
        ),
        textDirection: TextDirection.rtl,
      );
    }

    if (msg.isError) {
      return SelectableText(
        '⚠️ ${msg.text}',
        style: const TextStyle(
          fontSize: 13,
          height: 1.6,
          color: Colors.redAccent,
        ),
        textDirection: TextDirection.rtl,
      );
    }

    // ✅ استفاده از رنگ‌های داینامیک تم برای جلوگیری از نامرئی شدن متن در تم روشن
    return MarkdownBody(
      data: msg.text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 14, 
          height: 1.7, 
          color: theme.textTheme.bodyLarge?.color ?? Colors.black87
        ),
        h1: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
        ),
        h2: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
        ),
        h3: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
        ),
        listBullet: TextStyle(color: theme.colorScheme.secondary),
        code: TextStyle(
          backgroundColor: theme.dividerColor.withOpacity(0.3),
          color: theme.colorScheme.error,
          fontFamily: 'monospace',
        ),
        blockquote: TextStyle(
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
          fontSize: 13,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // ─ـ منوی Long Press ──
  // ─────────────────────────────────────────
  void _showMessageOptions(ChatMessage msg) {
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
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('کپی متن'),
              onTap: () {
                Navigator.pop(ctx);
                _copyMessage(msg.text);
              },
            ),
            if (msg.isAssistant) ...[
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('اشتراک‌گذاری'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareMessage(msg.text);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // ─ـ رنگ‌های حباب ──
  // ─────────────────────────────────────────
  Color _bubbleColor(ChatMessage msg, ThemeData theme) {
    if (msg.isUser) return theme.colorScheme.primary.withOpacity(0.2);
    if (msg.isError) return Colors.red.withOpacity(0.12);
    return theme.cardColor;
  }

  Color _bubbleBorder(ChatMessage msg, ThemeData theme) {
    if (msg.isUser) return theme.colorScheme.primary.withOpacity(0.4);
    if (msg.isError) return Colors.redAccent.withOpacity(0.4);
    return theme.dividerColor;
  }

  // ─────────────────────────────────────────
  // ─ـ typing indicator با نقطه‌های متحرک ──
  // ─────────────────────────────────────────
  Widget _buildTypingIndicator(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ استفاده از توابع استاندارد دارت (dart:math)
            ...List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _dotAnimCtrl,
                builder: (_, __) {
                  // محاسبه تاخیر برای هر نقطه
                  final delay = i * 0.2;
                  final t = (_dotAnimCtrl.value - delay) % 1.0;
                  // استفاده از sin و pi استاندارد و سریع
                  final scale = 0.5 + 0.5 * sin(t * pi);
                  
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.4 + 0.6 * scale),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              );
            }),
            const SizedBox(width: 10),
            Text(
              'در حال تحلیل...',
              style: TextStyle(color: theme.hintColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // ─ـ ناحیه ورودی ──
  // ─────────────────────────────────────────
  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
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
              onSubmitted: (_) => _sendMessage(),
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: _isTyping ? 'لطفاً صبر کنید...' : 'سوال دیگری دارید؟',
                hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: theme.colorScheme.secondary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _isTyping
                  ? theme.disabledColor
                  : theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
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
