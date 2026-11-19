import '../errors/sdk_error.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import '../sdk_init_config.dart';

class SdkInitHandler {
  final pigeon.PersonalizationHostApi _api;

  SdkInitHandler({pigeon.PersonalizationHostApi? api})
    : _api = api ?? pigeon.PersonalizationHostApi();

  /// Starts the shop on the native SDK and answers with its state at once.
  Future<pigeon.SdkSnapshotWire> initialize(SdkInitConfig config) {
    final apiDomain =
        (config.apiDomain == null || config.apiDomain!.trim().isEmpty)
        ? 'api.rees46.ru'
        : config.apiDomain!.trim();

    final stream = (config.stream == null || config.stream!.trim().isEmpty)
        ? defaultStream
        : config.stream!.trim();

    final enableLogs = config.enableLogs ?? false;
    final autoSendPushToken = config.autoSendPushToken ?? true;
    final sendAdvertisingId = config.sendAdvertisingId ?? false;
    final enableAutoPopupPresentation =
        config.enableAutoPopupPresentation ?? true;
    final needReInitialization = config.needReInitialization ?? false;

    return sdkCall(
      () => _api.initialize(
        pigeon.InitConfig(
          shopId: config.shopId,
          apiDomain: apiDomain,
          stream: stream,
          enableLogs: enableLogs,
          autoSendPushToken: autoSendPushToken,
          sendAdvertisingId: sendAdvertisingId,
          enableAutoPopupPresentation: enableAutoPopupPresentation,
          needReInitialization: needReInitialization,
          appDomain: _orNull(config.appDomain),
          deviceId: _orNull(config.deviceId),
          logLevel: config.logLevel?.name,
          storageKey: _orNull(config.storageKey),
        ),
      ),
    );
  }

  static String? _orNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// The traffic stream of a Flutter app that sets none: `flutter`, as the
  /// contract has it for the Flutter SDK.
  static const String defaultStream = 'flutter';
}
