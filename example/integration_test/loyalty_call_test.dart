import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

/// Real-network integration test for the loyalty methods, exercised at the SDK
/// level (no demo UI). It complements [loyalty_sdk_test], which drives the same
/// methods through the example app's UI.
///
/// Drives the actual native SDK (Android `loyaltyManager`, iOS
/// `joinLoyalty`/`getLoyaltyStatus`) against the live REES46 API using a
/// loyalty-enabled shop. Runs as part of the Patrol suite.
///
/// NOTE: this must be a `patrolTest`, not a plain `testWidgets` with
/// `IntegrationTestWidgetsFlutterBinding` — Patrol bundles every *_test.dart in
/// this directory and initializes its own `PatrolBinding`; a second binding
/// would conflict and hang the whole run during test exploration.
void main() {
  const shopId = 'c1140c8254976de297c3caf971701a';
  const apiDomain = 'api.rees46.ru';
  const phone = '79991234567';

  Future<PersonalizationSdk> initSdk() async {
    final sdk = PersonalizationSdk();
    await sdk.initialize(
      SdkInitConfig(
        shopId: shopId,
        apiDomain: apiDomain,
        stream: defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : 'ios',
        enableLogs: true,
        autoSendPushToken: false,
        sendAdvertisingId: false,
        enableAutoPopupPresentation: false,
        needReInitialization: false,
      ),
    );
    // Wait until the native SDK has established a device id (did) — the status
    // endpoint requires it, and on Android init resolves it asynchronously.
    for (var i = 0; i < 40; i++) {
      final did = await sdk.getDid();
      if (did != null && did.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return sdk;
  }

  patrolTest('joinLoyalty — real call returns success', ($) async {
    final sdk = await initSdk();

    final member = await sdk.loyalty.join(phone);
    debugPrint('loyalty.join -> identifier=${member.identifier}');
    expect(member.identifier, isNotEmpty);
  });

  patrolTest('getLoyaltyStatus — real call returns success', ($) async {
    final sdk = await initSdk();

    final status = await sdk.loyalty.getStatus(phone);
    debugPrint(
      'loyalty.getStatus -> member=${status.isMember} level=${status.level?.name}',
    );
    expect(status.isMember, isA<bool>());
  });
}
