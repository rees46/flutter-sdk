import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Where the shop placed a popup in the admin.
enum InAppPopupPosition {
  center,
  top,
  bottom,

  /// No position, or one this SDK does not know. Shown fullscreen, as the native SDKs do.
  unknown,
}

/// A server popup (in-app message). Popups arrive with the responses to init and tracking
/// calls; see `PersonalizationSdk.onPopup` for how they reach the screen.
@immutable
class InAppPopup {
  const InAppPopup({
    required this.id,
    this.position = InAppPopupPosition.unknown,
    this.delay = Duration.zero,
    this.title,
    this.text,
    this.imageUrl,
    this.linkText,
    this.linkUrl,
    this.pushSubscribeText,
    this.closeText,
    this.json = const <String, Object?>{},
  });

  /// Parses the popup as the server sends it. [platform] picks the link for this platform
  /// (`link_android` / `link_ios`), falling back to the web one.
  factory InAppPopup.fromJson(
    Map<String, Object?> json, {
    TargetPlatform? platform,
  }) {
    final components = _map(json['components']);
    final actions = _map(json['popup_actions']);
    final link = _map(actions['link']);
    final ios = (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
    final own = _text(link[ios ? 'link_ios' : 'link_android']);
    final other = _text(link[ios ? 'link_android' : 'link_ios']);

    return InAppPopup(
      id: _int(json['id']) ?? 0,
      position: switch (json['position']) {
        'centered' => InAppPopupPosition.center,
        'top' => InAppPopupPosition.top,
        'fixed_bottom' => InAppPopupPosition.bottom,
        _ => InAppPopupPosition.unknown,
      },
      delay: Duration(seconds: _int(json['delay']) ?? 0),
      title: _text(components['header']),
      text: _text(components['text']),
      imageUrl: _text(components['image']),
      linkText: _text(link['button_text']),
      linkUrl: own ?? _text(link['link_web']) ?? other,
      pushSubscribeText: _text(
        _map(actions['system_mobile_push_subscribe'])['button_text'],
      ),
      closeText: _text(_map(actions['close'])['button_text']),
      json: json,
    );
  }

  final int id;
  final InAppPopupPosition position;

  /// How long after it arrives the shop wants the popup shown.
  final Duration delay;

  final String? title;
  final String? text;
  final String? imageUrl;

  /// The link button: [linkText] opens [linkUrl].
  final String? linkText;
  final String? linkUrl;

  /// The push-subscription button. When the shop turned it on it takes the place of the
  /// link button, as in the native SDKs: tapping it opens the notification settings.
  final String? pushSubscribeText;

  /// The secondary button that closes the popup. Empty — only the cross closes it.
  final String? closeText;

  /// The popup as the server sent it, for fields this class does not cover.
  final Map<String, Object?> json;

  /// The main button's caption: the push subscription, else the link.
  String? get actionText => pushSubscribeText ?? linkText;

  /// Whether there is anything to show: a title, a text or a picture.
  bool get hasContent => title != null || text != null || imageUrl != null;

  // The server sends `components` and `popup_actions` as JSON inside a string; the
  // plugin hands them over as objects, but either reads.
  static Map<String, Object?> _map(Object? value) {
    if (value is String && value.isNotEmpty) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return const <String, Object?>{};
      }
    }
    return value is Map
        ? value.cast<String, Object?>()
        : const <String, Object?>{};
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  static int? _int(Object? value) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v),
    _ => null,
  };
}
