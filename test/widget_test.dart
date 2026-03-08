// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flappybird/main.dart';
import 'package:flappybird/menu_screen.dart';

void main() {
  testWidgets('App starts at Menu Screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FlappyBallApp());
    await tester.pumpAndSettle();

    // Verify that our Menu Screen is shown.
    expect(find.byType(MenuScreen), findsOneWidget);
    expect(find.text('Bouncing Ball'), findsOneWidget);
  });
}
