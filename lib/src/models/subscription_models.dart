// Models of the SDK contract, as the native SDKs hand them over.

/// The customer's subscriptions on every channel ([SubscriptionsApi.check]).
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.exists,
    required this.emailBulk,
    required this.emailChain,
    required this.emailTransactional,
    required this.smsBulk,
    required this.smsChain,
    required this.smsTransactional,
    required this.webPushBulk,
    required this.webPushChain,
    required this.webPushTransactional,
    required this.mobilePushBulk,
    required this.mobilePushChain,
    required this.mobilePushTransactional,
    required this.telegramBulk,
    required this.telegramChain,
    required this.telegramTransactional,
    required this.whatsappBulk,
    required this.whatsappChain,
    required this.whatsappTransactional,
    required this.maxBulk,
    required this.maxChain,
    required this.maxTransactional,
    required this.walletBulk,
    required this.walletChain,
    required this.walletTransactional,
    required this.hasWebPush,
    required this.hasMobilePush,
    required this.emailInvalid,
    required this.emailBlacklisted,
    required this.emailBounced,
    required this.emailSuppressed,
    required this.emailConfirmed,
  });

  /// Whether the server knows the customer.
  final bool exists;

  final bool emailBulk;

  final bool emailChain;

  final bool emailTransactional;

  final bool smsBulk;

  final bool smsChain;

  final bool smsTransactional;

  final bool webPushBulk;

  final bool webPushChain;

  final bool webPushTransactional;

  final bool mobilePushBulk;

  final bool mobilePushChain;

  final bool mobilePushTransactional;

  final bool telegramBulk;

  final bool telegramChain;

  final bool telegramTransactional;

  final bool whatsappBulk;

  final bool whatsappChain;

  final bool whatsappTransactional;

  final bool maxBulk;

  final bool maxChain;

  final bool maxTransactional;

  final bool walletBulk;

  final bool walletChain;

  final bool walletTransactional;

  final bool hasWebPush;

  final bool hasMobilePush;

  final bool emailInvalid;

  final bool emailBlacklisted;

  final bool emailBounced;

  final bool emailSuppressed;

  final bool emailConfirmed;
}

/// The variant of a product a back-in-stock subscription is for.
class BackInStockProperties {
  const BackInStockProperties({
    this.fashionSize,
    this.fashionColor,
    this.barcode,
  });

  final String? fashionSize;

  final String? fashionColor;

  final String? barcode;
}
