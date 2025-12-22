// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petai_frontend/screens/welcome_screen.dart';
import 'package:petai_frontend/services/api_service.dart';
import 'package:petai_frontend/theme/app_theme.dart';

void main() {
  testWidgets('Welcome screen renders sign-in UI', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: WelcomeScreen(
          apiService: ApiService(),
          onAuthenticated: (_) {},
        ),
      ),
    );

    expect(find.text('SIGN IN'), findsWidgets);
    expect(find.text('Nuru beta'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });
}
