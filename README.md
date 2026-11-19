# rees46_sdk

[![pub package](https://img.shields.io/pub/v/rees46_sdk.svg)](https://pub.dev/packages/rees46_sdk)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Flutter plugin for the REES46 personalization platform — a thin bridge over the
native [Android](https://github.com/rees46/android-sdk) and
[iOS](https://github.com/rees46/ios-sdk) SDKs. Init, sessions, identity, the event
queue, storage, requests and push delivery happen natively; Dart routes each call
to the right shop instance and hands back the native SDK's typed answer.

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

The plugin declares the iOS 15.0 minimum itself (the native SDK needs it) and
registers its own application delegate — your `AppDelegate` stays untouched.

**With Swift Package Manager** — the default since Flutter 3.44, and on earlier
versions after `flutter config --enable-swift-package-manager` — there is nothing to
add: the plugin's package pulls the native SDK.

**With CocoaPods** (Swift Package Manager support turned off, or Flutter older than
3.44 without the setting above) add the native pod to `ios/Podfile`, inside
`target 'Runner'`. CocoaPods trunk goes read-only on 2 December 2026 and new SDK
versions are no longer published there, so the pod is taken straight from its
repository. The tag is the version the plugin requires — the `REES46` dependency in
[`ios/rees46_sdk.podspec`](ios/rees46_sdk.podspec):

```ruby
pod 'REES46', :git => 'https://github.com/rees46/ios-sdk.git', :tag => 'v3.40.1'
```

`pod install` then runs as part of `flutter run`. Update the tag together with the
plugin, and drop the line once Swift Package Manager support is on — the plugin's
package brings the SDK then, and keeping the pod would link it twice.

## Migrating to 2.0

2.0 runs every shop on the native SDKs' new core and adds the typed
[namespaces](#namespaces). The released methods (`getRecommendation`, `searchFull`,
`joinLoyalty`, `setProfile`, `trackEvent`, …) are deprecated and behave as in 1.6.4:
the same answers, the same error codes. What an app can notice:

- **Native SDKs and iOS.** The plugin builds on the Android SDK 2.54.0 and the iOS SDK
  3.40.1, and iOS 15 is the minimum. With CocoaPods take the pod from its repository
  with the tag `v3.40.1` ([iOS](#ios)).
- **Errors.** The namespaces, `tracking`, `flush` and `deleteUserCredentials` throw an
  [`SdkException`](#errors) whose `type` is `notInitialized`, `shopBlocked`,
  `invalidArgument`, `network`, `timeout`, `http`, `decoding` or `cancelled`. It is a
  `PlatformException` too, with `code` set to the type. The deprecated methods keep the
  codes of 1.6.4: `bad_args`, `not_initialized` (iOS), `<method>_failed`
  (`recommendation_failed`, `search_failed`, `track_event_failed`, …) and
  `serialization_failed`.
- **`ready`.** It completes once the shop works — `ready`, or `retrying` with a device
  id from an earlier launch — and fails with `shopBlocked` when the server refused the
  shop. A first launch without network has no device id yet, so `ready` waits for the
  network: where the UI waits for it, give it a timeout
  (`await sdk.ready.timeout(const Duration(seconds: 10))`). Calls never need to await it.
- **Tracking completes on acceptance.** A `sdk.tracking.*` future completes once the
  event is in the shop's queue on disk, not when the server answered: an event the server
  refuses later is no error. Only `invalidArgument`, `shopBlocked` and `notInitialized`
  fail it. The deprecated `trackEvent` and `trackPurchase` still complete with the
  server's answer.
- **Default stream.** Without `stream` in the configuration events go with
  `stream: flutter`; 1.6.4 sent `android` or `ios`. Set `stream` to keep the reports
  split by platform.
- **Push events on the wire.** Android reports a push that arrived as `track/delivered`
  (1.6.4 sent `track/received`, which the server counts as an open), the notification the
  plugin drew as `track/opened`, a tap as `track/clicked` and a dismissal as
  `track/closed`. iOS reports `opened` for a push shown while the app is open,
  `delivered` from `didReceiveRemoteNotification`, and `clicked`. A host with its own
  messaging service that calls `REES46.handlePush(payload, event)`: `PushEvent.received`
  sends `delivered`, `PushEvent.delivered` (its notification is on screen) sends `opened`,
  `PushEvent.clicked` sends `clicked`, on both platforms.
- **Profile checks.** `sdk.profile.set` refuses with `invalidArgument`, before any
  request: a custom property key outside `[a-z0-9_]`, or one that is a field of the
  request (`email`, `first_name`, …) or a reserved one (`shop_id`, `did`, `sid`,
  `seance`, `segment`, `stream`); a value that is not a string, number, bool, `null`, or a
  list or map of them; an empty `email`, `phone` or `loyaltyId`; a `birthday` that is not
  a real `YYYY-MM-DD` date; a negative `age`. The advertising id is the SDK's to send
  (`sendAdvertisingId`), as `google_advertising_id` or `apple_advertising_id`. The
  deprecated `setProfile` sends its fields as 1.6.4 did.
- **New names.** The package exports new types — `Order`, `Profile`, `Gender`,
  `Segment`, `CartItem`, `PushPayload`, `SortBy`, `SdkState`, `SdkError` and others. If
  one clashes with a type of the app, hide it or import the package with a prefix:
  `import 'package:rees46_sdk/rees46_sdk.dart' hide Order, Profile;`.
- **Tests with a fake channel.** The internal Pigeon channel `PersonalizationHostApi`
  changed: the namespaces have typed methods, the deprecated methods go through
  `legacy…` methods (`legacyGetRecommendation`, `legacySearchFull`, …) with the JSON
  strings of 1.6.4, and `initialize` answers with the shop's state. A fake that extends
  it needs the new names.
- **New on the handle.** `state` and `stateChanges`, `deviceId` and `sessionId`,
  [`flush`, `release` and `deleteUserCredentials`](#the-instance-itself), the push
  callbacks of each shop (`sdk.notifications.setCallbacks`). `onToken` hears a token the
  SDK got from APNs, FCM or HMS, not one the app hands over with `setPushToken`.

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
right after wait natively until the shop is ready, so the handle is usable straight
away. To learn the outcome of the init itself, await the handle's `ready`: it
completes once the shop works (`SdkState.ready`, or `retrying` with a device id from
an earlier launch) and fails with an [`SdkException`](#errors) — `shopBlocked` when
the server refused the shop, `invalidArgument` for an empty `shopId`. `state` and
`stateChanges` follow the init as it goes: `notInitialized`, `initializing`, `ready`,
`retrying`, `refused`.

`shopId` is the only required field:

| Field | Default | Notes |
|---|---|---|
| `shopId` | — (**required**) | Your REES46 shop key |
| `apiDomain` | `api.rees46.ru` | API host |
| `stream` | `flutter` | Traffic stream label |
| `autoSendPushToken` | `true` | Fetches and sends the push token during init; on iOS it also asks for notification permission. With `false` the app asks and sends the token itself |
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
await sdk.ready;
print(sdk.deviceId);   // device id issued by REES46
print(sdk.sessionId);  // session id

final did = await sdk.getDid();   // the same, read from the native SDK now
```

A non-empty `did` means the native SDK completed its handshake with the API. An
app that ran an earlier release keeps its `did`: the native SDK takes over the data
it stored.

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
`CupertinoApp` or `MaterialApp.router` builds — with nothing to set up. A popup that
finds no navigator within 10 seconds is dropped.

A popup sits in the centre, at the top or at the bottom as set in the admin, and
fills the screen when no position is set. It waits out the delay set in the admin,
and one shown within the last minute is not shown again. One popup is on screen at a
time, whichever shop it came from. A popup is reported as shown once it is on screen.

The link button opens the link set for the platform, or the web one when there is
none, with the system handler: a link into the app itself reaches it through the
app's own deep-link handling. The push-subscription button opens the app's
notification settings.

To see popups in your theme without making one in the admin, run the
[example app](#example-app): it shows a test popup in each position.

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

### Several shops

`sdk.onPopup` takes the popups of its own shop. To take the popups of every shop in
one place, set `REES46.onPopup`; `popup.shopId` tells which shop a popup came from:

```dart
REES46.onPopup = (InAppPopup popup) {
  if (onCheckout) {
    held = popup;   // later: REES46.getInstance(held!.shopId).presentPopup(held!)
    return;
  }
  REES46.getInstance(popup.shopId).presentPopup(popup);
};
```

A shop's own `onPopup` wins over `REES46.onPopup`. Show or report a popup through
the handle of its shop, as above: `presentPopup` and `tracking.popupShown` count it
for the shop they are called on.

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

Events go through the native SDK's event queue on disk, which sends them in order
and retries them after a failure or a restart. Each method returns a `Future<void>`
that completes once the queue took the event, on Android and iOS alike. The server's
answer comes later and is not the call's: an event the server refuses later — a
custom event the shop does not know, say — still completes. The call throws an
[`SdkException`](#errors) only when the event does not get into the queue —
`invalidArgument` for an empty id or a source the API does not take in an event,
`shopBlocked` for a shop the server refused, `notInitialized` after `release()`.
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

### Banners

A banner of a [slider](#sliders) shown and tapped — once per showing of the slider:

```dart
final slider = await sdk.sliders.get('main_slider');
final banner = slider.banners.first;
await sdk.tracking.bannerView(banner.id, banner.code);
await sdk.tracking.bannerClick(banner.id, banner.code);
```

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

## Namespaces

Besides `tracking`, every domain of the SDK is a namespace of the handle —
`sdk.<namespace>.<method>(…)`. Each method calls the native SDK's method of the
same name and answers with a typed model:

```dart
final product = await sdk.products.getInfo('37');          // Product?
final results = await sdk.search.full('kettle');            // SearchFullResponse
final cart = await sdk.cart.get();                          // List<CartItem>
```

With several shops the namespaces follow the instance, as `tracking` does:
`REES46.getInstance('shop-b').products.getInfo('37')`.

### The instance itself

Besides `shopId`, `deviceId`, `sessionId`, `state` and `ready`, the handle's root has
three methods of the instance's life:

```dart
await sdk.flush();                  // send the queued events now
await sdk.deleteUserCredentials();  // forget the customer on this device
sdk.release();                      // stop the instance
```

- `flush()` sends the events waiting in the shop's queue without waiting for the
  queue's own triggers, and completes once each was tried — sent, or kept for later
  (no network, a server that asked to wait). It promises no delivery.
- `deleteUserCredentials()` forgets the shop's customer: device id, session, queued
  events, the saved init answer and the rest of the customer's data. The device's
  push token and A/B group stay. The instance asks the API again and gets a new
  device id: `deviceId` is null until then, and calls made meanwhile wait for it.
  Other shops keep their customers.
- `release()` stops the instance: nothing more is sent, the queued events stay on
  the device for the next launch, and the shop leaves the registry —
  `REES46.isInitialized(shopId)` is false. Every later call of the handle throws
  `SdkException` `notInitialized`, and `state` is `notInitialized`. A new
  `REES46.initialize` of the shop gives a fresh instance and a new handle.

`flush` and `deleteUserCredentials` throw `notInitialized` after `release()`; they
have no other error.

### Errors

A failed call throws an `SdkException` whose `error` is one of the closed set of
`SdkError`s — the same on every platform:

| `type` | Class | When |
|---|---|---|
| `notInitialized` | `SdkErrorNotInitialized` | the shop is not initialized, the plugin does not know it, or the handle was released |
| `shopBlocked` | `SdkErrorShopBlocked` | the server refused the shop on init |
| `invalidArgument` | `SdkErrorInvalidArgument` | an argument refused before any request; `message` says which |
| `network` | `SdkErrorNetwork` | no connection |
| `timeout` | `SdkErrorTimeout` | no answer in time |
| `http` | `SdkErrorHttp` | the server answered outside `2xx`: `code`, and `serverCode` once the server sends one |
| `decoding` | `SdkErrorDecoding` | a `2xx` answer that does not read |
| `cancelled` | `SdkErrorCancelled` | the request was cancelled |

```dart
try {
  await sdk.recommendations.get('block-code');
} on SdkException catch (e) {
  switch (e.error) {
    case SdkErrorHttp(code: 404):
      // no such block
    case SdkErrorNetwork():
      // offline
    default:
      debugPrint('${e.type} ${e.httpCode} ${e.serverCode}');
  }
}
```

`SdkException` is a `PlatformException` too (`code` is the type, `details` holds
`httpCode` and `serverCode`), so code that catches `PlatformException` keeps working.

### Products

| Method | Answer |
|---|---|
| `getInfo(itemId)` | `Product?` — `null` for a product the catalog does not have |
| `getList({request: ProductsListRequest})` | `ProductsListResponse` — a page of the listing with its facets |
| `getCounters(itemId)` | `ProductCountersResponse` — views, carts, purchases today and in 30 minutes |
| `getCategory(categoryId, {request: CategoryRequest})` | `CategoryResponse` — the category's products, facets, price range |

```dart
final page = await sdk.products.getList(
  request: const ProductsListRequest(
    categoryIds: ['kettles'],
    brands: ['Bosch'],
    filters: {'Цвет': ['белый']},
    sortBy: SortBy.price,
    sortDir: SortDirection.asc,
    limit: 20,
    page: 1,
  ),
);
```

`SortBy` is an open set — `SortBy('key')` passes a key the server added later.

### Collections and recommendations

```dart
final collection = await sdk.collections.get('12');          // CollectionResponse

final block = await sdk.recommendations.get(
  'block-code',
  request: const RecommendationRequest(itemId: '37', limit: 6),
);                                                            // RecommendationResponse
```

For a view, a cart or a purchase to count for the block, pass
`TrackingSource(type: TrackingSourceType.dynamicBlock, code: 'block-code')` to
`sdk.tracking`.

### Search

| Method | Answer |
|---|---|
| `blank()` | `SearchBlankResponse` — what to show in an empty search field |
| `instant(query, {locations, excludedMerchants, excludedBrands})` | `SearchInstantResponse` — products and suggestions as the user types |
| `full(query, {request: SearchFullRequest})` | `SearchFullResponse` — the results screen with facets, order and page |
| `agentEnabled` | `bool`, at once — whether the shop shows the AI search agent instead of the empty search |
| `agentDialog({sessionId, locations})` | `AgentDialogResponse` — the customer's sessions with the agent and the messages of one |
| `agent(message, {sessionId, locations})` | `AgentResponse` — the agent's answer, with the products it picked |

The methods send no search event: call `sdk.tracking.search` when the user searched.

### The cart on the server

```dart
final items = await sdk.cart.get(); // the cart the server built from tracking
```

`cart.clear(shopSecret, {email, phone, loyaltyId, externalId, telegramId})`
empties the cart of the customer of the given ids. It is a server method: it takes
the shop's secret key, which the SDK neither keeps nor logs — and a secret in an
app's binary gives whoever unpacks it the shop's server access.

### Profile

| Method | Answer |
|---|---|
| `get()` | `Profile` — the fields the API gives without the shop's secret |
| `set(ProfileUpdateRequest)` | — writes only the fields given; `""` erases where the API allows it |
| `getLastOrder()` | `List<Product>` — the products of the customer's last order |
| `getOrders(shopSecret, {did, email, phone, loyaltyId, externalId, dateFrom})` | `List<Order>` — a server method, with the shop's secret (see [the cart](#the-cart-on-the-server)) |

```dart
await sdk.profile.set(
  const ProfileUpdateRequest(
    externalId: 'customer-42',
    firstName: 'Anna',
    gender: Gender.female,
    birthday: '1990-05-17',            // YYYY-MM-DD
    customProperties: {'tier': 'gold'},
  ),
);
```

### Subscriptions and segments

```dart
await sdk.subscriptions.manage(
  const SubscriptionsUpdateRequest(emailBulk: true, smsBulk: false),
);
final status = await sdk.subscriptions.check();               // SubscriptionStatus
await sdk.subscriptions.subscribeForPriceDrop('37', 1990);
await sdk.subscriptions.unsubscribeFromPriceDrop(const []);    // [] — every product
await sdk.subscriptions.subscribeForBackInStock(
  '37',
  properties: const BackInStockProperties(fashionSize: '42'),
);
await sdk.subscriptions.unsubscribeFromBackInStock(const ['37']);

await sdk.segments.add(12);
await sdk.segments.remove(12);
final segments = await sdk.segments.get();                    // List<Segment>
final group = sdk.segments.getAbGroup();                      // "A" or "B", at once
```

A contact (`email`, `phone`) tells which address or number a subscription is for,
and the server applies the call to the contact's owner: pass one only when it is
the customer's own.

A price-drop or back-in-stock subscription needs the customer's email: one passed
in the call, or one the server already knows for this device. Without it, or with
a phone alone, the call fails with `SdkException` of type `http` and code 400.

### Notifications

The plugin handles the SDK's pushes itself (it draws data pushes on Android and
handles the notification centre on iOS) and the native SDK reports their events.
On Android a process started only to deliver a push does not start the shop: the
push's events go with the device id kept from the last launch, and the shop starts,
with its `/init`, when the app calls `initialize()`.

| Member | What it does |
|---|---|
| `setCallbacks(PushCallbacks)` | this shop's callbacks: `onDelivered`, `onOpened`, `onClicked`, `onClosed`, `onToken` |
| `getPushToken({provider})` | `PushToken?`, at once — the token the native SDK knows for the shop |
| `setPushToken(token, provider)` | a token the app got itself (`autoSendPushToken: false`) |
| `trackDelivered` / `trackOpened` / `trackClicked` / `trackClosed` `(code, type)` | the events of a push the app draws itself |
| `getHistory(shopSecret, type, {…})` | `NotificationHistory` — a server method, with the shop's secret |

```dart
sdk.notifications.setCallbacks(
  PushCallbacks(
    onClicked: (push) => openTarget(push.target), // the SDK opens nothing itself
    onToken: (token) => debugPrint('${token.provider}: new token'),
  ),
);
```

`REES46.setPushCallbacks(PushCallbacks(…))` sets them for every shop at once; a
shop's own callback of an event wins.

### Stories, predict, loyalty

```dart
final stories = await sdk.stories.get('stories-code');        // StoriesBlock
final probability = await sdk.predict.getProbabilityToPurchase();

final member = await sdk.loyalty.join('+79991234567', firstName: 'Anna');
final loyaltyStatus = await sdk.loyalty.getStatus('+79991234567');
final promotions = await sdk.loyalty.getPromotions(currentTime: '18:30');
```

### Sliders

```dart
final slider = await sdk.sliders.get('main_slider', tags: ['home']); // BannerSlider
```

The app draws the carousel and reports its banners with
[`tracking.bannerView` and `bannerClick`](#banners).

### Reviews

```dart
final channels = await sdk.reviews.getNpsChannels();
final categories = await sdk.reviews.getNpsCategories();
await sdk.reviews.createNps(9, 'android_app', 'delivery', comment: 'Fast');
await sdk.reviews.createCsat(5, 'android_app', 'support');
await sdk.reviews.createCes(7, 'android_app', 'checkout');

final reviews = await sdk.reviews.getProductReviews('37', limit: 10);
final mine = await sdk.reviews.getClientReviews('order-1024');
```

### Released methods

The methods of earlier releases keep working as deprecated delegates of the
namespaces, with their released types:

| Released | Namespace |
|---|---|
| `getProductInfo`, `getProductsList`, `getProductCounters`, `getCategory` | `products.getInfo`, `getList`, `getCounters`, `getCategory` |
| `getCollection` | `collections.get` |
| `getRecommendation` | `recommendations.get` |
| `searchBlank`, `searchInstant`, `searchFull` | `search.blank`, `instant`, `full` |
| `getProfile`, `setProfile` | `profile.get`, `profile.set` |
| `manageSubscription` (`ManageSubscriptionParams`) | `subscriptions.manage` (`SubscriptionsUpdateRequest`) |
| `joinLoyalty`, `getLoyaltyStatus` | `loyalty.join`, `loyalty.getStatus` |
| `getStories` | `stories.get` |
| `getStoredPushToken`, `setPushNotificationCallbacks` | `notifications.getPushToken`, `notifications.setCallbacks` |
| `trackEvent`, `trackPurchase` | `tracking.custom`, `tracking.purchase` |

## Example app

A full demo — tracking, recommendations, search, catalog, loyalty, popups, push
and two shops side by side — lives in [`example/`](example):

```bash
cd example
flutter run
```

## Links

- [Android SDK documentation](https://rees46.ru/help/integration/cdp/sdk/kotlin.html)
- [iOS SDK documentation](https://rees46.ru/help/integration/cdp/sdk/swift.html)
- [Issue tracker](https://github.com/rees46/flutter-sdk/issues)

## License

MIT — see [LICENSE](LICENSE).
