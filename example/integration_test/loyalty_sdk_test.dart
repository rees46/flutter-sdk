import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:rees46_sdk_example/main.dart' as app;

Future<void> _initializeSdk(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(const app.App());
  await $(
    'Status: Initialized',
  ).waitUntilExists(timeout: const Duration(seconds: 30));
  await $('Status: Initialized').scrollTo(scrollDirection: AxisDirection.up);
}

String _labelText(PatrolIntegrationTester $, String key) {
  final widget = $.tester.widget<Text>(find.byKey(Key(key)));
  return widget.data ?? '';
}

void main() {
  patrolTest('getLoyaltyStatus — real call returns success', ($) async {
    await _initializeSdk($);

    await $(const Key('btn_loyalty_status')).scrollTo();
    await $(const Key('btn_loyalty_status')).tap();

    await $(
      const Key('lbl_loyalty_result'),
    ).waitUntilExists(timeout: const Duration(seconds: 30));

    expect(find.byKey(const Key('lbl_loyalty_error')), findsNothing);

    final result = _labelText($, 'lbl_loyalty_result');
    expect(result, startsWith('status:'));
    expect(result, contains('success'));
  });

  patrolTest('joinLoyalty — real call returns success', ($) async {
    await _initializeSdk($);

    await $(const Key('btn_join_loyalty')).scrollTo();
    await $(const Key('btn_join_loyalty')).tap();

    await $(
      const Key('lbl_loyalty_result'),
    ).waitUntilExists(timeout: const Duration(seconds: 30));

    expect(find.byKey(const Key('lbl_loyalty_error')), findsNothing);

    final result = _labelText($, 'lbl_loyalty_result');
    expect(result, startsWith('join:'));
    expect(result, contains('success'));
  });
}
