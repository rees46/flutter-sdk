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
JitPack and the [iOS SDK](https://github.com/rees46/ios-sdk) through Swift Package
Manager or CocoaPods.

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

The plugin declares the iOS 13.0 minimum itself and registers its own application
delegate — your `AppDelegate` stays untouched.

**With Swift Package Manager** — the default since Flutter 3.44, and on earlier
versions after `flutter config --enable-swift-package-manager` — there is nothing to
add: the plugin's package pulls the native SDK.

**With CocoaPods** (Swift Package Manager support turned off, or Flutter older than
3.44 without the setting above) add the native pod to `ios/Podfile`, inside
`target 'Runner'`. CocoaPods trunk is
read-only since 2 December 2026, so the pod is taken straight from its repository.
The tag is the version the plugin requires — the `REES46` dependency in
[`ios/rees46_sdk.podspec`](ios/rees46_sdk.podspec):

```ruby
pod 'REES46', :git => 'https://github.com/rees46/ios-sdk.git', :tag => 'v3.36.1'
```

`pod install` then runs as part of `flutter run`. Update the tag together with the
plugin, and drop the line once Swift Package Manager support is on — the plugin's
package brings the SDK then, and keeping the pod would link it twice.

## Initialize

Initialize once, as early as possible — typically in `main()`, before `runApp`:

```dart
import 'package:flutter/widgets.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

late final PersonalizationSdk sdk;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  sdk = REES46.initialize(
    const REES46Config(shopId: 'YOUR_SHOP_ID'),
  );

  runApp(const MyApp());
}
```

`REES46` is the entry point. `REES46.initialize` **returns the handle
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
| `enableAutoPopupPresentation` | `true` | Shows server popups without an `onPopup` handler, see [Popups](#popups) |

Push delivery needs platform setup of its own — a Firebase config on Android, the
Push Notifications capability on iOS. Without it initialization still succeeds;
there is simply no token to send.

Keep one place that owns the handle, so no widget re-initializes:

```dart
class REES46Service {
  static const _shopId = 'YOUR_SHOP_ID';

  static PersonalizationSdk get sdk => REES46.isInitialized(_shopId)
      ? REES46.getInstance(_shopId)
      : REES46.initialize(const REES46Config(shopId: _shopId));
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
REES46.registerShops(const [
  REES46Config(shopId: 'shop-a'),
  REES46Config(shopId: 'shop-b'),
]);                                 // pass eagerInit: true to initialize up front

final shopA = REES46.getInstance('shop-a');
```

Address instances explicitly once more than one is registered: `getInstance()`
without an id resolves only while exactly one shop is registered, and throws
`AmbiguousShopException` otherwise (`UnknownShopIdException` for an id that was
never registered).


## Popups

Popups made in the REES46 admin arrive with the responses to init and tracking
calls. The SDK shows them over the app's root navigator — the one `MaterialApp`,
`CupertinoApp` or `MaterialApp.router` builds — with nothing to set up.

A popup sits in the centre, at the top or at the bottom as set in the admin, and
fills the screen when no position is set. It waits out the delay set in the admin,
one is shown at a time, and one shown within the last minute is not shown again.
The link button opens its link, the push-subscription button opens the app's
notification settings. A popup is reported as shown once it is on screen.

To decide yourself — hold a popup back on a checkout screen, or draw it your way —
take popups with `onPopup`. The SDK then shows nothing:

```dart
sdk.onPopup = (InAppPopup popup) {
  if (onCheckout) {
    held = popup;                     // later: sdk.presentPopup(held!)
    return;
  }
  showDialog(
    context: context,
    builder: (context) => Center(
      child: SizedBox(
        width: 370,
        // Unbounded in height, the popup takes the height of its content.
        child: SingleChildScrollView(
          child: PersonalizationInAppPopup(
            view: popup.imageUrl == null
                ? PersonalizationInAppPopupView.text
                : PersonalizationInAppPopupView.image,
            title: popup.title,
            text: popup.text,
            actionText: popup.actionText,
            closeText: popup.closeText,
            image: popup.imageUrl == null ? null : NetworkImage(popup.imageUrl!),
            onAction: () {
              Navigator.pop(context);
              // Open popup.linkUrl, or the notification settings when
              // popup.pushSubscribeText is set — with url_launcher, for instance.
            },
            onClose: () => Navigator.pop(context),
          ),
        ),
      ),
    ),
  );
  sdk.tracking.popupShown(popup.id);  // the SDK reports only what it shows itself
};
```

`sdk.presentPopup(popup)` shows a popup the way the SDK does and reports it. With
`enableAutoPopupPresentation: false` and no `onPopup`, popups are not shown.

## UI theme

The SDK's UI (popups, for now) is drawn in the REES46 design. Set your brand once, in
`main` before `runApp`; it applies in `MaterialApp`, `CupertinoApp` and without
either:

```dart
PersonalizationTheme.configure(
  lightColors: PersonalizationColors.light.copyWith(
    brandPrimary: const Color(0xFF7C3AED),
    buttonPrimary: const Color(0xFF7C3AED),
  ),
  darkColors: PersonalizationColors.dark.copyWith(
    brandPrimary: const Color(0xFFA78BFA),
    buttonPrimary: const Color(0xFFA78BFA),
  ),
  fontFamily: const PersonalizationFontFamily(regular: 'Inter', emphasized: 'Inter'),
);
```

- Colours are set per scheme, font and radii once for both. Anything left out stays
  as designed, so start from `PersonalizationColors.light` / `.dark` and change only
  what you need.
- Without `darkColors` the dark scheme takes the brand colours (brand, primary
  button, brand line and text) from `lightColors`, the rest from the design.
- The font families must be declared in your `pubspec.yaml`; pass `package:` for
  fonts that come from another package.

Light or dark follows the app — its Material theme, else its Cupertino theme, else
the device setting. To keep the SDK's UI one way whatever the app is in:

```dart
PersonalizationTheme.mode = ThemeMode.dark;   // or ThemeMode.light; ThemeMode.system by default
```

Both settings can change at runtime; what is on screen is redrawn.

## Track events

Standard events live in the `tracking` namespace of the handle:

```dart
await sdk.tracking.productView('sku-1');
```

Each method returns a `Future<void>` that completes once the native SDK has the
API's answer; a rejected request throws a `PlatformException` (`track_failed`, or
`track_event_failed` / `track_purchase_failed` for custom events and orders).
Awaiting is optional — fire-and-forget from UI code is fine.

With several shops the namespace follows the instance:

```dart
await REES46.getInstance('shop-b').tracking.productView('sku-1');
```

### Catalog

```dart
// Product page opened.
await sdk.tracking.productView('sku-1');

// Category listing opened.
await sdk.tracking.categoryView('boots');

// The user searched. Pass `results` when your app runs the search itself and
// knows the ids it showed.
await sdk.tracking.search('winter boots', results: ['sku-1', 'sku-2']);
```

### Cart

```dart
// One product added.
await sdk.tracking.addToCart(
  const TrackingItem(id: 'sku-1', quantity: 2, price: 49.9, fashionSize: '42'),
);

// The cart as it looks after a change — replaces the stored contents.
await sdk.tracking.syncCart(const [
  TrackingItem(id: 'sku-1', quantity: 2, price: 49.9),
  TrackingItem(id: 'sku-2'), // quantity defaults to 1
]);

// One product removed.
await sdk.tracking.removeFromCart('sku-1');
```

`TrackingItem` needs only an `id`; `quantity` defaults to `1`, `price` and
`fashionSize` are optional.

### Favorites

```dart
await sdk.tracking.addToFavorites('sku-1');

await sdk.tracking.syncFavorites(const ['sku-1', 'sku-2']);

await sdk.tracking.removeFromFavorites('sku-1');
```

An empty list is how an emptied cart or wishlist is reported: `items` goes on
the wire as `[]` alongside `full_cart` / `full_wish`, which is what the native
SDKs send. Removing a single product is still `removeFromCart` /
`removeFromFavorites`.

### Stories

Only needed when you render stories yourself — the built-in stories view tracks
its own views and taps.

```dart
await sdk.tracking.storyView(
  storyId: '4321',
  slideId: '2',
  code: 'main_stories',
);

await sdk.tracking.storyClick(
  storyId: '4321',
  slideId: '2',
  code: 'main_stories',
);
```

`code` is the stories block; omit it and the native SDK uses the block it loaded
last. A tracked story also becomes the source of the events that follow it — the
same rule as [`setSource`](#attribution).

### Purchase

```dart
await sdk.tracking.purchase(
  orderId: 'order-1024',
  orderPrice: 149.8,
  items: const [
    PurchaseLineItem(id: 'sku-1', amount: 2, price: 49.9, fashionSize: '42'),
    PurchaseLineItem(id: 'sku-2', amount: 1, price: 50.0),
  ],
);
```

Those three are required; everything else is optional:

```dart
await sdk.tracking.purchase(
  orderId: 'order-1024',
  orderPrice: 149.8,
  items: const [PurchaseLineItem(id: 'sku-1', amount: 1, price: 149.8)],
  deliveryType: 'courier',
  deliveryAddress: 'Tverskaya 1, Moscow',
  paymentType: 'card',
  isTaxFree: false,
  isGiftPackage: true,
  promocode: 'WINTER20',
  orderCash: 100.0,
  orderBonuses: 49.8,
  orderDelivery: 5.0,
  orderDiscount: 20.0,
  channel: 'mobile_app',
  custom: const {'store_id': 'msk-01'},
  recommendedSource: const {'from': 'dynamic', 'code': 'main_page_block'},
  stream: 'flutter',
  segment: 'a',
);
```

`custom` goes on the wire under `custom`; keys that collide with the order's own
fields (`order_id`, `items`, `event`, `shop_id`, …) are rejected natively.

### Custom event

```dart
await sdk.tracking.custom(
  'subscribed_to_newsletter',
  category: 'account',
  label: 'footer_form',
  value: 1,
  time: DateTime.now().millisecondsSinceEpoch ~/ 1000, // UNIX seconds
  customFields: const {'plan': 'weekly'},
);
```

`customFields` is the free-form part: its entries are sent at the top level and
duplicated under `payload`. The SDK's own keys are reserved and rejected —
`event`, `time`, `category`, `label`, `value`, `source`, `payload`, `from`,
`code`, `stream`, `shop_id`, `did`, `sid`, `seance`, `segment`.

### Attribution

Events can carry the campaign the user arrived from — a bulk mobile push, a
chain. Both values come from the link that opened the app, which carries them as
`recommended_by` and `recommended_code`:

```
myshop://product/sku-1?recommended_by=bulk&recommended_code=jkIWdXSRfwVyK
```

A campaign brings the user in and then colours everything they do next, so store
it once when you handle the link:

```dart
await sdk.tracking.setSource(
  const TrackingSource(type: TrackingSourceType.bulk, code: 'jkIWdXSRfwVyK'),
);

// Carries recommended_by=bulk without being told to.
await sdk.tracking.productView('sku-1');
```

The stored source lives natively per shop, survives restarts, and is kept for 48
hours or until it is replaced.

To attribute a single event instead of everything that follows, pass `source` per
call — `productView`, `addToCart` and `addToFavorites` accept it:

```dart
await sdk.tracking.addToCart(
  const TrackingItem(id: 'sku-1', quantity: 1),
  source: const TrackingSource(type: TrackingSourceType.chain, code: 'welcome_2'),
);
```

A per-call `source` wins over the stored one, and an order is attributed by the
`recommendedSource` of the `purchase` call itself.

| `TrackingSourceType` | Wire value | Set by |
|---|---|---|
| `dynamicBlock` | `dynamic` | Dynamic recommender block |
| `chain` | `chain` | Recommendation chain |
| `bulk` | `bulk` | Bulk mailing |
| `transactional` | `transactional` | Transactional mailing |
| `instantSearch` | `instant_search` | Search suggestions |
| `fullSearch` | `full_search` | Full search results page |
| `stories` | `stories` | Stories block |
| `webPushDigest` | `web_push_digest` | Web push digest |

## License

MIT — see [LICENSE](LICENSE).
