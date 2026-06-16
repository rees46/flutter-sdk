import 'package:patrol/patrol.dart';

import 'package:rees46_sdk_example/main.dart' as app;

void main() {
  patrolTest('push token section is visible on launch', ($) async {
    await $.pumpWidgetAndSettle(const app.App());

    await $('Stored push token').waitUntilVisible();
  });

  patrolTest('Refresh and Copy controls are visible', ($) async {
    await $.pumpWidgetAndSettle(const app.App());

    await $('Refresh').waitUntilVisible();
    await $('Copy').waitUntilVisible();
  });

  patrolTest('refreshing the token after auto-init does not crash', ($) async {
    await $.pumpWidgetAndSettle(const app.App());

    await $(
      'Status: Initialized',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));

    await $('Refresh').tap();
    await $.pumpAndSettle();

    // Section stays present whether or not a token was delivered yet.
    await $('Stored push token').waitUntilVisible();
  });
}
