import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../pigeon/personalization_api.g.dart' as pigeon;
import 'in_app_popup.dart';
import 'popup_presenter.dart';

/// Process-global sink for the popups the native SDKs hand over.
///
/// There is one Pigeon `PersonalizationPopupFlutterApi` channel per plugin, so one
/// dispatcher owns it and routes each popup by the shop it came for to that handle's
/// [PopupPresenter]. A handle registers when it initializes, under the shop id it
/// initialized the native SDK with — the id the native side reports back.
class PopupDispatcher implements pigeon.PersonalizationPopupFlutterApi {
  PopupDispatcher._() {
    pigeon.PersonalizationPopupFlutterApi.setUp(this);
  }

  static final PopupDispatcher instance = PopupDispatcher._();

  final Map<String, PopupPresenter> _byShop = <String, PopupPresenter>{};

  /// Registers [presenter] as the sink for [shopId]'s popups.
  void register(String shopId, PopupPresenter presenter) {
    _byShop[shopId] = presenter;
  }

  @override
  void onPopup(String shopId, String popupJson) {
    final presenter = _byShop[shopId];
    if (presenter == null) return; // a shop no handle initialized
    final Object? decoded;
    try {
      decoded = jsonDecode(popupJson);
    } on FormatException catch (error) {
      debugPrint('PersonalizationPopup: unreadable popup — $error');
      return;
    }
    if (decoded is! Map) return;
    presenter.receive(InAppPopup.fromJson(decoded.cast<String, Object?>()));
  }

  /// Test-only: drops all registrations.
  @visibleForTesting
  void reset() => _byShop.clear();
}
