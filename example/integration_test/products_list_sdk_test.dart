import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:personalization_flutter_sdk_example/main.dart' as app;

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
  patrolTest('getProductsList — returns non-negative total', ($) async {
    await _initializeSdk($);

    await $('Get Products List').scrollTo();
    await $('Get Products List').tap();
    await $('Get Products List').waitUntilVisible();

    expect(find.byKey(const Key('lbl_products_list_error')), findsNothing);

    final totalText = _labelText($, 'lbl_products_list_total');
    expect(totalText, startsWith('Total:'));
    final n = int.tryParse(totalText.replaceFirst('Total: ', ''));
    expect(n, isNotNull);
    expect(n, greaterThanOrEqualTo(0));
  });

  patrolTest('getProductsList — consistent total on repeated calls', ($) async {
    await _initializeSdk($);

    await $('Get Products List').scrollTo();
    await $('Get Products List').tap();
    await $('Get Products List').waitUntilVisible();
    final first = _labelText($, 'lbl_products_list_total');

    await $('Get Products List').scrollTo();
    await $('Get Products List').tap();
    await $('Get Products List').waitUntilVisible();
    final second = _labelText($, 'lbl_products_list_total');

    expect(first, equals(second));
  });

  patrolTest('getProductsList — no error after init', ($) async {
    await _initializeSdk($);

    await $('Get Products List').scrollTo();
    await $('Get Products List').tap();
    await $('Get Products List').waitUntilVisible();

    expect(find.byKey(const Key('lbl_products_list_error')), findsNothing);
    expect(find.byKey(const Key('lbl_products_list_total')), findsOneWidget);
  });
}
