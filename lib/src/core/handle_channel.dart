import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../errors/sdk_error.dart';

/// The channel one shop's handle calls the native side through: it passes every
/// call on until the handle is released, and fails each later one with
/// `notInitialized` — also once a new instance of the shop runs, which the calls
/// of the released handle would otherwise reach by the shop's id.
class HandleChannel extends BinaryMessenger {
  bool _closed = false;

  /// Whether the handle was released.
  bool get isClosed => _closed;

  /// From now on every call fails with `notInitialized`. A call already handed to
  /// the channel goes on.
  void close() => _closed = true;

  BinaryMessenger get _target =>
      ServicesBinding.instance.defaultBinaryMessenger;

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    if (_closed) {
      return Future<ByteData?>.error(
        SdkException(const SdkErrorNotInitialized()),
      );
    }
    return _target.send(channel, message);
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) =>
      _target.setMessageHandler(channel, handler);

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) =>
      // ignore: deprecated_member_use
      _target.handlePlatformMessage(channel, data, callback);
}

/// Who hears that a handle was released: the facade, which takes it out of its
/// registry. Keyed by the handle, so a handle nobody listens to tells nobody.
abstract final class HandleReleases {
  static final Expando<void Function()> _listeners = Expando<void Function()>(
    'released',
  );

  /// [listener] hears once that [handle] was released.
  static void listen(Object handle, void Function() listener) =>
      _listeners[handle] = listener;

  /// [handle] was released.
  static void released(Object handle) {
    final listener = _listeners[handle];
    _listeners[handle] = null;
    listener?.call();
  }
}
