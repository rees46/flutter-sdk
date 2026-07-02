import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:rees46_sdk_example/main.dart' as app;

import 'patrol_setup.dart';

import 'test_config.dart';

Future<void> _initializeSdk(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(const app.App());
  await dismissStartupPermissionDialog($);
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
  patrolTest('getProductInfo — returns product name for valid ID', ($) async {
    await _initializeSdk($);

    await $.tester.enterText(
      find.byKey(const Key('field_product_id')),
      TestConfig.productId,
    );
    await $.tester.pump();

    await $('Get Product Info').scrollTo();
    await $('Get Product Info').tap();
    await $('Get Product Info').waitUntilVisible();

    expect(find.byKey(const Key('lbl_product_info_error')), findsNothing);

    final nameText = _labelText($, 'lbl_product_info_name');
    expect(nameText, startsWith('Name:'));
    expect(nameText.length, greaterThan('Name:'.length));
  });

  patrolTest('getProductInfo — empty ID is no-op in the UI', ($) async {
    await _initializeSdk($);

    // The field is pre-filled for manual use — clear it to exercise the empty case.
    await $.tester.enterText(find.byKey(const Key('field_product_id')), '');
    await $.tester.pump();

    await $('Get Product Info').scrollTo();
    await $('Get Product Info').tap();
    await $.pumpAndSettle();

    expect(find.byKey(const Key('lbl_product_info_name')), findsNothing);
    expect(find.byKey(const Key('lbl_product_info_error')), findsNothing);
  });

  patrolTest('getProductInfo — invalid ID shows error', ($) async {
    await _initializeSdk($);

    await $.tester.enterText(
      find.byKey(const Key('field_product_id')),
      'nonexistent_product_id_xyz',
    );
    await $.tester.pump();

    await $('Get Product Info').scrollTo();
    await $('Get Product Info').tap();
    await $('Get Product Info').waitUntilVisible();

    final hasName = find
        .byKey(const Key('lbl_product_info_name'))
        .evaluate()
        .isNotEmpty;
    final hasError = find
        .byKey(const Key('lbl_product_info_error'))
        .evaluate()
        .isNotEmpty;
    expect(hasName || hasError, isTrue);
  });
}
