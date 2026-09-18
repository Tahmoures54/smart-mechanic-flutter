import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/diagnose_loading_overlay.dart';
import '../models/diagnostic.dart';

enum MessageRole { user, assistant, system }

class ChatMessage {
  final String text;
  final MessageRole role;
  ChatMessage({required this.text, required this.role});
}

class ChatScreen extends StatefulWidget {
  final String carId;
  final String carName;
  final String year;
  final bool isCustomCar;

  const ChatScreen({
    super.key,
    required this.carId,
    required this.carName,
    required this.year,
    this.isCustomCar = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: 'سلام! مشکل «${widget.carName}» مدل ${widget.year} را شرح بده تا عیب‌یابی کنم.',
      role: MessageRole.assistant,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addMessage(ChatMessage msg) {
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
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
          text: 'اعتبار کافی نیست. از فروشگاه بسته بخرید.',
          role: MessageRole.system,
        ));
      } else if (e.statusCode == 401) {
        _addMessage(ChatMessage(
          text: 'نشست منقضی شده. دوباره وارد شوید.',
          role: MessageRole.system,
        ));
      } else {
        _addMessage(ChatMessage(
          text: e.message,
          role: MessageRole.system,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      _addMessage(ChatMessage(
        text: 'خطا در عیب‌یابی. دوباره تلاش کنید.',
        role: MessageRole.system,
      ));
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  void _onSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || _isTyping) return;
    _controller.clear();
    _addMessage(ChatMessage(text: text, role: MessageRole.user));
    unawaited(_fetchDiagnosis(text));
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

  Widget _buildMessageList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        final isUser = m.role == MessageRole.user;
        final isSystem = m.role == MessageRole.system;
        return Align(
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
                      ? Colors.orange.withOpacity(0.2)
                      : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              m.text,
              style: TextStyle(
                height: 1.5,
                color: isSystem ? Colors.redAccent.shade100 : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea(ThemeData theme, AuthProvider auth, double bottomInset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset * 0.05),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _onSend(),
              decoration: InputDecoration(
                hintText: 'مشکل را بنویس…',
                filled: true,
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
            ),
          ),
        ],
      ),
    );
  }
}

void unawaited(Future<void> f) {}
