// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidconnect/app.dart';

void main() {
  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: KidConnectApp(),
      ),
    );

    // Verify that splash screen is shown
    expect(find.text('KidConnect'), findsOneWidget);
    expect(find.text('Parents & Preschool, Connected'), findsOneWidget);

    // Settle all animations and timers to avoid "Timer is still pending" error
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
