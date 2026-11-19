import 'dart:convert';

import '../models/values.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;

class ProfileParams {
  final String? email;
  final String? phone;
  final String? loyaltyId;
  final String? firstName;
  final String? lastName;

  /// Date of birth in "yyyy-MM-dd" format.
  final String? birthday;
  final int? age;
  final Gender? gender;
  final String? location;
  final String? advertisingId;
  final String? fbId;
  final String? vkId;
  final String? telegramId;
  final String? loyaltyCardLocation;
  final String? loyaltyStatus;
  final int? loyaltyBonuses;
  final int? loyaltyBonusesToNextLevel;
  final bool? boughtSomething;
  final String? userId;
  final Map<String, Object?>? customProperties;

  const ProfileParams({
    this.email,
    this.phone,
    this.loyaltyId,
    this.firstName,
    this.lastName,
    this.birthday,
    this.age,
    this.gender,
    this.location,
    this.advertisingId,
    this.fbId,
    this.vkId,
    this.telegramId,
    this.loyaltyCardLocation,
    this.loyaltyStatus,
    this.loyaltyBonuses,
    this.loyaltyBonusesToNextLevel,
    this.boughtSomething,
    this.userId,
    this.customProperties,
  });

  /// These parameters as the released `setProfile` hands them to the native SDKs, as
  /// in 1.6.4: the custom properties as a JSON object.
  pigeon.ProfileParamsWire toWire() {
    return pigeon.ProfileParamsWire(
      email: email,
      phone: phone,
      loyaltyId: loyaltyId,
      firstName: firstName,
      lastName: lastName,
      birthday: birthday,
      age: age,
      gender: gender?.wireValue,
      location: location,
      advertisingId: advertisingId,
      fbId: fbId,
      vkId: vkId,
      telegramId: telegramId,
      loyaltyCardLocation: loyaltyCardLocation,
      loyaltyStatus: loyaltyStatus,
      loyaltyBonuses: loyaltyBonuses,
      loyaltyBonusesToNextLevel: loyaltyBonusesToNextLevel,
      boughtSomething: boughtSomething,
      userId: userId,
      customPropertiesJson: customProperties == null
          ? null
          : jsonEncode(customProperties),
    );
  }
}
