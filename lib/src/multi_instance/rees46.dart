import 'package:flutter/foundation.dart';

import '../personalization_sdk.dart';
import 'instance_resolver.dart';
import 'push_event.dart';
import 'rees46_config.dart';
import 'sdk_exceptions.dart';

/// Builds and initializes a [PersonalizationSdk] handle for [config]. Injectable
/// so tests can resolve shops without touching native or Pigeon.
typedef Rees46SdkFactory = PersonalizationSdk Function(Rees46Config config);

/// Public entry point for the Flutter SDK — the unified, multi-instance API.
///
/// A host no longer keeps its own [PersonalizationSdk]: initialize (or register)
/// shops here and reach them by `shopId` through [getInstance]. One instance per
/// shop, each bound to a native instance with isolated storage and state.
///
/// ```dart
/// // Single shop:
/// final sdk = Rees46.initialize(Rees46Config(shopId: 'SHOP_ID'));
/// sdk.trackEvent('category', ...);
///
/// // Several shops, initialized lazily on first use:
/// Rees46.registerShops([Rees46Config(shopId: 'shop-a'), Rees46Config(shopId: 'shop-b')]);
/// Rees46.getInstance('shop-a').trackEvent('category', ...);
/// ```
///
/// ## Why the facade holds a shop-id mirror
///
/// The Flutter SDK is a **thin bridge over the native Android/iOS SDKs**, where
/// the real registry, storage partitions, identity migration, push routing and
/// session isolation already live. This facade does **not** reimplement any of
/// that. It keeps a small Dart-side mirror of the *registered shop-ids* purely
/// to (a) resolve which shop a call targets and (b) raise the ambiguous/unknown
/// contract synchronously, identically to native. The native `SdkRegistry`
/// remains the source of truth for the instances themselves.
///
/// Per-call routing to a specific native instance (threading `shopId` through
/// every Pigeon call) lands once the native `Rees46` facade ships in the
/// consumed artifacts — see the plan (`Multi-instance — Flutter Plan`, step F3).
/// Until then single-shop [initialize] is fully functional and the resolution
/// contract below is complete and tested.
class Rees46 {
  Rees46._();

  static final Rees46 _instance = Rees46._();

  /// Live (initialized) instances by shop id. The Dart-side mirror of the
  /// native registry — used for resolution only.
  final Map<String, PersonalizationSdk> _live = <String, PersonalizationSdk>{};

  /// Shops registered lazily and not yet initialized. Materialized on the first
  /// [getInstance] for the shop.
  final Map<String, Rees46Config> _pending = <String, Rees46Config>{};

  Rees46SdkFactory _factory = _defaultFactory;

  static PersonalizationSdk _defaultFactory(Rees46Config config) {
    final sdk = PersonalizationSdk(shopId: config.shopId);
    // F1: delegates to the existing single-shop native init. Per-call `shopId`
    // routing to the native `Rees46` facade lands in plan step F3.
    sdk.initialize(config.toSdkInitConfig());
    return sdk;
  }

  // ---------------------------------------------------------------------------
  // Public API (static — delegates to the process-global instance)
  // ---------------------------------------------------------------------------

  /// Initializes an SDK instance for [config] immediately and returns it. The
  /// instance is registered, so it is also reachable via [getInstance]. Any
  /// pending registration for the same shop is cleared.
  static PersonalizationSdk initialize(Rees46Config config) =>
      _instance._initialize(config);

  /// Registers [configs] without initializing them. Initialization happens
  /// lazily on the first [getInstance] for a shop — the region case, where only
  /// the current region is needed. Pass [eagerInit] = true to initialize every
  /// shop up front — the super-shop case, where instances must stay consistent.
  static void registerShops(
    List<Rees46Config> configs, {
    bool eagerInit = false,
  }) => _instance._registerShops(configs, eagerInit: eagerInit);

  /// Returns the SDK instance for [shopId], initializing a pending registration
  /// on first use. With no [shopId], returns the single instance when exactly
  /// one shop is registered.
  ///
  /// Throws [AmbiguousShopException] when [shopId] is null and more than one
  /// shop is registered; [UnknownShopIdException] when the shop is unknown.
  static PersonalizationSdk getInstance([String? shopId]) =>
      _instance._getInstance(shopId);

  /// True when an instance is available for [shopId] — or, with no [shopId],
  /// when exactly one shop is initialized so the default is unambiguous. A
  /// pending (registered-but-not-initialized) shop is not counted as initialized.
  static bool isInitialized([String? shopId]) =>
      _instance._isInitialized(shopId);

