/// Response from [PersonalizationSdk.getProfile].
///
/// Mirrors native `GetProfileResponse`. All scalar fields are optional;
/// [customProperties] is kept as a raw map because its shape is shop-defined.
class ProfileResponse {
  final String? id;
  final String? email;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final bool? hasEmail;
  final String? emailRegisteredAt;
  final String? gender;
  final String? computedGender;
  final bool? boughtSomething;
  final Map<String, dynamic> customProperties;

  const ProfileResponse({
    this.id,
    this.email,
    this.phone,
    this.firstName,
    this.lastName,
    this.hasEmail,
    this.emailRegisteredAt,
    this.gender,
    this.computedGender,
    this.boughtSomething,
    this.customProperties = const <String, dynamic>{},
  });

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    return ProfileResponse(
      id: json['id'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      hasEmail: json['has_email'] as bool?,
      emailRegisteredAt: json['email_registered_at'] as String?,
      gender: json['gender'] as String?,
      computedGender: json['computed_gender'] as String?,
      boughtSomething: json['bought_something'] as bool?,
      customProperties:
          (json['custom_properties'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }
}
