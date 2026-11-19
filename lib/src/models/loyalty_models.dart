// Models of the SDK contract, as the native SDKs hand them over.

import '../loyalty/loyalty_response.dart';
import 'values.dart';

/// A member of the loyalty program.
class LoyaltyMember {
  const LoyaltyMember({required this.identifier});

  /// The phone the program knows the member by.
  final String identifier;
}

/// Whether the customer is a member of the loyalty program, and on which level.
class LoyaltyStatus {
  const LoyaltyStatus({required this.isMember, this.level});

  final bool isMember;

  final LoyaltyLevel? level;
}

/// An active promotion of the loyalty program that suits the customer.
class LoyaltyPromotion {
  const LoyaltyPromotion({
    required this.id,
    required this.name,
    this.description,
    this.startDate,
    this.finishDate,
    this.stream,
    this.badgeLabel,
    this.badgeColor,
    this.rewardType,
  });

  /// 64-bit.
  final int id;

  final String name;

  final String? description;

  final String? startDate;

  final String? finishDate;

  final String? stream;

  final String? badgeLabel;

  final String? badgeColor;

  /// None for a type this release does not know.
  final LoyaltyRewardType? rewardType;
}
