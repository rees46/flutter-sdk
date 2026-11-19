// The closed sets (Dart enums) and the open ones (classes of string constants the server
// may extend) of the SDK contract.

/// Where a shop's native instance stands with its initialization (`/init`).
enum SdkState {
  /// Not initialized yet, or released: every call fails with `notInitialized`.
  notInitialized,

  /// `/init` is on its way; requests with a result wait for it.
  initializing,

  /// The instance has its device id and works.
  ready,

  /// `/init` did not go through and is being repeated. With a device id from an
  /// earlier launch the instance works as [ready].
  retrying,

  /// The shop turned the SDK away: calls fail with `shopBlocked`.
  refused,
}

/// The gender of a customer, a child or a loyalty member.
enum Gender {
  male('m'),
  female('f');

  const Gender(this.wireValue);

  /// The value the API takes: `m` or `f`.
  final String wireValue;
}

/// The released name of [Gender].
@Deprecated('Use Gender.')
typedef ProfileGender = Gender;

/// The direction of a listing's or a search's order.
enum SortDirection {
  asc,
  desc;

  /// The value the API takes.
  String get wireValue => name;
}

/// What a listing or a search is ordered by. An open set: the server may add a key,
/// and the app passes it as `SortBy('key')` without a new release.
class SortBy {
  const SortBy(this.value);

  final String value;

  static const price = SortBy('price');
  static const discount = SortBy('discount');
  static const salesRate = SortBy('sales_rate');
  static const date = SortBy('date');
  static const priceMargin = SortBy('price_margin');

  /// The server applies it only together with another key, which the SDK cannot
  /// send yet.
  static const rating = SortBy('rating');

  /// Only for `search.full`; a listing or a category fails with `invalidArgument`.
  static const relevance = SortBy('relevance');

  @override
  bool operator ==(Object other) => other is SortBy && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Who wrote a message of a dialog with the search agent. An open set.
class AgentMessageRole {
  const AgentMessageRole(this.value);

  final String value;

  /// The customer.
  static const user = AgentMessageRole('user');

  /// The agent.
  static const assistant = AgentMessageRole('assistant');

  @override
  bool operator ==(Object other) =>
      other is AgentMessageRole && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// The service a push token is of.
enum PushProvider {
  /// Apple Push Notification service (iOS).
  apns,

  /// Firebase Cloud Messaging (Android, and iOS through Firebase).
  fcm,

  /// Huawei Mobile Services (Android).
  hms;

  /// The value of the native channel.
  String get wireValue => name;
}

/// What [PushTarget.uri] is. An open set: the server understands `web` and
/// `carousel` itself, the others are an agreement with the app.
class PushTargetType {
  const PushTargetType(this.value);

  final String value;

  static const web = PushTargetType('web');
  static const product = PushTargetType('product');
  static const category = PushTargetType('category');
  static const carousel = PushTargetType('carousel');
  static const custom = PushTargetType('custom');

  @override
  bool operator ==(Object other) =>
      other is PushTargetType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// What a promotion of the loyalty program gives.
enum LoyaltyRewardType {
  discount('discount'),
  bonusesEarn('bonuses_earn'),
  bonusesUsage('bonuses_usage');

  const LoyaltyRewardType(this.wireValue);

  final String wireValue;
}

/// Where a review stands in moderation.
enum ReviewState {
  moderation,
  published,
  rejected;

  String get wireValue => name;
}

/// The gender of [wire] (`m` / `f`); null for none or another value.
Gender? genderFromWire(String? wire) => switch (wire) {
  'm' => Gender.male,
  'f' => Gender.female,
  _ => null,
};

/// The state of [wire]; [SdkState.notInitialized] for one this release does not
/// know.
SdkState sdkStateFromWire(String wire) => SdkState.values.firstWhere(
  (state) => state.name == wire,
  orElse: () => SdkState.notInitialized,
);

/// The provider of [wire]; [PushProvider.fcm] for one this release does not know.
PushProvider pushProviderFromWire(String wire) => PushProvider.values
    .firstWhere((p) => p.wireValue == wire, orElse: () => PushProvider.fcm);

/// The reward type of [wire]; null for none or one this release does not know.
LoyaltyRewardType? loyaltyRewardTypeFromWire(String? wire) {
  for (final type in LoyaltyRewardType.values) {
    if (type.wireValue == wire) return type;
  }
  return null;
}

/// The state of [wire]; null for none or one this release does not know.
ReviewState? reviewStateFromWire(String? wire) {
  for (final state in ReviewState.values) {
    if (state.wireValue == wire) return state;
  }
  return null;
}
