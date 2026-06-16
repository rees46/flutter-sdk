import 'package:flutter/widgets.dart';
import 'package:patrol/patrol.dart';

import 'package:rees46_sdk_example/main.dart' as app;

void main() {
  patrolTest('auto-initializes on startup with hardcoded config', ($) async {
    await $.pumpWidgetAndSettle(const app.App());

    await $(
      'Status: Initialized',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
  });

  patrolTest('tracking buttons are visible after auto-initialization', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const app.App());

    await $(
      'Status: Initialized',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
    await $('Send demo trackEvent').scrollTo();
    await $('Send demo trackPurchase').scrollTo();
  });

  patrolTest(
    'Re-initialize button re-runs initialization and returns to Initialized',
    ($) async {
      await $.pumpWidgetAndSettle(const app.App());

      await $(
        'Status: Initialized',
      ).waitUntilVisible(timeout: const Duration(seconds: 30));

      await $('Re-initialize').scrollTo();
      await $('Re-initialize').tap();

      await $(
        'Status: Initialized',
      ).waitUntilVisible(timeout: const Duration(seconds: 30));
      await $(
        'Status: Initialized',
      ).scrollTo(scrollDirection: AxisDirection.up);
    },
  );
}
