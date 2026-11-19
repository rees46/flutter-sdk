import '../core/sdk_logs.dart';
import '../sdk_init_config.dart';

/// Configuration for one SDK instance (one shop), passed to
/// [REES46.initialize] / [REES46.registerShops]: the contract's `Rees46Config`.
class REES46Config {
  const REES46Config({
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

  /// `true` is [logLevel] [LogLevel.debug].
  @Deprecated('Use logLevel: LogLevel.debug.')
  final bool? enableLogs;

  /// Which messages the SDK logs and hands to [REES46.setLogHandler];
  /// [LogLevel.warning] when null.
  final LogLevel? logLevel;
  final bool? autoSendPushToken;

  /// Whether the SDK sends the advertising id (IDFA, GAID); off when null.
  final bool? sendAdvertisingId;

  /// Whether the SDK shows server popups itself while no `onPopup` is set on the
  /// instance. Off — and without `onPopup` — popups are not shown. Defaults to true.
  final bool? enableAutoPopupPresentation;
  final bool? needReInitialization;

  /// The prefix of the shop's storage, for an app that needs a split of its own;
  /// the shop id when null.
  final String? storageKey;

  /// The configuration the handle's `initialize` takes.
  SdkInitConfig toSdkInitConfig() => SdkInitConfig(
    shopId: shopId,
    apiDomain: apiDomain,
    appDomain: appDomain,
    stream: stream,
    deviceId: deviceId,
    // ignore: deprecated_member_use_from_same_package
    enableLogs: enableLogs,
    logLevel: logLevel,
    autoSendPushToken: autoSendPushToken,
    sendAdvertisingId: sendAdvertisingId,
    enableAutoPopupPresentation: enableAutoPopupPresentation,
    needReInitialization: needReInitialization,
    storageKey: storageKey,
  );

  REES46Config copyWith({String? shopId, String? storageKey}) => REES46Config(
    shopId: shopId ?? this.shopId,
    apiDomain: apiDomain,
    appDomain: appDomain,
    stream: stream,
    deviceId: deviceId,
    // ignore: deprecated_member_use_from_same_package
    enableLogs: enableLogs,
    logLevel: logLevel,
    autoSendPushToken: autoSendPushToken,
    sendAdvertisingId: sendAdvertisingId,
    enableAutoPopupPresentation: enableAutoPopupPresentation,
    needReInitialization: needReInitialization,
    storageKey: storageKey ?? this.storageKey,
  );
}