  /// Routes a push to the shop it belongs to (the payload's `shop_id`) and tracks
  /// [event] for it via the native `Rees46.handlePush`, then fires that shop's
  /// registered push callbacks. Call this from a host that owns its messaging
  /// service.
  ///
  /// Resolution mirrors [getInstance] (live wins over pending; a single
  /// registered shop resolves with no `shop_id`) but **drops** instead of
  /// throwing: an unknown shop, or an absent `shop_id` while several shops are
  /// registered, is not delivered to the wrong one. A pending shop is
  /// materialized so it has a live instance to track on.
  ///
  /// Returns the shop id the push routed to, or `null` if it was dropped.
  static Future<String?> handlePush(
    Map<String, String> payload,
    PushEvent event,
  ) => _instance._handlePush(payload, event);

  /// Shops that are live (initialized), sorted.
  static List<String> get liveShopIds => _instance._live.keys.toList()..sort();

  /// Shops registered lazily and not yet initialized, sorted.
  static List<String> get pendingShopIds =>
      _instance._pending.keys.toList()..sort();

  // ---------------------------------------------------------------------------
  // Instance implementation
  // ---------------------------------------------------------------------------

  PersonalizationSdk _initialize(Rees46Config config) {
    final sdk = _factory(config);
    _live[config.shopId] = sdk;
    _pending.remove(config.shopId);
    return sdk;
  }

  void _registerShops(List<Rees46Config> configs, {required bool eagerInit}) {
    for (final config in configs) {
      if (eagerInit) {
        _initialize(config);
      } else {
        _pending[config.shopId] = config;
      }
    }
  }

  PersonalizationSdk _getInstance(String? shopId) {
    final resolution = InstanceResolver.resolve(
      requestedShopId: shopId,
      liveShopIds: _live.keys.toSet(),
      pendingShopIds: _pending.keys.toSet(),
    );
    return switch (resolution) {
      ExistingResolution(:final shopId) =>
        _live[shopId] ?? (throw UnknownShopIdException(shopId)),
      PendingResolution(:final shopId) => _materialize(shopId),
      NotRegisteredResolution() => throw UnknownShopIdException(shopId),
      AmbiguousResolution() => throw AmbiguousShopException(
        _registeredShopIds(),
      ),
    };
  }

  bool _isInitialized(String? shopId) =>
      shopId != null ? _live.containsKey(shopId) : _live.length == 1;

  static const String _shopIdKey = 'shop_id';

  Future<String?> _handlePush(
    Map<String, String> payload,
    PushEvent event,
  ) async {
    final resolution = InstanceResolver.resolve(
      requestedShopId: payload[_shopIdKey],
      liveShopIds: _live.keys.toSet(),
      pendingShopIds: _pending.keys.toSet(),
    );
    final PersonalizationSdk sdk;
    switch (resolution) {
      case ExistingResolution(:final shopId):
        sdk = _live[shopId]!;
      case PendingResolution(:final shopId):
        // Materialize so native has a live instance to track on.
        sdk = _materialize(shopId);
      case NotRegisteredResolution():
      case AmbiguousResolution():
        return null; // drop — unknown shop, or ambiguous (no shop_id, several live)
    }
    await sdk.handlePush(payload, event);
    sdk.dispatchInboundPush(event, payload);
    return sdk.shopId;
  }

  /// Initializes a pending registration for [shopId]. If the registration is
  /// gone (materialized by a concurrent caller), falls back to the live map.
  PersonalizationSdk _materialize(String shopId) {
    final config = _pending.remove(shopId);
    if (config != null) {
      return _initialize(config);
    }
    return _live[shopId] ?? (throw UnknownShopIdException(shopId));
  }

  List<String> _registeredShopIds() =>
      <String>{..._live.keys, ..._pending.keys}.toList()..sort();

  // ---------------------------------------------------------------------------
  // Test hooks
  // ---------------------------------------------------------------------------

  /// Test-only: overrides the factory that builds/initializes instances so shop
  /// resolution can be exercised without touching native or Pigeon.
  @visibleForTesting
  static set debugFactory(Rees46SdkFactory factory) =>
      _instance._factory = factory;

  /// Test-only: drops all live and pending registrations and restores the
  /// default factory.
  @visibleForTesting
  static void reset() {
    _instance._live.clear();
    _instance._pending.clear();
    _instance._factory = _defaultFactory;
  }
}
