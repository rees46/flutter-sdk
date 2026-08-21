# rees46_sdk

[![pub package](https://img.shields.io/pub/v/rees46_sdk.svg)](https://pub.dev/packages/rees46_sdk)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Flutter plugin for the REES46 personalization platform — a thin bridge over the
native [Android](https://github.com/rees46/android-sdk) and
[iOS](https://github.com/rees46/ios-sdk) SDKs. Storage, sessions, identity and
push delivery happen natively; Dart only routes calls to the right shop instance.

## Add the package

```bash
flutter pub add rees46_sdk
```

Everything is exported from a single import:

```dart
import 'package:rees46_sdk/rees46_sdk.dart';
```

The native dependencies come with it — `com.github.rees46:android-sdk` from
JitPack and the `REES46` pod from CocoaPods trunk.

### Android

The plugin brings its own Gradle settings; the only value your app must agree on
is **`minSdk 24`**. Current Flutter versions already default to it, so a freshly
generated project needs no changes — set it only if you hardcoded something lower:

```kotlin
android {
    defaultConfig {
        minSdk = 24
    }
}
```

Your app's Java version does **not** have to match the plugin's — `compileOptions`
and `jvmTarget` only govern the module they are declared in.

If your `android/settings.gradle.kts` centralizes repositories
(`RepositoriesMode.FAIL_ON_PROJECT_REPOS` / `PREFER_SETTINGS`), add JitPack there —
otherwise the native SDK cannot be resolved:

```kotlin
maven(url = "https://jitpack.io")
```

### iOS

Nothing to add: the plugin's podspec pulls the `REES46` pod and declares the
iOS 13.0 minimum itself, `pod install` runs as part of `flutter run`, and the
plugin registers its own application delegate — your `AppDelegate` stays untouched.

## Initialize

Initialize once, as early as possible — typically in `main()`, before `runApp`:

```dart
import 'package:flutter/widgets.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

late final PersonalizationSdk sdk;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  sdk = Rees46.initialize(
    const Rees46Config(shopId: 'YOUR_SHOP_ID'),
  );

  runApp(const MyApp());
}
```

`Rees46` is the entry point. `Rees46.initialize` **returns the handle
synchronously** and starts native initialization in the background; calls issued
right after are queued natively until the session is ready, so the handle is
usable straight away. A broken setup surfaces as a `PlatformException` on the
first call you make with it (`bad_args` for an empty `shopId`, `init_failed` if
native init threw).

`shopId` is the only required field:

| Field | Default | Notes |
|---|---|---|
| `shopId` | — (**required**) | Your REES46 shop key |
| `apiDomain` | `api.rees46.ru` | API host |
| `stream` | `android` / `ios` | Traffic stream label; defaults to the current platform |
| `autoSendPushToken` | `true` | Fetches and sends the push token during init |
| `needReInitialization` | `false` | Forces a fresh session / device id |

Push delivery needs platform setup of its own — a Firebase config on Android, the
Push Notifications capability on iOS. Without it initialization still succeeds;
there is simply no token to send.

Keep one place that owns the handle, so no widget re-initializes:

```dart
class Rees46Service {
  static const _shopId = 'YOUR_SHOP_ID';

  static PersonalizationSdk get sdk => Rees46.isInitialized(_shopId)
      ? Rees46.getInstance(_shopId)
      : Rees46.initialize(const Rees46Config(shopId: _shopId));
}
```

### Check that it worked

```dart
final sid = await sdk.getSid();   // session id
final did = await sdk.getDid();   // device id issued by REES46
```

A non-empty `did` means the native SDK completed its handshake with the API.

### Several shops in one app

One app can run several shops at once — regional storefronts, super-app tenants.
Each gets its own native instance with isolated storage, session and `did`.

```dart
// Registered now, initialized on first use.
Rees46.registerShops(const [
  Rees46Config(shopId: 'shop-a'),
  Rees46Config(shopId: 'shop-b'),
]);                                 // pass eagerInit: true to initialize up front

final shopA = Rees46.getInstance('shop-a');
```

Address instances explicitly once more than one is registered: `getInstance()`
without an id resolves only while exactly one shop is registered, and throws
`AmbiguousShopException` otherwise (`UnknownShopIdException` for an id that was
never registered).


## License

MIT — see [LICENSE](LICENSE).
