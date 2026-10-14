import '../pigeon/personalization_api.g.dart' as pigeon;

/// Changes to a client's subscriptions for [PersonalizationSdk.manageSubscription].
///
/// [email], [phone], [externalId], [loyaltyId] and [telegramId] identify the client; the device is
/// always sent. Each flag is a channel and mailing type: `true` subscribes, `false` unsubscribes,
/// `null` keeps the current status. Wallet has the bulk type only.
class ManageSubscriptionParams {
  final String? email;
  final String? phone;
  final String? externalId;
  final String? loyaltyId;
  final String? telegramId;
  final bool? emailBulk;
  final bool? emailChain;
  final bool? emailTransactional;
  final bool? smsBulk;
  final bool? smsChain;
  final bool? smsTransactional;
  final bool? webPushBulk;
  final bool? webPushChain;
  final bool? webPushTransactional;
  final bool? mobilePushBulk;
  final bool? mobilePushChain;
  final bool? mobilePushTransactional;
  final bool? telegramBulk;
  final bool? telegramChain;
  final bool? telegramTransactional;
  final bool? whatsappBulk;
  final bool? whatsappChain;
  final bool? whatsappTransactional;
  final bool? maxBulk;
  final bool? maxChain;
  final bool? maxTransactional;
  final bool? walletBulk;

  const ManageSubscriptionParams({
    this.email,
    this.phone,
    this.externalId,
    this.loyaltyId,
    this.telegramId,
    this.emailBulk,
    this.emailChain,
    this.emailTransactional,
    this.smsBulk,
    this.smsChain,
    this.smsTransactional,
    this.webPushBulk,
    this.webPushChain,
    this.webPushTransactional,
    this.mobilePushBulk,
    this.mobilePushChain,
    this.mobilePushTransactional,
    this.telegramBulk,
    this.telegramChain,
    this.telegramTransactional,
    this.whatsappBulk,
    this.whatsappChain,
    this.whatsappTransactional,
    this.maxBulk,
    this.maxChain,
    this.maxTransactional,
    this.walletBulk,
  });

  pigeon.ManageSubscriptionParamsWire toWire() {
    return pigeon.ManageSubscriptionParamsWire(
      email: email,
      phone: phone,
      externalId: externalId,
      loyaltyId: loyaltyId,
      telegramId: telegramId,
      emailBulk: emailBulk,
      emailChain: emailChain,
      emailTransactional: emailTransactional,
      smsBulk: smsBulk,
      smsChain: smsChain,
      smsTransactional: smsTransactional,
      webPushBulk: webPushBulk,
      webPushChain: webPushChain,
      webPushTransactional: webPushTransactional,
      mobilePushBulk: mobilePushBulk,
      mobilePushChain: mobilePushChain,
      mobilePushTransactional: mobilePushTransactional,
      telegramBulk: telegramBulk,
      telegramChain: telegramChain,
      telegramTransactional: telegramTransactional,
      whatsappBulk: whatsappBulk,
      whatsappChain: whatsappChain,
      whatsappTransactional: whatsappTransactional,
      maxBulk: maxBulk,
      maxChain: maxChain,
      maxTransactional: maxTransactional,
      walletBulk: walletBulk,
    );
  }
}
