# rees46_flutter_sdk

Flutter plugin wrapper around REES46 native SDKs (Android/iOS).

## Getting Started

### Install

Add dependency in your app:

```yaml
dependencies:
  personalization_flutter_sdk: ^0.0.1
```

### Initialize

```dart
import 'package:personalization_flutter_sdk/personalization_flutter_sdk.dart';

final sdk = PersonalizationSdk();

await sdk.initialize(
  const SdkInitConfig(
    shopId: 'YOUR_SHOP_ID',
    apiDomain: 'api.rees46.ru',
    // stream defaults to 'ios' on iOS and 'android' on Android if omitted.
    stream: 'ios',
    enableLogs: false,
    autoSendPushToken: true,
    sendAdvertisingId: false,
    enableAutoPopupPresentation: true,
    needReInitialization: false,
  ),
);
```

### API structure

The public API is exported from
`package:personalization_flutter_sdk/personalization_flutter_sdk.dart`:

- **`PersonalizationSdk`** — the SDK entrypoint (tracking, search,
  recommendations, profile).
- **`SdkInitConfig`** — initialization config passed to `initialize()`.

### Run demo app

```bash
cd example
fvm flutter run
```

### Notes

- **Android**: uses Maven dependency `com.rees46:rees46-sdk:2.28.0` and calls `SDK.initialize(...)`. Some iOS-only init flags are accepted by Dart API but ignored on Android.
- **iOS**: uses CocoaPods dependency `REES46 (3.23.0)` and calls `createPersonalizationSDK(...)`.
- **Pushes**:
  - **Android**: when `autoSendPushToken=true`, the native SDK fetches the FCM token via `FirebaseMessaging.getInstance().token` during initialization and sends it.
  - **iOS**: when `autoSendPushToken=true`, the native SDK requests notification permission and registers for remote notifications. The Flutter plugin also forwards `didRegisterForRemoteNotificationsWithDeviceToken` and `didReceiveRemoteNotification` AppDelegate callbacks to the native SDK.

For Flutter plugin development basics, see Flutter docs: [develop plugins](https://flutter.dev/to/develop-plugins).

