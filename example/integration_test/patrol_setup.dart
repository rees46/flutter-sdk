import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Waits until either [resultKey] or [errorKey] is present, so assertions run
/// only after the async SDK call has rendered its outcome.
///
/// Prefer this over waiting on a button's label when that label isn't unique on
/// the page — e.g. a card whose title text equals its button text. Waiting on
/// such text resolves immediately against the always-visible title and races
/// the result. Tap the button by its Key, then wait on the result/error label.
Future<void> waitForResultOrError(
  PatrolIntegrationTester $,
  String resultKey,
  String errorKey, {
  int maxPumps = 60,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    final done =
        find.byKey(Key(resultKey)).evaluate().isNotEmpty ||
        find.byKey(Key(errorKey)).evaluate().isNotEmpty;
    if (done) return;
    await $.tester.pump(const Duration(milliseconds: 500));
  }
}

/// Dismisses the Android 13+ POST_NOTIFICATIONS permission dialog that the
/// example app requests once at startup (see MainActivity).
///
/// This is deliberately defensive so it can never wedge the whole suite:
///  * `isPermissionDialogVisible` is given a real timeout so it tolerates the
///    dialog appearing a moment after the app launches (a race the 2s default
///    loses), instead of returning `false` too early.
///  * The whole thing is wrapped so a UiAutomator hiccup (or a build where the
///    dialog never shows, e.g. permission already granted) is a no-op rather
///    than a hang or a failure.
///
/// The OS only shows the dialog on the first app launch of an instrumentation
/// run, so for every test after the first this is a cheap no-op.
Future<void> dismissStartupPermissionDialog(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    if (await $.platform.mobile.isPermissionDialogVisible(timeout: timeout)) {
      await $.platform.mobile.grantPermissionWhenInUse();
    }
  } catch (_) {
    // Permission handling must never fail or hang a test.
  }
}
