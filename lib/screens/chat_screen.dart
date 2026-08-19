import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'shop_screen.dart';
import 'login_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// مدل پیام
// ══════════════════════════════════════════════════════════════════════════════
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
    String? id,
  })  : id = id ??
            '${DateTime.now().microsecondsSinceEpoch}_${_randomSuffix()}',
        timestamp = timestamp ?? DateTime.now();

  /// پسوند تصادفی برای جلوگیری از تکرار id
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

// ══════════════════════════════════════════════════════════════════════════════
// ChatScreen
// ══════════════════════════════════════════════════════════════════════════════
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

    // پیام اولیه کاربر
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

  // ─── ارسال به API ─────────────────────────────────────────────────────────
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

  // ─── ارسال پیام کاربر ────────────────────────────────────────────────────
  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;

    final auth = context.read<AuthProvider>();

    // ✅ سازگار با هر دو نام متد (isGolden / isGoldenActive)
    final isGolden = auth.isGolden;
    if (!isGolden && auth.credits <= 0) {
      _showNoCreditDialog();
      return;
    }

    _addMessage(ChatMessage(text: text, role: MessageRole.user));
    _inputCtrl.clear();
    _focusNode.unfocus();
    _fetchDiagnosis(text);
  }

  // ─── تلاش مجدد ───────────────────────────────────────────────────────────
  void _retryLast() {
    if (_messages.isEmpty) return;

    // حذف پیام خطا
    if (_messages.last.isError) {
      setState(() => _messages.removeLast());
    }

    // آخرین پیام کاربر را پیدا کن
    final lastUser = _messages.lastWhere(
      (m) => m.isUser,
      orElse: () => ChatMessage(
        text: widget.initialUserMessage,
        role: MessageRole.user,
      ),
    );

    _fetchDiagnosis(lastUser.text);
  }

  // ─── اسکرول به پایین ─────────────────────────────────────────────────────
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

  // ─── کپی متن ─────────────────────────────────────────────────────────────
  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('متن کپی شد ✅'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade700,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── اشتراک‌گذاری ─────────────────────────────────────────────────────────
  void _shareMessage(String text) {
    SharePlus.instance.share(
      ShareParams(
        text:
            '🔧 نتیجه عیب‌یابی ${widget.carName} (${widget.year}):\n\n$text',
        subject: 'عیب‌یابی مکانیک هوشمند',
      ),
    );
  }

  // ─── دیالوگ اعتبار ناکافی ────────────────────────────────────────────────
  void _showNoCreditDialog() {
    if (!mounted) return;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade600, size: 28),
            const SizedBox(width: 8),
            Text(
              'اعتبار ناکافی',
              style: TextStyle(color: theme.textTheme.titleLarge?.color),
            ),
          ],
        ),
        content: Text(
          'برای ادامه گفتگو، نیاز به تهیه اعتبار دارید.',
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
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
            child: const Text('تهیه اعتبار'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
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
                color: Colors.black87,
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: auth.isGolden
                  ? const Text(
                      '⭐ طلایی',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : _buildCreditBadge(auth),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCarInfoBanner(theme),
            Expanded(child: _buildMessageList(theme)),
            if (_isTyping) _buildTypingBanner(theme),
            _buildInputArea(theme, auth),
          ],
        ),
      ),
    );
  }

  // ─── نشان اعتبار در AppBar ────────────────────────────────────────────────
  Widget _buildCreditBadge(AuthProvider auth) {
    final hasCredit = auth.credits > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hasCredit
            ? Colors.green.withAlpha(51)
            : Colors.red.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCredit ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Text(
        '${auth.credits} اعتبار',
        style: TextStyle(
          fontSize: 12,
          color: hasCredit ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─── نوار اطلاعات خودرو ──────────────────────────────────────────────────
  Widget _buildCarInfoBanner(ThemeData theme) {
    final sentCount = _messages.where((m) => m.isUser).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.primary.withAlpha(18),
      child: Row(
        children: [
          Icon(
            Icons.directions_car_rounded,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${widget.carName} · ${widget.year}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$sentCount پیام ارسالی',
            style: TextStyle(fontSize: 11, color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  // ─── نوار تایپینگ ─────────────────────────────────────────────────────────
  Widget _buildTypingBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.secondary.withAlpha(20),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'مکانیک هوشمند در حال تحلیل مشکل شماست...',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── لیست پیام‌ها ─────────────────────────────────────────────────────────
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

  // ─── آیتم پیام ───────────────────────────────────────────────────────────
  Widget _buildMessageItem(ChatMessage msg, bool isLast, ThemeData theme) {
    return TweenAnimationBuilder<double>(
      // ✅ key برای جلوگیری از اجرای مجدد انیمیشن روی rebuild
      key: ValueKey(msg.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (_, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
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
                bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                bottomRight: Radius.circular(msg.isUser ? 4 : 18),
              ),
              border: Border.all(
                color: _bubbleBorder(msg, theme),
                width: 1,
              ),
              // ✅ سایه ملایم برای حباب‌ها
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMessageContent(msg, theme),
                const SizedBox(height: 4),
                // زمان پیام
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    msg.timeLabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: theme.hintColor.withAlpha(153),
                    ),
                  ),
                ),
                // دکمه تلاش مجدد برای پیام‌های خطا
                if (msg.isError && isLast) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _retryLast,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('تلاش مجدد'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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

  // ─── محتوای پیام (Markdown / متن) ────────────────────────────────────────
  Widget _buildMessageContent(ChatMessage msg, ThemeData theme) {
    // پیام کاربر
    if (msg.isUser) {
      return SelectableText(
        msg.text,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          // ✅ رنگ متن بر اساس روشنایی رنگ حباب
          color: theme.brightness == Brightness.dark
              ? Colors.white
              : theme.colorScheme.primary,
        ),
        textDirection: TextDirection.rtl,
      );
    }

    // پیام خطا
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

    // پیام دستیار (Markdown)
    return MarkdownBody(
      data: msg.text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 14,
          height: 1.7,
          color: theme.textTheme.bodyLarge?.color,
        ),
        h1: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
          height: 2,
        ),
        h2: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
          height: 2,
        ),
        h3: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
          height: 1.8,
        ),
        listBullet: TextStyle(
          color: theme.colorScheme.secondary,
          fontSize: 14,
        ),
        code: TextStyle(
          backgroundColor: theme.dividerColor.withAlpha(76),
          color: theme.colorScheme.error,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.dividerColor.withAlpha(40),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        blockquote: TextStyle(
          color: theme.textTheme.bodyMedium?.color?.withAlpha(178),
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: theme.colorScheme.secondary,
              width: 4,
            ),
          ),
        ),
        strong: TextStyle(
          fontWeight: FontWeight.bold,
          color: theme.textTheme.bodyLarge?.color,
        ),
        em: TextStyle(
          fontStyle: FontStyle.italic,
          color: theme.textTheme.bodyLarge?.color,
        ),
        tableHead: TextStyle(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
        ),
        tableBody: TextStyle(
          color: theme.textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  // ─── منوی Long Press ──────────────────────────────────────────────────────
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
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // پیش‌نمایش پیام
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                msg.text.length > 80
                    ? '${msg.text.substring(0, 80)}...'
                    : msg.text,
                style: TextStyle(
                  color: theme.hintColor,
                  fontSize: 12,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.copy_rounded,
                  color: theme.colorScheme.primary),
              title: const Text('کپی متن'),
              onTap: () {
                Navigator.pop(ctx);
                _copyMessage(msg.text);
              },
            ),
            if (msg.isAssistant) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.share_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('اشتراک‌گذاری'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareMessage(msg.text);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── رنگ حباب ────────────────────────────────────────────────────────────
  Color _bubbleColor(ChatMessage msg, ThemeData theme) {
    if (msg.isError) return Colors.red.withAlpha(30);
    if (msg.isUser) {
      return theme.brightness == Brightness.dark
          ? theme.colorScheme.primary.withAlpha(60)
          : theme.colorScheme.primary.withAlpha(25);
    }
    return theme.cardColor;
  }

  Color _bubbleBorder(ChatMessage msg, ThemeData theme) {
    if (msg.isError) return Colors.redAccent.withAlpha(100);
    if (msg.isUser) return theme.colorScheme.primary.withAlpha(80);
    return theme.dividerColor;
  }

  // ─── typing indicator ─────────────────────────────────────────────────────
  Widget _buildTypingIndicator(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ نقطه‌های متحرک با محاسبه صحیح (بدون منفی شدن t)
            ...List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _dotAnimCtrl,
                builder: (_, __) {
                  final delay = i / 3.0; // تاخیر بین 0 تا 0.66
                  // ✅ اطمینان از غیر منفی بودن مقدار
                  final rawT =
                      (_dotAnimCtrl.value - delay + 1.0) % 1.0;
                  final scale = 0.5 + 0.5 * sin(rawT * pi);
                  final opacity = (0.4 + 0.6 * scale).clamp(0.0, 1.0);

                  return Transform.scale(
                    scale: scale.clamp(0.3, 1.0),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary
                            .withAlpha((opacity * 255).toInt()),
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
              style: TextStyle(
                color: theme.hintColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ناحیه ورودی ─────────────────────────────────────────────────────────
  Widget _buildInputArea(ThemeData theme, AuthProvider auth) {
    final canSend = !_isTyping && (auth.isGolden || auth.credits > 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // فیلد متن
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
                hintText: _isTyping
                    ? 'لطفاً صبر کنید...'
                    : 'سوال دیگری دارید؟',
                hintStyle:
                    TextStyle(color: theme.hintColor, fontSize: 13),
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
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: theme.dividerColor.withAlpha(100),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // دکمه ارسال
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: canSend
                  ? theme.colorScheme.primary
                  : theme.disabledColor,
              shape: BoxShape.circle,
              boxShadow: canSend
                  ? [
                      BoxShadow(
                        color:
                            theme.colorScheme.primary.withAlpha(76),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: IconButton(
              icon: _isTyping
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withAlpha(200),
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: canSend ? _sendMessage : null,
              tooltip: canSend ? 'ارسال' : 'صبر کنید...',
            ),
          ),
        ],
      ),
    );
  }
}
