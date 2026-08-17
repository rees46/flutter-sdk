/// Pure decision logic behind [Rees46.getInstance]: given the requested `shopId`
/// (or none) and the sets of live and pending shops, decides which instance to
/// return, whether one must be lazily materialized, or which error to raise.
///
/// A faithful port of the native `InstanceResolver` (Android/iOS) — the rules
/// must stay byte-for-byte identical across platforms, so this file intentionally
/// mirrors the Kotlin original line for line. Kept side-effect-free so the rules
/// can be tested without constructing or initializing an SDK.
library;

/// Outcome of resolving a requested shop against the live and pending sets.
sealed class Resolution {
  const Resolution();
}

/// An initialized instance exists for this shop — return it.
class ExistingResolution extends Resolution {
  const ExistingResolution(this.shopId);
  final String shopId;

  @override
  bool operator ==(Object other) =>
      other is ExistingResolution && other.shopId == shopId;

  @override
  int get hashCode => Object.hash(ExistingResolution, shopId);

  @override
  String toString() => 'Existing($shopId)';
}

/// A registration exists but is not initialized yet — materialize it now.
class PendingResolution extends Resolution {
  const PendingResolution(this.shopId);
  final String shopId;

  @override
  bool operator ==(Object other) =>
      other is PendingResolution && other.shopId == shopId;

  @override
  int get hashCode => Object.hash(PendingResolution, shopId);

  @override
  String toString() => 'Pending($shopId)';
}

/// No live instance and no registration matches — raise
/// [UnknownShopIdException].
class NotRegisteredResolution extends Resolution {
  const NotRegisteredResolution();

  @override
  bool operator ==(Object other) => other is NotRegisteredResolution;

  @override
  int get hashCode => (NotRegisteredResolution).hashCode;

  @override
  String toString() => 'NotRegistered';
}

/// No shopId given and more than one shop registered — raise
/// [AmbiguousShopException].
class AmbiguousResolution extends Resolution {
  const AmbiguousResolution();

  @override
  bool operator ==(Object other) => other is AmbiguousResolution;

  @override
  int get hashCode => (AmbiguousResolution).hashCode;

  @override
  String toString() => 'Ambiguous';
}

abstract final class InstanceResolver {
  static Resolution resolve({
    required String? requestedShopId,
    required Set<String> liveShopIds,
    required Set<String> pendingShopIds,
  }) {
    if (requestedShopId != null) {
      if (liveShopIds.contains(requestedShopId)) {
        return ExistingResolution(requestedShopId);
      }
      if (pendingShopIds.contains(requestedShopId)) {
        return PendingResolution(requestedShopId);
      }
      return const NotRegisteredResolution();
    }

    final allShopIds = <String>{...liveShopIds, ...pendingShopIds};
    switch (allShopIds.length) {
      case 0:
        return const NotRegisteredResolution();
      case 1:
        final only = allShopIds.first;
        return liveShopIds.contains(only)
            ? ExistingResolution(only)
            : PendingResolution(only);
      default:
        return const AmbiguousResolution();
    }
  }
}
