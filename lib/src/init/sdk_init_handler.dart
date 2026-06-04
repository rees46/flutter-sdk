import 'package:flutter/foundation.dart';

import '../pigeon/personalization_api.g.dart' as pigeon;
import '../sdk_init_config.dart';

class SdkInitHandler {
  final pigeon.PersonalizationHostApi _api;

  SdkInitHandler({pigeon.PersonalizationHostApi? api})
    : _api = api ?? pigeon.PersonalizationHostApi();

  Future<void> initialize(SdkInitConfig config) {
    final apiDomain =
        (config.apiDomain == null || config.apiDomain!.trim().isEmpty)
        ? 'api.rees46.ru'
        : config.apiDomain!.trim();

    final stream = (config.stream == null || config.stream!.trim().isEmpty)
        ? _defaultStream()
        : config.stream!.trim();

    final enableLogs = config.enableLogs ?? false;
    final autoSendPushToken = config.autoSendPushToken ?? true;
    final sendAdvertisingId = config.sendAdvertisingId ?? false;
    final enableAutoPopupPresentation =
        config.enableAutoPopupPresentation ?? true;
    final needReInitialization = config.needReInitialization ?? false;

    return _api.initialize(
      pigeon.InitConfig(
        shopId: config.shopId,
        apiDomain: apiDomain,
        stream: stream,
        enableLogs: enableLogs,
        autoSendPushToken: autoSendPushToken,
        sendAdvertisingId: sendAdvertisingId,
        enableAutoPopupPresentation: enableAutoPopupPresentation,
        needReInitialization: needReInitialization,
      ),
    );
  }

  static String _defaultStream() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'android';
    }
  }
}
