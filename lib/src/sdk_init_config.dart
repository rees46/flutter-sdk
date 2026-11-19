import 'core/sdk_logs.dart';

/// The configuration of a shop's start, as `PersonalizationSdk.initialize` takes
/// it; [REES46Config] builds it.
class SdkInitConfig {
  final String shopId;

  /// The API's host; `api.rees46.ru` when null.
  final String? apiDomain;

  /// The host of the shop's app API — polls, the search agent, predict; `app.rees46.ru` when
  /// null. A shop of its own cluster has its own.
  final String? appDomain;

  /// The source of the events in the reports; `flutter` when null.
  final String? stream;

  /// A `did` the app kept from another version of the SDK: taken only while the
  /// shop has no device id of its own.
  final String? deviceId;

  /// `true` is [logLevel] [LogLevel.debug]. Replaced by [logLevel], which wins when
  /// both are set.
  final bool? enableLogs;

  /// Which messages the SDK logs and hands to `REES46.setLogHandler`;
  /// [LogLevel.warning] when null.
  final LogLevel? logLevel;
  final bool? autoSendPushToken;

  /// Whether the SDK sends the advertising id (IDFA, GAID); off when null.
  final bool? sendAdvertisingId;
  final bool? enableAutoPopupPresentation;
  final bool? needReInitialization;

  /// The prefix of the shop's storage, for an app that needs a split of its own;
  /// the shop id when null.
  final String? storageKey;

  const SdkInitConfig({
    required this.shopId,
    this.apiDomain,
    this.appDomain,
    this.stream,
    this.deviceId,
    this.enableLogs,
    this.logLevel,
    this.autoSendPushToken,
    this.sendAdvertisingId,
    this.enableAutoPopupPresentation,
    this.needReInitialization,
    this.storageKey,
  });

  /// The level the shop logs from: [logLevel], else [enableLogs] as
  /// [LogLevel.debug], else [LogLevel.warning].
  LogLevel get effectiveLogLevel =>
      logLevel ?? (enableLogs == true ? LogLevel.debug : LogLevel.warning);
}
