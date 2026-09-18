import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/diagnose_loading_overlay.dart';

/// صفحه چت عیب‌یابی
class ChatScreen extends StatefulWidget {
  final String carName;
  final String carId;
  final String year;
  final String initialUserMessage;
  final bool isCustomCar;
  final String? initialDiagnosisResult;
  final String? initialDiagnosticId;

  const ChatScreen({
    super.key,
    required this.carName,
    required this.carId,
    required this.year,
    required this.initialUserMessage,
    this.isCustomCar = false,
    this.initialDiagnosisResult,
    this.initialDiagnosticId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum MessageRole { user, assistant, system }

class ChatMessage {
  final String text;
  final MessageRole role;
  /// پاسخ اصلی تشخیص — برای اسکرول و تکان
  final bool isDiagnosisResult;

  ChatMessage({
    required this.text,
    required this.role,
    this.isDiagnosisResult = false,
  });
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _started = false;
  String? _lastDiagnosticId;

  /// ایندکس آخرین پاسخ تشخیص برای اسکرول دقیق
  int? _resultMessageIndex;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_started || !mounted) return;
      _started = true;
      _messages.add(ChatMessage(
        text:
            'سلام! دارم مشکل «${widget.carName}» مدل ${widget.year} را بررسی می‌کنم.\nمشکل: ${widget.initialUserMessage}',
        role: MessageRole.assistant,
      ));
      if (widget.initialDiagnosisResult != null &&
          widget.initialDiagnosisResult!.trim().isNotEmpty) {
        _messages.add(ChatMessage(
          text: widget.initialDiagnosisResult!,
          role: MessageRole.assistant,
          isDiagnosisResult: true,
        ));
        _lastDiagnosticId = widget.initialDiagnosticId;
        _resultMessageIndex = _messages.length - 1;
        setState(() {});
        _focusResultAndShake();
      } else {
        setState(() {});
        _fetchDiagnosis(widget.initialUserMessage);
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _addMessage(ChatMessage msg) {
    setState(() => _messages.add(msg));
    if (msg.isDiagnosisResult) {
      _resultMessageIndex = _messages.length - 1;
      _focusResultAndShake();
    } else {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  /// اسکرول به جواب + ویبره خفیف + تکان حباب
  void _focusResultAndShake() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // کمی صبر تا layout حباب جواب کامل شود
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted || !_scrollCtrl.hasClients) return;

      final target = _scrollCtrl.position.maxScrollExtent;
      await _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );

      // بار دوم بعد از paint (متن بلند ممکن است ارتفاع را عوض کند)
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted || !_scrollCtrl.hasClients) return;
      if (_scrollCtrl.position.maxScrollExtent > target + 8) {
        await _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }

      if (!mounted) return;
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
      _shakeCtrl.forward(from: 0);
    });
  }

  Future<void> _fetchDiagnosis(String description) async {
    if (!mounted) return;
    setState(() => _isTyping = true);
    _scrollToBottom();

    final auth = context.read<AuthProvider>();
    final api = context.read<ApiService>();

    try {
      if (auth.token == null || auth.token!.isEmpty) {
        throw const ApiException(401, 'لطفاً دوباره وارد شوید.');
      }

      final response = await api.diagnoseDetailed(
        auth.token!,
        widget.carId,
        description,
        year: widget.year,
        carName: widget.isCustomCar ? widget.carName : null,
        previousDiagnosticId: _lastDiagnosticId,
      );
      final result = response.result;
      _lastDiagnosticId = response.diagnosticId;

      unawaited(auth.fetchProfile());

      if (!mounted) return;
      _addMessage(ChatMessage(
        text: result,
        role: MessageRole.assistant,
        isDiagnosisResult: true,
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 402) {
        _addMessage(ChatMessage(
          text: 'اعتبار شما کافی نیست. لطفاً از فروشگاه بسته بخرید.',
          role: MessageRole.system,
        ));
      } else if (e.statusCode == 401) {
        _addMessage(ChatMessage(
          text: 'نشست شما منقضی شده است. لطفاً دوباره وارد شوید.',
          role: MessageRole.system,
        ));
      } else {
        _addMessage(ChatMessage(text: e.message, role: MessageRole.system));
      }
    } catch (_) {
      if (!mounted) return;
      _addMessage(ChatMessage(
        text: 'خطا در عیب‌یابی. لطفاً دوباره تلاش کنید.',
        role: MessageRole.system,
      ));
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  void _onSend() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;
    _inputCtrl.clear();
    _addMessage(ChatMessage(text: text, role: MessageRole.user));
    unawaited(_fetchDiagnosis(text));
  }

  Widget _buildCreditBadge(AuthProvider auth, ThemeData theme) {
    if (auth.isGolden) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('طلایی',
            style: TextStyle(fontSize: 12, color: Colors.amber)),
      );
    }
    final credits = auth.credits;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'اعتبار: ${credits ?? '—'}',
        style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary),
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
              'لطفاً صبر کنید — هوش مصنوعی در حال بررسی است…',
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

  Widget _buildMessageBubble(
    ChatMessage m,
    ThemeData theme,
    int index,
  ) {
    final isUser = m.role == MessageRole.user;
    final isSystem = m.role == MessageRole.system;
    final isResult = m.isDiagnosisResult && index == _resultMessageIndex;

    Widget bubble = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isSystem
              ? Colors.red.withOpacity(0.12)
              : isUser
                  ? Colors.orange.withOpacity(0.22)
                  : theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
          borderRadius: BorderRadius.circular(16),
          border: isResult
              ? Border.all(color: Colors.orange.withOpacity(0.45), width: 1.2)
              : null,
        ),
        child: SelectableText(
          m.text,
          style: TextStyle(
            height: 1.55,
            fontSize: 14,
            color: isSystem ? Colors.redAccent.shade100 : null,
          ),
        ),
      ),
    );

    if (!isResult) return bubble;

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: Transform.rotate(
            angle: _shakeAnim.value * 0.008 * (math.pi / 12),
            child: child,
          ),
        );
      },
      child: bubble,
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: ListView.builder(
        controller: _scrollCtrl,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _messages.length,
        itemBuilder: (context, i) {
          return _buildMessageBubble(_messages[i], theme, i);
        },
      ),
    );
  }

  Widget _buildInputArea(
      ThemeData theme, AuthProvider auth, double bottomInset) {
    return Material(
      elevation: 8,
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(12, 10, 12, 10 + (bottomInset > 0 ? 4 : 0)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _onSend(),
                enabled: !_isTyping,
                decoration: InputDecoration(
                  hintText: 'سوال پیگیری بنویس…',
                  filled: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isTyping ? null : _onSend,
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.orange.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: BrandAppBarTitle(
          subtitle: '${widget.carName} · ${widget.year}',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Center(child: _buildCreditBadge(auth, theme)),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(child: _buildMessageList(theme)),
                if (_isTyping) _buildTypingBanner(theme),
                _buildInputArea(theme, auth, bottomInset),
              ],
            ),
          ),
          DiagnoseLoadingOverlay(visible: _isTyping),
        ],
      ),
    );
  }
}

void unawaited(Future<void> f) {}
