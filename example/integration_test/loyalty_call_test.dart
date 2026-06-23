import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

/// Real-network integration test for the loyalty methods.
///
/// Drives the actual native SDK (Android `loyaltyManager`, iOS
/// `joinLoyalty`/`getLoyaltyStatus`) against the live REES46 API using a
/// loyalty-enabled shop. Run on a booted simulator/emulator:
///
///   flutter test integration_test/loyalty_call_test.dart -d [device-id]
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const shopId = 'c1140c8254976de297c3caf971701a';
  const apiDomain = 'api.rees46.ru';
  const phone = '79991234567';

  Future<PersonalizationSdk> initSdk() async {
    final sdk = PersonalizationSdk();
    await sdk.initialize(
      const SdkInitConfig(
        shopId: shopId,
        apiDomain: apiDomain,
        stream: kIsWeb ? 'web' : 'ios',
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

  testWidgets('joinLoyalty — real call returns success', (tester) async {
    final sdk = await initSdk();

    final response = await sdk.joinLoyalty(phone: phone);
    debugPrint(
      'joinLoyalty -> status=${response.status} payload=${response.payload}',
    );
    expect(response.status, equals('success'));
  });

  testWidgets('getLoyaltyStatus — real call returns success', (tester) async {
    final sdk = await initSdk();

    final response = await sdk.getLoyaltyStatus(phone);
    debugPrint(
      'getLoyaltyStatus -> status=${response.status} member=${response.member} level=${response.level?.name}',
    );
    expect(response.status, equals('success'));
  });
}
