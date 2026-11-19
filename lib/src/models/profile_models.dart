// Models of the SDK contract, as the native SDKs hand them over.

import 'catalog.dart';
import 'values.dart';

/// The customer's profile as the API gives it without the shop's secret: no name, email or phone.
class Profile {
  const Profile({
    this.id,
    this.hasEmail,
    this.emailRegisteredAt,
    this.gender,
    this.computedGender,
    this.boughtSomething,
    this.customProperties = const <String, Object?>{},
  });

  /// The customer's id on the server (not the shop's external id).
  final String? id;

  final bool? hasEmail;

  /// When the shop first got the email, `YYYY-MM-DD HH:MM:SS`.
  final String? emailRegisteredAt;

  final Gender? gender;

  /// The gender the server worked out.
  final Gender? computedGender;

  final bool? boughtSomething;

  /// The shop's public custom properties.
  final Map<String, Object?> customProperties;
}

/// A child of the customer, for [ProfileUpdateRequest.kids].
class ProfileKid {
  const ProfileKid({this.gender, this.birthday});

  final Gender? gender;

  /// `YYYY-MM-DD`.
  final String? birthday;
}

/// A car of the customer, for [ProfileUpdateRequest.cars] (`auto` on the wire).
class ProfileCar {
  const ProfileCar({this.brand, this.model, this.vds});

  final String? brand;

  final String? model;

  final String? vds;
}

/// The properties [ProfileApi.set] writes. Only the fields given change: `null` is not sent; `""` erases where the API allows it.
class ProfileUpdateRequest {
  const ProfileUpdateRequest({
    this.email,
    this.phone,
    this.externalId,
    this.loyaltyId,
    this.telegramId,
    this.fbId,
    this.vkId,
    this.firstName,
    this.lastName,
    this.gender,
    this.birthday,
    this.age,
    this.location,
    this.kids,
    this.cars,
    this.customProperties,
  });

  final String? email;

  final String? phone;

  /// The customer's id in the shop's system; sent as `id` and `external_id`.
  final String? externalId;

  final String? loyaltyId;

  final String? telegramId;

  final String? fbId;

  final String? vkId;

  final String? firstName;

  final String? lastName;

  final Gender? gender;

  /// `YYYY-MM-DD`; `""` erases it.
  final String? birthday;

  /// 0 erases it.
  final int? age;

  /// The city: a location id of the product feed.
  final String? location;

  final List<ProfileKid>? kids;

  final List<ProfileCar>? cars;

  /// Properties set up in the shop's account, sent at the top level: strings, numbers, booleans, null, lists and maps of them.
  final Map<String, Object?>? customProperties;
}

/// A line of an [Order], as the native SDKs' released model has it: sums are strings.
class OrderItem {
  const OrderItem({
    this.amount,
    this.price,
    this.status,
    this.originalPrice,
    this.barcode,
    this.lineId,
    this.cancelReason,
    this.item,
  });

  final int? amount;

  final String? price;

  final String? status;

  final String? originalPrice;

  final String? barcode;

  final String? lineId;

  final String? cancelReason;

  /// The product, as far as the order carries it.
  final Product? item;
}

/// An order of the customer ([ProfileApi.getOrders]), the native SDKs' released model: sums are strings.
class Order {
  const Order({
    this.internalId,
    this.id,
    this.date,
    this.value,
    this.cashValue,
    this.bonusesValue,
    this.deliveryValue,
    this.promocode,
    this.deliveryDate,
    this.internalStatus,
    this.stream,
    this.channel,
    this.taxFree,
    this.deliveryType,
    this.deliveryAddress,
    this.orderStatus,
    this.paymentType,
    required this.items,
  });

  /// The server's own id (`_id`).
  final int? internalId;

  /// The shop's order id.
  final String? id;

  final String? date;

  final String? value;

  final String? cashValue;

  final String? bonusesValue;

  final String? deliveryValue;

  final String? promocode;

  final String? deliveryDate;

  final String? internalStatus;

  final String? stream;

  final String? channel;

  final bool? taxFree;

  final String? deliveryType;

  final String? deliveryAddress;

  final String? orderStatus;

  final String? paymentType;

  final List<OrderItem> items;
}
