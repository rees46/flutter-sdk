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
  patrolTest('searchFull — returns products_total for valid query', ($) async {
    await _initializeSdk($);

    await $.tester.enterText(
      find.byKey(const Key('field_search_query')),
      TestConfig.searchQuery,
    );
    await $.tester.pump();

    await $('Search').scrollTo();
    await $('Search').tap();
    await $('Search').waitUntilVisible();

    expect(find.byKey(const Key('lbl_search_error')), findsNothing);

    final totalText = _labelText($, 'lbl_search_total');
    expect(totalText, startsWith('Total:'));
    final n = int.tryParse(totalText.replaceFirst('Total: ', ''));
    expect(n, isNotNull);
    expect(n, greaterThanOrEqualTo(0));
  });

  patrolTest('searchFull — empty query is no-op in the UI', ($) async {
    await _initializeSdk($);

    await $('Search').scrollTo();
    await $('Search').tap();
    await $.pumpAndSettle();

    expect(find.byKey(const Key('lbl_search_total')), findsNothing);
    expect(find.byKey(const Key('lbl_search_error')), findsNothing);
  });

  patrolTest('searchFull — can be called multiple times', ($) async {
    await _initializeSdk($);

    await $.tester.enterText(
      find.byKey(const Key('field_search_query')),
      TestConfig.searchQuery,
    );
    await $.tester.pump();

    await $('Search').scrollTo();
    await $('Search').tap();
    await $('Search').waitUntilVisible();
    final first = _labelText($, 'lbl_search_total');

    await $('Search').scrollTo();
    await $('Search').tap();
    await $('Search').waitUntilVisible();
    final second = _labelText($, 'lbl_search_total');

    expect(first, equals(second));
  });

  patrolTest('searchFull — unknown query returns result or error, no crash', (
    $,
  ) async {
    await _initializeSdk($);

    await $.tester.enterText(
      find.byKey(const Key('field_search_query')),
      'xyznotexistentproduct12345',
    );
    await $.tester.pump();

    await $('Search').scrollTo();
    await $('Search').tap();
    await $('Search').waitUntilVisible();

    final hasTotal = find
        .byKey(const Key('lbl_search_total'))
        .evaluate()
        .isNotEmpty;
    final hasError = find
        .byKey(const Key('lbl_search_error'))
        .evaluate()
        .isNotEmpty;
    expect(hasTotal || hasError, isTrue);
  });
}
