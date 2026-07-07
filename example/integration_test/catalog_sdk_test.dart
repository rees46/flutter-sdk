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

bool _exists(String key) => find.byKey(Key(key)).evaluate().isNotEmpty;

/// Polls until either the result or the error label for a method is rendered,
/// so the assertion does not depend on whether the test shop happens to have the
/// requested category/collection — only on the call completing without crashing.
Future<void> _waitForTerminalState(
  PatrolIntegrationTester $,
  String resultKey,
  String errorKey,
) async {
  for (var i = 0; i < 60; i++) {
    if (_exists(resultKey) || _exists(errorKey)) return;
    await $.tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  // ---------------------------------------------------------------------------
  // getProfile — the session profile always resolves after init.
  // ---------------------------------------------------------------------------
  patrolTest('getProfile — returns the session profile', ($) async {
    await _initializeSdk($);

    await $(const Key('btn_catalog_profile')).scrollTo(maxScrolls: 40);
    await $(const Key('btn_catalog_profile')).tap();

    await $(
      const Key('lbl_catalog_profile'),
    ).waitUntilExists(timeout: const Duration(seconds: 30));

    expect(_exists('lbl_catalog_profile_error'), isFalse);
    expect(_labelText($, 'lbl_catalog_profile'), contains('id='));
  });

  // ---------------------------------------------------------------------------
  // getProductCounters — returns counters for any item id (zeros if untracked).
  // ---------------------------------------------------------------------------
  patrolTest('getProductCounters — returns counters for an item', ($) async {
    await _initializeSdk($);

    await $.tester.enterText(
      find.byKey(const Key('field_catalog_counter_item')),
      TestConfig.productId,
    );
    await $.tester.pump();

    await $(const Key('btn_catalog_counters')).scrollTo(maxScrolls: 40);
    await $(const Key('btn_catalog_counters')).tap();

    await $(
      const Key('lbl_catalog_counters'),
    ).waitUntilExists(timeout: const Duration(seconds: 30));

    expect(_exists('lbl_catalog_counters_error'), isFalse);
    expect(_labelText($, 'lbl_catalog_counters'), contains('now.view='));
  });

  patrolTest('getProductCounters — empty item is a no-op', ($) async {
    await _initializeSdk($);

    // The field is pre-filled for manual use — clear it to exercise the empty case.
    await $.tester.enterText(
      find.byKey(const Key('field_catalog_counter_item')),
      '',
    );
    await $.tester.pump();

    await $(const Key('btn_catalog_counters')).scrollTo(maxScrolls: 40);
    await $(const Key('btn_catalog_counters')).tap();
    await $.pumpAndSettle();

    expect(_exists('lbl_catalog_counters'), isFalse);
    expect(_exists('lbl_catalog_counters_error'), isFalse);
  });

  // ---------------------------------------------------------------------------
  // getCategory — round-trips (a listing if the category exists, else an error).
  // ---------------------------------------------------------------------------
  patrolTest('getCategory — completes the round-trip', ($) async {
    await _initializeSdk($);

    await $.tester.enterText(
      find.byKey(const Key('field_catalog_category')),
      'naushniki',
    );
    await $.tester.pump();

    await $(const Key('btn_catalog_category')).scrollTo(maxScrolls: 40);
    await $(const Key('btn_catalog_category')).tap();

    await _waitForTerminalState(
      $,
      'lbl_catalog_category',
      'lbl_catalog_category_error',
    );

    expect(
      _exists('lbl_catalog_category') || _exists('lbl_catalog_category_error'),
      isTrue,
    );
  });

  patrolTest('getCategory — empty category is a no-op', ($) async {
    await _initializeSdk($);

    // The field is pre-filled for manual use — clear it to exercise the empty case.
    await $.tester.enterText(
      find.byKey(const Key('field_catalog_category')),
      '',
    );
    await $.tester.pump();

    await $(const Key('btn_catalog_category')).scrollTo(maxScrolls: 40);
    await $(const Key('btn_catalog_category')).tap();
    await $.pumpAndSettle();

    expect(_exists('lbl_catalog_category'), isFalse);
    expect(_exists('lbl_catalog_category_error'), isFalse);
  });

  // ---------------------------------------------------------------------------
  // getCollection — round-trips (products if the collection exists, else error).
  // ---------------------------------------------------------------------------
  patrolTest('getCollection — completes the round-trip', ($) async {
    await _initializeSdk($);

    await $.tester.enterText(
      find.byKey(const Key('field_catalog_collection')),
      '1',
    );
    await $.tester.pump();

    await $(const Key('btn_catalog_collection')).scrollTo(maxScrolls: 40);
    await $(const Key('btn_catalog_collection')).tap();

    await _waitForTerminalState(
      $,
      'lbl_catalog_collection',
      'lbl_catalog_collection_error',
    );

    expect(
      _exists('lbl_catalog_collection') ||
          _exists('lbl_catalog_collection_error'),
      isTrue,
    );
  });
}
