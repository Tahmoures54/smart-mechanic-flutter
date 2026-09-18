import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../models/chat_message.dart';
import 'shop_screen.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/diagnose_loading_overlay.dart';
import '../widgets/chat/chat_bubble.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/chat/chat_top_widgets.dart';
import '../widgets/chat/diagnosis_result_card.dart';

class ChatScreen extends StatefulWidget {
  final String carName;
  final String carId;
  final String year;
  final String initialUserMessage;
  final bool isCustomCar;
  final String? initialDiagnosisResult;
  final String? initialDiagnosticId;
  final Map<String, dynamic>? initialStructuredResult;

  const ChatScreen({
    super.key,
    required this.carName,
    required this.carId,
    required this.year,
    required this.initialUserMessage,
    this.isCustomCar = false,
    this.initialDiagnosisResult,
    this.initialDiagnosticId,
    this.initialStructuredResult,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final Map<int, GlobalKey> _bubbleKeys = {};

  late final ChatController _chat;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));

    _chat = ChatController(
      carId: widget.carId,
      carName: widget.carName,
      year: widget.year,
      isCustomCar: widget.isCustomCar,
      apiService: context.read<ApiService>(),
      authProvider: context.read<AuthProvider>(),
      onMessageAppended: _handleMessageAppended,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chat.seedInitial(
        userMessage: widget.initialUserMessage,
        initialResultText: widget.initialDiagnosisResult,
        initialResultJson: widget.initialStructuredResult,
        initialDiagnosticId: widget.initialDiagnosticId,
      );
    });
  }

  @override
  void dispose() {
    _chat.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _handleMessageAppended(int index, bool isDiagnosisResult) {
    if (isDiagnosisResult) {
      _focusResultAndShake(index);
    } else {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  /// اسکرول دقیق به کارت نتیجه با Scrollable.ensureVisible روی RenderObject
  /// واقعی — به‌جای حدس‌زدن زمان پایدارشدن layout با تأخیر ثابت.
  void _focusResultAndShake(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctx = _bubbleKeys[index]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
      } else {
        _scrollToBottom();
      }
      if (!mounted) return;
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
      _shakeCtrl.forward(from: 0);
    });
  }

  void _onSend() {
    final text = _inputCtrl.text;
    if (text.trim().isEmpty || _chat.isTyping) return;
    _inputCtrl.clear();
    _chat.sendUserMessage(text);
  }

  Future<void> _goToStore() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopScreen()),
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
        title: BrandAppBarTitle(subtitle: '${widget.carName} · ${widget.year}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Center(child: CreditBadge(auth: auth)),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: _chat,
                    builder: (context, _) => _buildMessageList(theme),
                  ),
                ),
                ListenableBuilder(
                  listenable: _chat,
                  builder: (context, _) => _chat.isTyping ? const TypingBanner() : const SizedBox.shrink(),
                ),
                ListenableBuilder(
                  listenable: _chat,
                  builder: (context, _) {
                    if (_chat.isAwaitingChoices) {
                      return const _ChoicePromptBar();
                    }
                    return ChatInputBar(
                      controller: _inputCtrl,
                      focusNode: _focusNode,
                      enabled: !_chat.isTyping,
                      onSend: _onSend,
                      bottomInset: bottomInset,
                    );
                  },
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: _chat,
            builder: (context, _) => DiagnoseLoadingOverlay(visible: _chat.isTyping),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    final messages = _chat.messages;
    final lastResultIndex = messages.lastIndexWhere((m) => m.isDiagnosisResult);

    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: ListView.builder(
        controller: _scrollCtrl,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: messages.length,
        itemBuilder: (context, i) {
          final key = _bubbleKeys.putIfAbsent(i, () => GlobalKey());
          final m = messages[i];
          final highlighted = m.isDiagnosisResult && i == lastResultIndex;

          Widget child;
          if (m.structured != null) {
            child = Align(
              alignment: Alignment.centerLeft,
              child: DiagnosisResultCard(
                result: m.structured!,
                onSubmitAnswer: _chat.sendStructuredAnswer,
              ),
            );
          } else {
            child = ChatBubble(
              message: m,
              highlighted: highlighted,
              onRetry: m.errorType == ChatErrorType.insufficientCredits
                  ? _goToStore
                  : m.retryText != null
                      ? () => _chat.retry(m)
                      : null,
            );
          }

          final wrapped = KeyedSubtree(key: key, child: child);
          if (!highlighted) return wrapped;

          return AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, c) => Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: Transform.rotate(angle: _shakeAnim.value * 0.008 * (math.pi / 12), child: c),
            ),
            child: wrapped,
          );
        },
      ),
    );
  }
}


class _ChoicePromptBar extends StatelessWidget {
  const _ChoicePromptBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
          child: Row(
            children: [
              Icon(Icons.touch_app_rounded, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'گزینه‌های بالا را انتخاب کن؛ نیازی به تایپ نیست.',
                  style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
