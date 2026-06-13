import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_management_app/app.dart';
import 'package:student_management_app/core/api_client.dart';

void main() {
  testWidgets('shows login screen when no session is stored', (tester) async {
    const storageChannel = MethodChannel('student_management/storage');
    const notificationChannel = MethodChannel(
      'student_management/notifications',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storageChannel, (_) async => null);
    messenger.setMockMethodCallHandler(notificationChannel, (_) async => true);

    await tester.pumpWidget(StudentManagementApp(apiClient: ApiClient()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    messenger.setMockMethodCallHandler(storageChannel, null);
    messenger.setMockMethodCallHandler(notificationChannel, null);
  });
}
