import '../errors/sdk_error.dart';
import '../models/loyalty_models.dart';
import '../models/values.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import 'from_wire.dart';

/// The loyalty program on the customer's side — the `loyalty` namespace. The SDK
/// never sends the shop's secret: [join] and [getStatus] answer only for a shop
/// that allows the loyalty methods from the front end (otherwise `http` 403).
class LoyaltyApi {
  LoyaltyApi(this._api, this._shopId);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;

  /// Makes [phone] a member of the loyalty program (`POST /loyalty/members/join`).
  /// A phone already registered is a success with the same member. `invalidArgument`
  /// for an empty [phone] or a [birthday] that is no date `YYYY-MM-DD`.
  Future<LoyaltyMember> join(
    String phone, {
    String? firstName,
    String? lastName,
    Gender? gender,
    String? birthday,
  }) async => loyaltyMemberFromWire(
    await sdkCall(
      () => _api.loyaltyJoin(
        phone,
        firstName,
        lastName,
        gender?.wireValue,
        birthday,
        _shopId,
      ),
    ),
  );

  /// Whether [phone] is a member, and on which level
  /// (`GET /loyalty/members/status`). Someone who is not a member is a success with
  /// `isMember` false.
  Future<LoyaltyStatus> getStatus(String phone) async => loyaltyStatusFromWire(
    await sdkCall(() => _api.loyaltyGetStatus(phone, _shopId)),
  );

  /// The active promotions that suit the customer and their cart
  /// (`GET /loyalty/promos/for-client`); none is an empty list. [currentTime] is the
  /// local time at the point of sale as `HH:MM`.
  Future<List<LoyaltyPromotion>> getPromotions({
    String? locationId,
    List<String>? promoCodes,
    bool? chargeBonuses,
    String? currentTime,
  }) async => List<LoyaltyPromotion>.unmodifiable(
    (await sdkCall(
      () => _api.loyaltyGetPromotions(
        locationId,
        promoCodes,
        chargeBonuses,
        currentTime,
        _shopId,
      ),
    )).map(loyaltyPromotionFromWire),
  );
}
