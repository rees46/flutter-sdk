/// Exceptions raised by [Rees46] shop resolution.
///
/// They mirror the native contract so the same failure modes surface
/// identically on every platform (see `Multi-instance — Contracts`):
///   * Android — `UnknownShopIdException` / `AmbiguousShopException`
///   * iOS     — `Rees46Error.unknownShopId` / `.ambiguousShop`
///
/// The Flutter SDK is a thin bridge over the native SDKs, so these are raised by
/// the Dart facade's own resolver (a mirror of the registered shop-ids) — the
/// resolution rules are identical, only the throw site is in Dart.
library;

/// Thrown when an instance is requested for a shop that is neither initialized
/// nor registered — nothing registered at all, or no such shop id.
class UnknownShopIdException implements Exception {
  const UnknownShopIdException(this.shopId, [this.customMessage]);

  /// The requested shop id, or `null` when [Rees46.getInstance] was called with
  /// no id while nothing at all is registered.
  final String? shopId;

  /// Optional override for the default human-readable message.
  final String? customMessage;

  String get message =>
      customMessage ??
      (shopId != null
          ? 'No shop is registered for shopId=$shopId. '
                'Call Rees46.initialize(...) or Rees46.registerShops(...) first.'
          : 'No shop has been registered. '
                'Call Rees46.initialize(...) or Rees46.registerShops(...) first.');

  @override
  String toString() => 'UnknownShopIdException: $message';
}

/// Thrown when [Rees46.getInstance] is called with no shop id while more than
/// one shop is registered — the default instance is ambiguous.
class AmbiguousShopException implements Exception {
  const AmbiguousShopException(this.registeredShopIds, [this.customMessage]);

  /// The shops (live + pending) that made the default ambiguous, sorted.
  final List<String> registeredShopIds;

  /// Optional override for the default human-readable message.
  final String? customMessage;

  String get message =>
      customMessage ??
      'More than one shop is registered — call Rees46.getInstance(shopId) with '
          'an explicit id. Registered: $registeredShopIds.';

  @override
  String toString() => 'AmbiguousShopException: $message';
}
