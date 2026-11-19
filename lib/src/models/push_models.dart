// Models of the SDK contract, as the native SDKs hand them over.

import 'values.dart';

/// A push token and the service it is of.
class PushToken {
  const PushToken({required this.token, required this.provider});

  final String token;

  final PushProvider provider;
}

/// A button of a push.
class PushAction {
  const PushAction({required this.id, required this.title, this.url});

  final String id;

  final String title;

  /// The link of the button, when it has one.
  final String? url;
}

/// What to open when the push is tapped (`event`).
class PushTarget {
  const PushTarget({
    required this.type,
    required this.uri,
    required this.payload,
  });

  final PushTargetType type;

  /// A link, a product id, a category id or the app's own link.
  final String uri;

  /// Free-form.
  final Map<String, Object?> payload;
}

/// A push of the SDK, as the native SDK parsed it.
class PushPayload {
  const PushPayload({
    this.shopId,
    required this.code,
    required this.type,
    this.title,
    this.body,
    this.icon,
    this.image,
    required this.actions,
    this.target,
    this.source,
    this.sound,
    required this.data,
  });

  /// The shop the push is of.
  final String? shopId;

  /// The message's code (`id`).
  final String code;

  /// The mailing type: `bulk`, `chain`, `transactional`, `digest`.
  final String type;

  final String? title;

  final String? body;

  final String? icon;

  final String? image;

  final List<PushAction> actions;

  final PushTarget? target;

  /// The mailing's `utm_source`.
  final String? source;

  final String? sound;

  /// The whole push as it came.
  final Map<String, Object?> data;
}

/// What happened to a message of [NotificationHistory].
class NotificationStatistics {
  const NotificationStatistics({
    required this.clicked,
    required this.complained,
    required this.hardBounced,
    required this.opened,
    required this.purchased,
    required this.softBounced,
    required this.unsubscribed,
  });

  final bool clicked;

  final bool complained;

  final bool hardBounced;

  final bool opened;

  final bool purchased;

  final bool softBounced;

  final bool unsubscribed;
}

/// A message the shop sent the customer.
class NotificationMessage {
  const NotificationMessage({
    this.body,
    this.campaignId,
    this.channel,
    this.code,
    this.date,
    this.icon,
    this.picture,
    this.sentAt,
    this.statistics,
    this.subject,
    this.type,
    this.url,
  });

  final String? body;

  final int? campaignId;

  final String? channel;

  final String? code;

  final String? date;

  final String? icon;

  final String? picture;

  final String? sentAt;

  final NotificationStatistics? statistics;

  final String? subject;

  final String? type;

  final String? url;
}

/// The messages the shop sent the customer ([NotificationsApi.getHistory]).
class NotificationHistory {
  const NotificationHistory({this.status, required this.messages});

  final String? status;

  final List<NotificationMessage> messages;
}

/// The app's callbacks on pushes: for one shop with `notifications.setCallbacks`,
/// for every shop with `REES46.setPushCallbacks`; a shop's own callback of an event
/// wins over the shared one.
///
/// A callback runs on the main isolate when the native SDK sees its event: its
/// messaging service, a notification the SDK drew, the notification centre (iOS) or
/// `REES46.handlePush`. One event of one message is reported once per process. All
/// are optional; `PushCallbacks()` with none clears them.
class PushCallbacks {
  const PushCallbacks({
    this.onDelivered,
    this.onOpened,
    this.onClicked,
    this.onClosed,
    this.onToken,
  });

  /// The push reached the app.
  final void Function(PushPayload payload)? onDelivered;

  /// The notification was shown.
  final void Function(PushPayload payload)? onOpened;

  /// The notification was tapped: what to open is [PushPayload.target]; the SDK
  /// opens nothing itself.
  final void Function(PushPayload payload)? onClicked;

  /// The notification was dismissed without a tap.
  final void Function(PushPayload payload)? onClosed;

  /// The native SDK got a new token from APNs, FCM or HMS, once per token and
  /// provider in a process.
  final void Function(PushToken token)? onToken;
}
