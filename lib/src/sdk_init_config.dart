class SdkInitConfig {
  final String shopId;
  final String? apiDomain;
  final String? stream;

  /// Enables verbose SDK logging. **iOS only** — ignored on Android (the
  /// published Android SDK artifact does not expose a logging toggle).
  final bool? enableLogs;
  final bool? autoSendPushToken;

  /// Opt-in to IDFA/GAID collection. **iOS only** — ignored on Android (the
  /// published Android SDK artifact always collects the advertising ID
  /// internally via `InitializeAdvertisingIdUseCase`).
  final bool? sendAdvertisingId;
  final bool? enableAutoPopupPresentation;
  final bool? needReInitialization;

  const SdkInitConfig({
    required this.shopId,
    this.apiDomain,
    this.stream,
    this.enableLogs,
    this.autoSendPushToken,
    this.sendAdvertisingId,
    this.enableAutoPopupPresentation,
    this.needReInitialization,
  });
}
