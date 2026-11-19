import 'package:flutter/foundation.dart';

/// How much the SDK writes to its log (`REES46Config.logLevel`): [warning] by
/// default, [debug] for development, [none] for nothing.
enum LogLevel {
  /// Requests (method and path), state changes, the queue's decisions.
  debug,

  /// Initialization finished, the session changed, the push token was sent.
  info,

  /// A retried `/init`, an event the queue dropped, an answer that did not read.
  warning,

  /// The shop refused, a `4xx` to a request of the SDK, an exception caught inside.
  error,

  /// Nothing.
  none;

  /// The level of a native message by its wire name; an unknown one is [debug].
  static LogLevel fromWire(String? value) => LogLevel.values.firstWhere(
    (level) => level.name == value,
    orElse: () => LogLevel.debug,
  );
}

/// One message of the SDK's log, as [REES46.setLogHandler] hands it over. It
/// carries no personal data: no request data or bodies, contacts, push token or
/// push content.
@immutable
class SdkLogMessage {
  const SdkLogMessage({
    required this.level,
    required this.code,
    required this.message,
    this.shopId,
    this.context = const <String, Object?>{},
  });

  final LogLevel level;

  /// A stable code of the event — `init_retry`, `queue_dropped`, `request_failed`,
  /// … — the same on Android and iOS: match on it, not on [message].
  final String code;

  /// A text in English.
  final String message;

  /// The shop the message is about; null for one about the SDK as a whole.
  final String? shopId;

  /// Details: the request's method and path, the HTTP code, the attempt.
  final Map<String, Object?> context;

  @override
  String toString() =>
      'SdkLogMessage(${level.name} $code${shopId == null ? '' : ' [$shopId]'}: $message)';
}

/// The app's log handler and the levels of the shops, for the messages of the
/// native SDKs and of the SDK's own Dart code.
abstract final class SdkLogs {
  static void Function(SdkLogMessage message)? _handler;
  static final Map<String, LogLevel> _levels = <String, LogLevel>{};

  /// Whether a handler is set.
  static bool get hasHandler => _handler != null;

  /// The app's handler; null removes it.
  static set handler(void Function(SdkLogMessage message)? handler) =>
      _handler = handler;

  /// [shopId] logs from [level] up (its `logLevel`).
  static void setLevel(String shopId, LogLevel level) =>
      _levels[shopId] = level;

  /// Hands [message] to the app's handler. A handler that throws is reported to
  /// the system log only (`log_handler_failed`).
  static void deliver(SdkLogMessage message) {
    final handler = _handler;
    if (handler == null) return;
    try {
      handler(message);
    } catch (error) {
      debugPrint('REES46: log_handler_failed: $error');
    }
  }

  /// A message of the SDK's Dart code under the code of its area: it reaches
  /// the handler when it passes the shop's level
  /// (`warning` unless the shop says otherwise).
  static void log(
    LogLevel level,
    String code,
    String message, {
    String? shopId,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    if (_handler == null || level == LogLevel.none) return;
    final threshold =
        (shopId == null ? null : _levels[shopId]) ?? LogLevel.warning;
    if (threshold == LogLevel.none || level.index < threshold.index) return;
    deliver(
      SdkLogMessage(
        level: level,
        code: code,
        message: message,
        shopId: shopId,
        context: context,
      ),
    );
  }

  /// Test-only.
  @visibleForTesting
  static void reset() {
    _handler = null;
    _levels.clear();
  }
}
