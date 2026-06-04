import '../pigeon/personalization_api.g.dart' as pigeon;

/// Holds optional Dart callbacks for push-related events coming from native code.
class PushNotificationCallbacks implements pigeon.PersonalizationFlutterApi {
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

  @override
  void onPushReceived(Map<String, String?> payload) {
    _onReceived?.call(Map<String, String?>.from(payload));
  }

  @override
  void onPushDelivered(Map<String, String?> payload) {
    _onDelivered?.call(Map<String, String?>.from(payload));
  }

  @override
  void onPushClicked(Map<String, String?> payload) {
    _onClicked?.call(Map<String, String?>.from(payload));
  }
}
