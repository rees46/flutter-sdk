import 'package:flutter/services.dart';

/// Why a call of the SDK failed — the same set of errors on every platform. Every
/// namespace method (`sdk.products.getInfo` and the rest) fails with an
/// [SdkException] that carries one of these.
///
/// The set is closed: a new kind of error comes only with a major release, so a
/// `switch` over it may be exhaustive.
sealed class SdkError {
  const SdkError();

  /// The error's name on the wire between the native SDK and Dart:
  /// `notInitialized`, `shopBlocked`, `invalidArgument`, `network`, `timeout`,
  /// `http`, `decoding` or `cancelled`.
  String get type;

  /// What failed, for a log: English, without personal data and without the
  /// server's answer.
  String get message;

  /// The error of [type], as the native SDK names it; [SdkErrorDecoding] for a type it
  /// does not know.
  static SdkError fromType(
    String type, {
    String? message,
    int? httpCode,
    String? serverCode,
  }) => switch (type) {
    'notInitialized' => const SdkErrorNotInitialized(),
    'shopBlocked' => const SdkErrorShopBlocked(),
    'invalidArgument' => SdkErrorInvalidArgument(message ?? 'Invalid argument'),
    'network' => const SdkErrorNetwork(),
    'timeout' => const SdkErrorTimeout(),
    'http' => SdkErrorHttp(httpCode ?? 0, serverCode: serverCode),
    'cancelled' => const SdkErrorCancelled(),
    _ => const SdkErrorDecoding(),
  };

  @override
  String toString() => 'SdkError.$type: $message';
}

/// The instance was not created, was released, or runs on a core that has no such
/// method; a shop the plugin does not know is this too.
final class SdkErrorNotInitialized extends SdkError {
  const SdkErrorNotInitialized();

  @override
  String get type => 'notInitialized';

  @override
  String get message => 'The SDK instance is not initialized or was released';

  @override
  bool operator ==(Object other) => other is SdkErrorNotInitialized;

  @override
  int get hashCode => type.hashCode;
}

/// The shop is refused: the server turned the SDK away on `/init`.
final class SdkErrorShopBlocked extends SdkError {
  const SdkErrorShopBlocked();

  @override
  String get type => 'shopBlocked';

  @override
  String get message => 'The shop is blocked';

  @override
  bool operator ==(Object other) => other is SdkErrorShopBlocked;

  @override
  int get hashCode => type.hashCode;
}

/// A parameter of the call is wrong; [message] says which. Nothing was sent.
final class SdkErrorInvalidArgument extends SdkError {
  const SdkErrorInvalidArgument(this.message);

  @override
  final String message;

  @override
  String get type => 'invalidArgument';

  @override
  bool operator ==(Object other) =>
      other is SdkErrorInvalidArgument && other.message == message;

  @override
  int get hashCode => Object.hash(type, message);
}

/// There is no network, or the connection was not established.
final class SdkErrorNetwork extends SdkError {
  const SdkErrorNetwork();

  @override
  String get type => 'network';

  @override
  String get message => 'No connection to the server';

  @override
  bool operator ==(Object other) => other is SdkErrorNetwork;

  @override
  int get hashCode => type.hashCode;
}

/// The answer did not come in time, or broke off in the middle.
final class SdkErrorTimeout extends SdkError {
  const SdkErrorTimeout();

  @override
  String get type => 'timeout';

  @override
  String get message => 'The answer did not come in time';

  @override
  bool operator ==(Object other) => other is SdkErrorTimeout;

  @override
  int get hashCode => type.hashCode;
}

/// The server answered outside `2xx` with [code]. [serverCode] is the
/// machine-readable code of the answer, once the server sends one.
final class SdkErrorHttp extends SdkError {
  const SdkErrorHttp(this.code, {this.serverCode});

  final int code;
  final String? serverCode;

  @override
  String get type => 'http';

  @override
  String get message => 'The server answered $code';

  @override
  bool operator ==(Object other) =>
      other is SdkErrorHttp &&
      other.code == code &&
      other.serverCode == serverCode;

  @override
  int get hashCode => Object.hash(type, code, serverCode);
}

/// A `2xx` answer that does not parse.
final class SdkErrorDecoding extends SdkError {
  const SdkErrorDecoding();

  @override
  String get type => 'decoding';

  @override
  String get message => 'The answer could not be read';

  @override
  bool operator ==(Object other) => other is SdkErrorDecoding;

  @override
  int get hashCode => type.hashCode;
}

/// The request was cancelled: the instance was released.
final class SdkErrorCancelled extends SdkError {
  const SdkErrorCancelled();

  @override
  String get type => 'cancelled';

  @override
  String get message => 'The request was cancelled';

  @override
  bool operator ==(Object other) => other is SdkErrorCancelled;

  @override
  int get hashCode => type.hashCode;
}

/// A failed call of the SDK: [error] says why.
///
/// It is a [PlatformException] too — [code] is [SdkError.type] and [details] holds
/// `httpCode` and `serverCode` — so code written against earlier releases, which
/// caught a [PlatformException], keeps catching it.
class SdkException extends PlatformException {
  SdkException(this.error, {String? message})
    : super(
        code: error.type,
        message: message ?? error.message,
        details: <String, Object?>{
          'httpCode': error is SdkErrorHttp ? error.code : null,
          'serverCode': error is SdkErrorHttp ? error.serverCode : null,
        },
      );

  /// The failure as the native channel reports it: [PlatformException.code] is the
  /// error's type, [PlatformException.details] its `httpCode` and `serverCode`. A
  /// call that reached no native code (`channel-error`) is [SdkErrorNotInitialized].
  factory SdkException.fromPlatform(PlatformException exception) {
    if (exception is SdkException) return exception;
    final details = exception.details;
    int? httpCode;
    String? serverCode;
    if (details is Map) {
      final code = details['httpCode'];
      httpCode = code is int ? code : (code is num ? code.toInt() : null);
      final server = details['serverCode'];
      serverCode = server is String ? server : null;
    }
    final error = exception.code == 'channel-error'
        ? const SdkErrorNotInitialized()
        : SdkError.fromType(
            exception.code,
            message: exception.message,
            httpCode: httpCode,
            serverCode: serverCode,
          );
    return SdkException(error, message: exception.message ?? error.message);
  }

  /// Why the call failed.
  final SdkError error;

  /// [SdkError.type]: `notInitialized`, `shopBlocked`, `invalidArgument`,
  /// `network`, `timeout`, `http`, `decoding` or `cancelled`.
  String get type => error.type;

  /// The HTTP status of an [SdkErrorHttp] error; null otherwise.
  int? get httpCode => switch (error) {
    SdkErrorHttp(:final code) => code,
    _ => null,
  };

  /// The server's machine-readable code of an [SdkErrorHttp] error, once it sends one.
  String? get serverCode => switch (error) {
    SdkErrorHttp(:final serverCode) => serverCode,
    _ => null,
  };

  @override
  String toString() => 'SdkException(${error.type}): $message';
}

/// Runs a call of the native channel, turning its failure into an [SdkException].
Future<T> sdkCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on PlatformException catch (e) {
    throw SdkException.fromPlatform(e);
  }
}
