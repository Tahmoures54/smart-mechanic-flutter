import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/diagnosis_result.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// منطق کسب‌وکار صفحهٔ چت، کاملاً جدا از UI — قابل تست بدون WidgetTester.
///
/// UI فقط این کنترلر را listen می‌کند و روی رویداد onMessageAppended
/// (اسکرول/لرزش) واکنش نشان می‌دهد.
class ChatController extends ChangeNotifier {
  ChatController({
    required this.carId,
    required this.carName,
    required this.year,
    required this.isCustomCar,
    required this.apiService,
    required this.authProvider,
    this.onMessageAppended,
  });

  final String carId;
  final String carName;
  final String year;
  final bool isCustomCar;
  final ApiService apiService;
  final AuthProvider authProvider;

  /// (index, isDiagnosisResult) — UI از این برای تصمیم «اسکرول ساده» یا
  /// «اسکرول به نتیجه + لرزش» استفاده می‌کند.
  final void Function(int index, bool isDiagnosisResult)? onMessageAppended;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isTyping = false;
  bool _guidedAnswerReady = false;
  bool get isTyping => _isTyping;

  /// When the latest assistant response is a guided questionnaire, the user
  /// should answer through touch options instead of the free-text composer.
  bool get isAwaitingChoices {
    if (_isTyping || _messages.isEmpty) return false;
    final last = _messages.last;
    return !_guidedAnswerReady &&
        last.structured?.responseMode == ResponseMode.questions &&
        last.structured?.questionOptions.isNotEmpty == true;
  }

  String? _lastDiagnosticId;
  bool _disposed = false;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void seedInitial({
    required String userMessage,
    String? initialResultText,
    Map<String, dynamic>? initialResultJson,
    String? initialDiagnosticId,
  }) {
    _append(ChatMessage.assistant(
      'سلام! دارم مشکل «$carName» مدل $year را بررسی می‌کنم.\nمشکل: $userMessage',
    ));

    if (initialResultText != null && initialResultText.trim().isNotEmpty) {
      _lastDiagnosticId = initialDiagnosticId;
      _appendDiagnosisResult(initialResultText, initialResultJson);
    } else {
      unawaited(fetchDiagnosis(userMessage));
    }
  }

  /// Marks a guided answer as selected. The answer is intentionally not
  /// sent to the backend yet; the user reviews it in the composer and taps Send.
  void prepareGuidedAnswer() {
    if (_isTyping) return;
    _guidedAnswerReady = true;
    _safeNotify();
  }

  void clearGuidedAnswer() {
    _guidedAnswerReady = false;
    _safeNotify();
  }


  Future<void> sendUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping || isAwaitingChoices) return;
    _append(ChatMessage.user(trimmed));
    await fetchDiagnosis(trimmed);
  }

  /// تلاش دوباره روی یک پیام خطا؛ پیام خطا از لیست حذف می‌شود و درخواست
  /// با همان متن اصلی کاربر دوباره ارسال می‌شود.
  Future<void> retry(ChatMessage errorMessage) async {
    if (errorMessage.retryText == null) return;
    _messages.remove(errorMessage);
    _safeNotify();
    await fetchDiagnosis(errorMessage.retryText!);
  }

  Future<void> fetchDiagnosis(String description) async {
    _isTyping = true;
    _safeNotify();

    try {
      final token = authProvider.token;
      if (token == null || token.isEmpty) {
        throw const ApiException(401, 'لطفاً دوباره وارد شوید.');
      }

      final response = await apiService.diagnoseDetailed(
        token,
        carId,
        description,
        year: year,
        carName: isCustomCar ? carName : null,
        previousDiagnosticId: _lastDiagnosticId,
      );

      if (_disposed) return;

      _lastDiagnosticId = response.diagnosticId;
      _guidedAnswerReady = false;
      unawaited(authProvider.fetchProfile());

      // فرض: ApiService به‌مرور فیلد اختیاری `structured` (Map<String,dynamic>؟)
      // را هم برمی‌گرداند (خروجی خام DiagnosisResponseSchema). تا وقتی بک‌اند
      // به‌روزرسانی نشده، این فیلد null است و UI به‌صورت متن ساده fallback می‌کند.
      final structuredJson = response.structured;
      _appendDiagnosisResult(response.result, structuredJson);
    } on ApiException catch (e) {
      if (_disposed) return;
      _append(ChatMessage.error(
        _messageForApiError(e),
        retryText: e.statusCode == 402 ? null : description,
        errorType: _errorTypeFor(e),
      ));
    } catch (_) {
      if (_disposed) return;
      _append(ChatMessage.error('خطا در عیب‌یابی. لطفاً دوباره تلاش کنید.', retryText: description));
    } finally {
      if (!_disposed) {
        _isTyping = false;
        _safeNotify();
      }
    }
  }

  void _appendDiagnosisResult(String text, Map<String, dynamic>? json) {
    final structured = DiagnosisResult.tryParse(json);
    _append(ChatMessage.assistant(text, isDiagnosisResult: true, structured: structured));
  }

  void _append(ChatMessage message) {
    _messages.add(message);
    _safeNotify();
    onMessageAppended?.call(_messages.length - 1, message.isDiagnosisResult);
  }

  ChatErrorType _errorTypeFor(ApiException e) {
    if (e.statusCode == 401) return ChatErrorType.unauthorized;
    if (e.statusCode == 402) return ChatErrorType.insufficientCredits;
    if (e.statusCode >= 500) return ChatErrorType.server;
    if (e.statusCode == 0 || e.statusCode == 408) return ChatErrorType.network;
    return ChatErrorType.generic;
  }

  String _messageForApiError(ApiException e) {
    switch (e.statusCode) {
      case 402:
        return 'اعتبار شما کافی نیست. لطفاً از فروشگاه بسته بخرید.';
      case 401:
        return 'نشست شما منقضی شده است. لطفاً دوباره وارد شوید.';
      default:
        return e.message;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
