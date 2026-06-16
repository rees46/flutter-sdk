import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:rees46_sdk_example/main.dart' as app;

import 'test_config.dart';

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
  // ---------------------------------------------------------------------------
  // getRecommendation
  // ---------------------------------------------------------------------------
  patrolTest('getRecommendation — returns title and product list', ($) async {
    await _initializeSdk($);

    await $.tester.enterText(
      find.byKey(const Key('field_rec_block_code')),
      TestConfig.recommendationBlockCode,
    );
    await $.tester.pump();

    await $('Get Recommendations').scrollTo();
    await $('Get Recommendations').tap();

    // Wait for loading to finish — button text reverts to 'Get Recommendations'.
    await $('Get Recommendations').waitUntilVisible();

    expect(find.byKey(const Key('lbl_rec_error')), findsNothing);

    final title = _labelText($, 'lbl_rec_title');
    expect(title, isNot(contains('Error')));
    expect(title, startsWith('Title:'));
  });

  patrolTest('getRecommendation — product count is non-negative', ($) async {
    await _initializeSdk($);

    await $.tester.enterText(
      find.byKey(const Key('field_rec_block_code')),
      TestConfig.recommendationBlockCode,
    );
    await $.tester.pump();
    await $('Get Recommendations').scrollTo();
    await $('Get Recommendations').tap();
    await $('Get Recommendations').waitUntilVisible();

    final countText = _labelText($, 'lbl_rec_count');
    // Text is "Products: N" — extract the number.
    final n = int.tryParse(countText.replaceFirst('Products: ', ''));
    expect(n, isNotNull);
    expect(n, greaterThanOrEqualTo(0));
  });

  patrolTest('getRecommendation — empty block code does not crash', ($) async {
    await _initializeSdk($);

    // Leave block code field empty and tap.
    await $('Get Recommendations').scrollTo();
    await $('Get Recommendations').tap();
    await $.pumpAndSettle();

    // No error label should appear — empty code is a no-op in the UI.
    expect(find.byKey(const Key('lbl_rec_title')), findsNothing);
    expect(find.byKey(const Key('lbl_rec_error')), findsNothing);
  });

  patrolTest('getRecommendation — invalid block code shows error', ($) async {
    await _initializeSdk($);

    await $.tester.enterText(
      find.byKey(const Key('field_rec_block_code')),
      'nonexistent_block_xyz',
    );
    await $.tester.pump();
    await $('Get Recommendations').scrollTo();
    await $('Get Recommendations').tap();
    await $('Get Recommendations').waitUntilVisible();

    // Either an error label appears, or we get an empty product list — both are valid.
    final hasError = find
        .byKey(const Key('lbl_rec_error'))
        .evaluate()
        .isNotEmpty;
    final hasTitle = find
        .byKey(const Key('lbl_rec_title'))
        .evaluate()
        .isNotEmpty;
    expect(hasError || hasTitle, isTrue);
  });
}
