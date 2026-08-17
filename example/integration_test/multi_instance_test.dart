import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:rees46_sdk_example/main.dart' as app;

import 'patrol_setup.dart';

/// On-device E2E for the multi-instance screen — mirror of the native
/// `MultiInstanceE2ETest` (Android) / `multi-instance.e2e.js` (RN). Opening the
/// screen makes shop A (eager) and shop B (lazy → materialized) both live, so the
/// fail-fast contracts and `Rees46.handlePush` routing run with two real shops in
/// one process. Runs on an emulator/simulator like the other `*_sdk_test.dart`.
///
/// Reads the deterministic result labels the screen exposes (`mi-contract-result`
/// / `mi-push-result`) rather than parsing the scrolling log.
void main() {
  String? textByKey(String key) {
    final elements = find.byKey(Key(key)).evaluate();
    if (elements.isEmpty) return null;
    return (elements.single.widget as Text).data;
  }

  Future<void> openMultiInstance(PatrolIntegrationTester $) async {
    await $.pumpWidgetAndSettle(const app.App());
    await dismissStartupPermissionDialog($);
    await $('REES46 SDK init demo').waitUntilVisible();
    await $(const Key('open-multi-instance')).tap();
    await $('Two shops, one app').waitUntilVisible();
  }

  patrolTest('multi-instance screen opens without crashing', ($) async {
    await openMultiInstance($);
    await $('Shop A').waitUntilVisible();
    await $('Shop B').waitUntilVisible();
  });

  patrolTest('getInstance() with two live shops is ambiguous', ($) async {
    await openMultiInstance($);

    await $('getInstance() → Ambiguous').scrollTo();
    await $('getInstance() → Ambiguous').tap();

    await pumpUntil(
      $,
      () => textByKey('mi-contract-result')?.contains('AmbiguousShopException') ?? false,
    );
    expect(textByKey('mi-contract-result'), contains('AmbiguousShopException'));
  });

  patrolTest('getInstance("nope") is an unknown shop', ($) async {
    await openMultiInstance($);

    await $('getInstance("nope") → Unknown').scrollTo();
    await $('getInstance("nope") → Unknown').tap();

    await pumpUntil(
      $,
      () => textByKey('mi-contract-result')?.contains('UnknownShopIdException') ?? false,
    );
    expect(textByKey('mi-contract-result'), contains('UnknownShopIdException'));
  });

  patrolTest('push shop_id=A routes to a shop', ($) async {
    await openMultiInstance($);

    await $('push shop_id=A').scrollTo();
    await $('push shop_id=A').tap();

    await pumpUntil(
      $,
      () => textByKey('mi-push-result')?.startsWith('routed:') ?? false,
    );
    expect(textByKey('mi-push-result'), startsWith('routed:'));
  });

  patrolTest('push shop_id=unknown is dropped', ($) async {
    await openMultiInstance($);

    await $('push shop_id=unknown').scrollTo();
    await $('push shop_id=unknown').tap();

    await pumpUntil($, () => textByKey('mi-push-result') == 'dropped');
    expect(textByKey('mi-push-result'), 'dropped');
  });

  patrolTest('push with no shop_id is dropped (two shops live)', ($) async {
    await openMultiInstance($);

    await $('push (no shop_id)').scrollTo();
    await $('push (no shop_id)').tap();

    await pumpUntil($, () => textByKey('mi-push-result') == 'dropped');
    expect(textByKey('mi-push-result'), 'dropped');
  });
}
