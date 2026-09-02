import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:rees46_sdk_example/main.dart' as app;

import 'patrol_setup.dart';

/// Taps every button of the demo's standard-events section and reads the result line the
/// handler writes.
///
/// The handlers call `sdk.tracking.*` against the real API, so a green run means both that the
/// bridge is wired and that every method works end to end on this platform.

Future<void> _initializeSdk(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(const app.App());
  await dismissStartupPermissionDialog($);
  await $(
    'Status: Initialized',
  ).waitUntilExists(timeout: const Duration(seconds: 30));
}

String _resultText(PatrolIntegrationTester $) {
  final widget = $.tester.widget<Text>(
    find.byKey(const Key('lbl_tracking_result')),
  );
  return widget.data ?? '';
}

/// Taps [key] and waits until the result line reports on [method].
Future<void> _tapAndExpectSuccess(
  PatrolIntegrationTester $,
  String key,
  String method,
) async {
  await $(Key(key)).scrollTo(maxScrolls: 60);
  await $(Key(key)).tap();

  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!_resultText($).startsWith(method)) {
    if (DateTime.now().isAfter(deadline)) {
      fail('$method never reported, last result: "${_resultText($)}"');
    }
    await $.pump(const Duration(milliseconds: 100));
  }

  expect(_resultText($), '$method OK');
}

void main() {
  const demos = <String, String>{
    'tracking_product_view': 'productView',
    'tracking_category_view': 'categoryView',
    'tracking_search': 'search',
    'tracking_add_to_cart': 'addToCart',
    'tracking_sync_cart': 'syncCart',
    'tracking_remove_from_cart': 'removeFromCart',
    'tracking_add_to_favorites': 'addToFavorites',
    'tracking_sync_favorites': 'syncFavorites',
    'tracking_remove_from_favorites': 'removeFromFavorites',
    'tracking_set_source': 'setSource',
  };

  patrolTest('every standard event reports success', ($) async {
    await _initializeSdk($);

    for (final entry in demos.entries) {
      await _tapAndExpectSuccess($, entry.key, entry.value);
    }
  });
}
