# rees46_flutter_sdk

Flutter plugin wrapper around REES46 native SDKs (Android/iOS).

## Getting Started

### Install

Add dependency in your app:

```yaml
dependencies:
  rees46_sdk: ^0.0.1
```

### Initialize

```dart
import 'package:rees46_sdk/rees46_sdk.dart';

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
`package:rees46_sdk/rees46_sdk.dart`:

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

### Android push notification icon

On Android the plugin displays incoming pushes itself, so the notification's **small icon** is resolved from the **host app**, never from REES46. You should point it at your own icon:

```xml
<!-- android/app/src/main/AndroidManifest.xml, inside <application> -->
<meta-data
    android:name="com.rees46.push.notification_icon"
    android:resource="@drawable/ic_stat_notify" />
```

The icon must be a **white, alpha-only silhouette** — Android tints the small icon, so a full-colour image renders as a solid white/grey square. Generate one via Android Studio → *New → Image Asset → Notification Icons*.

**Already using Firebase?** If your app already declares `com.google.firebase.messaging.default_notification_icon`, you don't need to set anything — the plugin reuses that icon. Set `com.rees46.push.notification_icon` only if you want a different icon for REES46 pushes specifically.

Resolution order:

1. The `com.rees46.push.notification_icon` meta-data icon above (recommended if you want a dedicated icon).
2. The existing Firebase `com.google.firebase.messaging.default_notification_icon`, if declared.
3. The app's launcher icon, if neither is set (may look like a square, since a launcher icon is not a silhouette).
4. A neutral non-branded default bundled in the plugin, only if the host has no icon at all.

For Flutter plugin development basics, see Flutter docs: [develop plugins](https://flutter.dev/to/develop-plugins).

