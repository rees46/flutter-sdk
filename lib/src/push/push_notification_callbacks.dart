/// Holds one [PersonalizationSdk] handle's optional push callbacks.
///
/// No longer the Pigeon `PersonalizationFlutterApi` itself: with multi-instance,
/// a single process-global `PushDispatcher` implements that channel and routes
/// each inbound push (by `shopId`) to the matching handle's callbacks here.
class PushNotificationCallbacks {
  void Function(Map<String, String?> payload)? _onReceived;
  void Function(Map<String, String?> payload)? _onDelivered;
  void Function(Map<String, String?> payload)? _onClicked;

  void setCallbacks({
    void Function(Map<String, String?> payload)? onReceived,
    void Function(Map<String, String?> payload)? onDelivered,
    void Function(Map<String, String?> payload)? onClicked,
  }) {
    _onReceived = onReceived;
    _onDelivered = onDelivered;
    _onClicked = onClicked;
  }

  void onPushReceived(Map<String, String?> payload) {
    _onReceived?.call(Map<String, String?>.from(payload));
  }

  void onPushDelivered(Map<String, String?> payload) {
    _onDelivered?.call(Map<String, String?>.from(payload));
  }

  void onPushClicked(Map<String, String?> payload) {
    _onClicked?.call(Map<String, String?>.from(payload));
  }
}
