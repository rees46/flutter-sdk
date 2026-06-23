/// Response from [PersonalizationSdk.joinLoyalty] (`loyalty/members/join`).
///
/// The endpoint returns an envelope `{ "status": ..., "payload": { ... } }`.
/// [payload] is kept as a raw map because its shape differs between success
/// and failure responses.
class LoyaltyJoinResponse {
  final String? status;
  final Map<String, dynamic> payload;

  const LoyaltyJoinResponse({this.status, required this.payload});

  factory LoyaltyJoinResponse.fromJson(Map<String, dynamic> json) {
    return LoyaltyJoinResponse(
      status: json['status'] as String?,
      payload:
          (json['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }
}

/// Response from [PersonalizationSdk.getLoyaltyStatus] (`loyalty/members/status`).
///
/// Envelope: `{ "status": ..., "payload": { "member": ..., "level": { ... } } }`.
class LoyaltyStatusResponse {
  final String? status;
  final bool? member;
  final LoyaltyLevel? level;

  const LoyaltyStatusResponse({this.status, this.member, this.level});

  factory LoyaltyStatusResponse.fromJson(Map<String, dynamic> json) {
    final payload = (json['payload'] as Map?)?.cast<String, dynamic>();
    final levelJson = (payload?['level'] as Map?)?.cast<String, dynamic>();
    return LoyaltyStatusResponse(
      status: json['status'] as String?,
      member: payload?['member'] as bool?,
      level: levelJson == null ? null : LoyaltyLevel.fromJson(levelJson),
    );
  }
}

/// Loyalty level returned inside the `loyalty/members/status` payload.
class LoyaltyLevel {
  final String? name;
  final String? code;
  final String? expirationDate;

  const LoyaltyLevel({this.name, this.code, this.expirationDate});

  factory LoyaltyLevel.fromJson(Map<String, dynamic> json) {
    return LoyaltyLevel(
      name: json['name'] as String?,
      code: json['code'] as String?,
      expirationDate: json['expiration_date'] as String?,
    );
  }
}
