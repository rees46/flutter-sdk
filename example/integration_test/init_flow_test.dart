import 'package:flutter/widgets.dart';
import 'package:patrol/patrol.dart';

import 'package:rees46_sdk_example/main.dart' as app;

import 'patrol_setup.dart';

void main() {
  patrolTest('auto-initializes on startup with hardcoded config', ($) async {
    await $.pumpWidgetAndSettle(const app.App());
    await dismissStartupPermissionDialog($);

    await $(
      'Status: Initialized',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
  });

  patrolTest('tracking buttons are visible after auto-initialization', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const app.App());
    await dismissStartupPermissionDialog($);

    await $(
      'Status: Initialized',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));
    // Scroll by key (not label text), with extra drags: these buttons sit at the
    // very bottom of a long form, and on a GPU-throttled CI emulator the per-drag
    // fling momentum shrinks, so the default 15 scrolls can undershoot.
    await $(const Key('example_demo_track_event')).scrollTo(maxScrolls: 40);
    await $(const Key('example_demo_track_purchase')).scrollTo(maxScrolls: 40);
  });

  patrolTest(
    'Re-initialize button re-runs initialization and returns to Initialized',
    ($) async {
      await $.pumpWidgetAndSettle(const app.App());
      await dismissStartupPermissionDialog($);

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
