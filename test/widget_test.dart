// Widget tests for ControlRobot app
//
// These tests verify the basic UI structure and navigation

import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/main.dart';

void main() {
  testWidgets('App launches and shows splash screen', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const RobotControllerApp());

    // Verify splash screen shows ControlRobot branding
    expect(find.text('ControlRobot'), findsOneWidget);

    // Verify version text is present
    expect(find.text('v1.0.0'), findsOneWidget);
  });

  testWidgets('Splash screen transitions to connection screen', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const RobotControllerApp());

    // Wait for splash animation and transition
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Verify we're now on the connection screen
    expect(find.text('ROBOT LINK'), findsOneWidget);
    expect(find.text('SCAN DEVICES'), findsOneWidget);
  });
}
