import 'package:flutter_test/flutter_test.dart';

import 'package:smart_mechanic/controllers/chat_controller.dart';
import 'package:smart_mechanic/models/chat_message.dart';
import 'package:smart_mechanic/providers/auth_provider.dart';
import 'package:smart_mechanic/services/api_service.dart';

void main() {
  late ChatController controller;

  setUp(() {
    controller = ChatController(
      carId: 'test-car',
      carName: 'خودروی آزمایشی',
      year: '۱۴۰۲',
      isCustomCar: false,
      apiService: ApiService(),
      authProvider: AuthProvider(ApiService()),
    );
  });

  tearDown(() => controller.dispose());

  test('accepts a follow-up answer while a question card is visible', () async {
    controller.seedInitial(
      userMessage: 'صدای غیرعادی دارم',
      initialResultText: 'برای تشخیص دقیق‌تر پاسخ بده.',
      initialResultJson: {
        'responseMode': 'questions',
        'questionOptions': [
          {
            'question': 'صدا در حالت سرد شنیده می‌شود؟',
            'options': ['بله', 'خیر'],
          },
        ],
      },
    );

    expect(controller.isAwaitingChoices, isTrue);

    // No token is intentional: the request ends in a handled 401, but the
    // important invariant is that the user's answer is appended and the chat
    // leaves the questionnaire state instead of silently ignoring the tap.
    await controller.sendUserMessage('صدا در حالت سرد شنیده می‌شود؟: بله');

    expect(
      controller.messages.any(
        (message) =>
            message.role == MessageRole.user &&
            message.text.contains('بله'),
      ),
      isTrue,
    );
    expect(controller.isTyping, isFalse);
    expect(controller.messages.last.role, MessageRole.system);
  });
}
