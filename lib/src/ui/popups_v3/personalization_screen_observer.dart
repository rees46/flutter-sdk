import 'package:flutter/widgets.dart';

import '../../multi_instance/rees46.dart';
import '../../personalization_sdk.dart';
import '../../popups_v3/popups_v3.dart';

/// Сообщает попапам v3 об открытых экранах навигатора: страница пришла (`push`),
/// вернулись на неё (`pop` верхней), заменили — `sdk.popups.screenOpened(код)`.
///
/// Код экрана — то, что маркетолог пишет в `target_screens`: по умолчанию имя маршрута
/// (`RouteSettings.name`), иначе — что вернёт [screenName] (`null` — не сообщать).
/// Диалоги и всплывающие маршруты экраном не считаются.
///
/// ```dart
/// MaterialApp(navigatorObservers: [PersonalizationScreenObserver(shopId: 'SHOP_ID')]);
/// ```
class PersonalizationScreenObserver extends NavigatorObserver {
  PersonalizationScreenObserver({this.sdk, this.shopId, this.screenName});

  /// Инстанс SDK; без него — [shopId] или единственный (`REES46.getInstance`).
  final PersonalizationSdk? sdk;
  final String? shopId;

  /// Код экрана маршрута.
  final String? Function(Route<dynamic> route)? screenName;

  /// Последний сообщённый экран.
  String? get current => _current;
  String? _current;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute != null) _report(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _report(newRoute);
  }

  void _report(Route<dynamic> route) {
    if (route is! PageRoute) return;
    final name = screenName?.call(route) ?? route.settings.name;
    if (name == null || name.trim().isEmpty) return;
    _current = name;
    reportScreen(name);
  }

  /// Сообщить экран [name] — например, при переключении вкладки на этот навигатор.
  void reportScreen(String name) {
    try {
      (sdk ?? REES46.getInstance(shopId)).popups.screenOpened(name);
    } catch (error) {
      debugPrint('PersonalizationScreenObserver: screen $name — $error');
    }
  }
}
