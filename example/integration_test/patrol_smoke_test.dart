import 'package:patrol/patrol.dart';

import 'package:rees46_sdk_example/main.dart' as app;

import 'patrol_setup.dart';

void main() {
  patrolTest('app launches and all key sections are visible', ($) async {
    await $.pumpWidgetAndSettle(const app.App());
    await dismissStartupPermissionDialog($);

    await $('REES46 SDK init demo').waitUntilVisible();
    await $('Initialization').waitUntilVisible();
    await $('Stored push token').waitUntilVisible();
    // Tracking is the last section of a long form. Each scroll relies on fling
    // momentum that a GPU-throttled CI emulator shrinks, so the default 15 scrolls
    // can undershoot; give generous headroom (the loop stops once it's visible).
    await $('Tracking').scrollTo(maxScrolls: 40);
    await $('Send demo trackEvent').scrollTo(maxScrolls: 40);
    await $('Send demo trackPurchase').scrollTo(maxScrolls: 40);
  });

  patrolTest(
    'auto-initializes on startup and exposes the Re-initialize button',
    ($) async {
      await $.pumpWidgetAndSettle(const app.App());
      await dismissStartupPermissionDialog($);

      // The demo uses hardcoded config and initializes itself on launch.
      await $(
        'Status: Initialized',
      ).waitUntilVisible(timeout: const Duration(seconds: 30));
      await $('Re-initialize').scrollTo();
    },
  );
}
