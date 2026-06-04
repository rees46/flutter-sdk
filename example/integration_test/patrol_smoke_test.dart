import 'package:patrol/patrol.dart';

import 'package:personalization_flutter_sdk_example/main.dart' as app;

void main() {
  patrolTest('app launches and all key sections are visible', ($) async {
    await $.pumpWidgetAndSettle(const app.App());

    await $('REES46 SDK init demo').waitUntilVisible();
    await $('Initialization').waitUntilVisible();
    await $('Stored push token').waitUntilVisible();
    await $('Tracking').scrollTo();
    await $('Send demo trackEvent').scrollTo();
    await $('Send demo trackPurchase').scrollTo();
  });

  patrolTest(
    'auto-initializes on startup and exposes the Re-initialize button',
    ($) async {
      await $.pumpWidgetAndSettle(const app.App());

      // The demo uses hardcoded config and initializes itself on launch.
      await $(
        'Status: Initialized',
      ).waitUntilVisible(timeout: const Duration(seconds: 30));
      await $('Re-initialize').scrollTo();
    },
  );
}
