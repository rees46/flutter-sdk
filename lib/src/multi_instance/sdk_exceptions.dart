/// Exceptions raised by [REES46] shop resolution.
///
/// They mirror the native contract so the same failure modes surface
/// identically on every platform:
///   * Android — `Rees46Error`: `UnknownShopIdException` / `AmbiguousShopException`
///   * iOS     — `Rees46Error.unknownShopId` / `.ambiguousShop`
///
/// The Flutter SDK is a thin bridge over the native SDKs, so these are raised by
/// the Dart facade's own resolver (a mirror of the registered shop-ids) — the
/// resolution rules are identical, only the throw site is in Dart.
library;

/// The error of the facade (contract `Rees46Error`): the app's code asked for a
/// shop the facade cannot resolve. A mistake in the app's code, not a failure of
/// the SDK's work — so it is not an [SdkException]. Thrown at once by
/// [REES46.getInstance].
///
/// Its two cases are the released [UnknownShopIdException] (`unknownShop`) and
/// [AmbiguousShopException] (`ambiguousShop`): code that catches either of them
/// keeps working.
sealed class Rees46Exception implements Exception {
  const Rees46Exception();

  /// The case of the contract: `unknownShop` or `ambiguousShop`.
  Rees46ErrorType get type;

  /// A human-readable message in English.
  String get message;
}

/// The cases of [Rees46Exception].
enum Rees46ErrorType {
  /// No shop is registered for the requested id.
  unknownShop,

  /// No shop id was given while several shops are registered.
  ambiguousShop,
}

/// Thrown when an instance is requested for a shop that is neither initialized
/// nor registered — nothing registered at all, or no such shop id.
class UnknownShopIdException extends Rees46Exception {
  const UnknownShopIdException(this.shopId, [this.customMessage]);

  @override
  Rees46ErrorType get type => Rees46ErrorType.unknownShop;

  /// The requested shop id, or `null` when [REES46.getInstance] was called with
  /// no id while nothing at all is registered.
  final String? shopId;

  /// Optional override for the default human-readable message.
  final String? customMessage;

  @override
  String get message =>
      customMessage ??
      (shopId != null
          ? 'No shop is registered for shopId=$shopId. '
                'Call REES46.initialize(...) or REES46.registerShops(...) first.'
          : 'No shop has been registered. '
                'Call REES46.initialize(...) or REES46.registerShops(...) first.');

  @override
  String toString() => 'UnknownShopIdException: $message';
}

/// Thrown when [REES46.getInstance] is called with no shop id while more than
/// one shop is registered — the default instance is ambiguous.
class AmbiguousShopException extends Rees46Exception {
  const AmbiguousShopException(this.registeredShopIds, [this.customMessage]);

  @override
  Rees46ErrorType get type => Rees46ErrorType.ambiguousShop;

  /// The shops (live + pending) that made the default ambiguous, sorted.
  final List<String> registeredShopIds;

  /// Optional override for the default human-readable message.
  final String? customMessage;

  @override
  String get message =>
      customMessage ??
      'More than one shop is registered — call REES46.getInstance(shopId) with '
          'an explicit id. Registered: $registeredShopIds.';

  @override
  String toString() => 'AmbiguousShopException: $message';
}
