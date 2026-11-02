// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rees46_sdk_example/main.dart';

void main() {
  testWidgets('Renders init demo page', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('REES46 SDK init demo'), findsOneWidget);
  });

  testWidgets('Shop and UI Kit are tabs, not entries of the API page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const App());

    for (final label in ['API', 'UI Kit', 'Shop']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    for (final key in [
      'open-shop',
      'open-shop-button',
      'open-ui-kit',
      'open-ui-kit-button',
    ]) {
      expect(find.byKey(Key(key)), findsNothing);
    }
    expect(find.byKey(const Key('open-multi-instance')), findsOneWidget);
    expect(find.byKey(const Key('open-multi-instance-button')), findsOneWidget);
  });
}
