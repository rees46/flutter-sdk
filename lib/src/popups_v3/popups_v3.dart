import 'dart:async';

import 'package:flutter/widgets.dart';

import '../multi_instance/rees46.dart';
import '../personalization_sdk.dart';
import '../popups/popup_presenter.dart';
import '../profile/profile_params.dart';
import '../sdk_init_config.dart';
import '../stories/stories_response.dart';
import '../subscriptions/manage_subscription_params.dart';
import '../ui/components/personalization_product.dart';
import '../ui/popups_v3/popup_v3_host.dart';
import '../ui/widgets/stories_api_v3.dart';
import '../ui/widgets/stories_polls_api.dart';
import 'popups_v3_api.dart';
import 'popups_v3_engine.dart';
import 'popups_v3_frequency.dart';
import 'popups_v3_hooks.dart';

/// Попапы v3 магазина: `sdk.popups`.
extension PersonalizationPopupsV3 on PersonalizationSdk {
  /// Попапы нового конструктора (документ design) этого магазина.
  PopupsV3 get popups => PopupsV3.of(this);
}

/// Попапы нового конструктора: движок (список, триггеры, частота, события) и рендер
/// документа design. Один на магазин.
///
/// Спит, пока хост его не включил: без [enabled] ни одного запроса. Включённый работает,
/// если `/init` вернул флаг `popups_v3` или хост задал [ignoreInitFlag]. Флаг из `/init`
/// во Flutter пока не приходит (плагин собран против опубликованных нативных SDK), поэтому
/// приложение, которое хочет попапы, ставит оба.
///
/// Хост сообщает экраны — [screenOpened] с кодом, который маркетолог пишет в
/// `target_screens` (или [PersonalizationScreenObserver] на навигаторе), — и может
/// показать попап вручную ([show]). С `enableAutoPopupPresentation: false` в init
/// попапы по триггерам пропускаются (с записью в лог), ручной показ работает.
class PopupsV3 with WidgetsBindingObserver implements PopupsV3Listener {
  PopupsV3._(this._shop, PersonalizationSdk sdk) : _sdk = sdk {
    engine = PopupsV3Engine(
      sdk: sdk,
      platform: _SdkPlatform(this),
      presenter: PopupV3Host(),
      storage: PopupsV3PreferencesStorage(_shop.isEmpty ? 'default' : _shop),
      logTag: _shop,
    );
    // Автопоказ выключен в init — триггеры молчат, ручной [show] показывает.
    engine.autoPresentation = () =>
        PopupsV3Hooks.configOf(_sdk.tracking)?.enableAutoPopupPresentation ??
        true;
    PopupsV3Hooks.listen(sdk.tracking, this);
    // Окно одно на экране со старыми попапами: старый ждёт закрытия окна v3, окно v3
    // — закрытия старого.
    PopupPresenter.heldElsewhere = () =>
        PopupsV3Slots.isTaken(PopupsV3Slots.modal);
    PopupPresenter.onIdle = PopupsV3Slots.notify;
  }

  static final Map<String, PopupsV3> _byShop = <String, PopupsV3>{};

  /// Попапы магазина [sdk]. Переинициализированный магазин (новый инстанс с тем же
  /// `shopId`) получает те же попапы с теми же настройками.
  static PopupsV3 of(PersonalizationSdk sdk) {
    final shop = _shopOf(sdk);
    final popups = _byShop[shop];
    if (popups == null) return _byShop[shop] = PopupsV3._(shop, sdk);
    if (!identical(popups._sdk, sdk)) popups._rebind(sdk);
    return popups;
  }

  static String _shopOf(PersonalizationSdk sdk) {
    final own = sdk.shopId;
    if (own != null && own.isNotEmpty) return own;
    final live = REES46.liveShopIds;
    return live.length == 1 ? live.single : '';
  }

  final String _shop;
  PersonalizationSdk _sdk;

  /// Движок попапов магазина.
  late final PopupsV3Engine engine;

  bool _enabled = false;
  bool _ignoreInitFlag = false;
  bool? _initFlag;
  bool _observing = false;

  /// Включить попапы v3. Выключенные не делают ни одного запроса.
  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    _update();
  }

  /// Работать без флага `popups_v3` из `/init` (во Flutter он пока не приходит).
  bool get ignoreInitFlag => _ignoreInitFlag;

  set ignoreInitFlag(bool value) {
    _ignoreInitFlag = value;
    _update();
  }

  /// Флаг `popups_v3` из ответа `/init`; `null` — не приходил.
  bool? get initFlag => _initFlag;

  set initFlag(bool? value) {
    _initFlag = value;
    _update();
  }

  /// Работает ли движок сейчас.
  bool get active => _enabled && (_initFlag == true || _ignoreInitFlag);

  /// Хост ЛК (API попапов, событий и опросов) без схемы; по умолчанию `app.rees46.ru`.
  String get appHost => engine.appHost;

  set appHost(String value) {
    final host = StoriesApiV3.host(value) ?? 'app.rees46.ru';
    if (host == engine.appHost) return;
    engine.appHost = host;
    if (active) unawaited(engine.refresh(force: true));
  }

  /// Тестовый режим: попапы со статусом «Тест», показы не пишутся в частоту.
  bool get testMode => engine.testMode;

  set testMode(bool value) {
    if (value == engine.testMode) return;
    engine.testMode = value;
    if (active) unawaited(engine.refresh(force: true));
  }

  /// `debug=1` в запросе списка и каждое решение движка в лог.
  bool get debug => engine.debug;

  set debug(bool value) => engine.debug = value;

  /// Обработчик ссылок попапов: `true` — ссылку открыл он, иначе — система.
  bool Function(String url)? get onLink => engine.onLink;

  set onLink(bool Function(String url)? handler) => engine.onLink = handler;

  /// Нажатие на товар блока рекомендаций в попапе (после события `click`). `true` —
  /// товар открыл обработчик: попап закрывается без события `close`, как после
  /// перехода. `false`, исключение или нет обработчика — открывается ссылка товара
  /// (`deeplink`, иначе `url`) через [onLink] или систему, попап остаётся.
  bool Function(PersonalizationProduct product)? get onProductClick =>
      engine.onProductClick;

  set onProductClick(bool Function(PersonalizationProduct product)? handler) =>
      engine.onProductClick = handler;

  /// Открыт экран [name] — код экрана, который маркетолог указывает в `target_screens`.
  void screenOpened(String name) => engine.screenOpened(name);

  /// Показать попап [id] вручную: без триггера, экранов и частоты (и без флага из
  /// `/init`, но только включённым). Показывает и при выключенном в init
  /// `enableAutoPopupPresentation` — тот глушит только автоматические показы.
  Future<void> show(int id) {
    if (!_enabled) {
      debugPrint('PersonalizationPopupsV3: show($id) — popups are not enabled');
      return Future<void>.value();
    }
    return engine.show(id);
  }

  void _update() {
    if (active) {
      if (!_observing) {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      }
      engine.apiHost = _apiHost;
      unawaited(engine.start());
    } else if (engine.active) {
      engine.stop();
      if (_observing) {
        WidgetsBinding.instance.removeObserver(this);
        _observing = false;
      }
    }
  }

  void _rebind(PersonalizationSdk sdk) {
    PopupsV3Hooks.listen(_sdk.tracking, null);
    _sdk = sdk;
    engine.sdk = sdk;
    PopupsV3Hooks.listen(sdk.tracking, this);
    engine.apiHost = _apiHost;
  }

  /// API-хост магазина из init (промокоды, сегменты).
  String get _apiHost =>
      StoriesApiV3.host(
        PopupsV3Hooks.configOf(_sdk.tracking)?.apiDomain ?? '',
      ) ??
      'api.rees46.ru';

  @override
  void onInitialized(SdkInitConfig config) {
    engine.apiHost = _apiHost;
    if (active) unawaited(engine.refresh());
  }

  @override
  void onTrackEvent(String event) => engine.onTrackEvent(event);

  @override
  void onContextChanged(String type, String action, Object? data) =>
      engine.onContextChanged(type, action, data);

  @override
  void onPurchase() => engine.onPurchase();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        engine.onForeground();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        engine.onBackground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Тестам: забыть все магазины.
  @visibleForTesting
  static void reset() {
    for (final popups in _byShop.values) {
      popups.engine.stop();
      if (popups._observing) {
        WidgetsBinding.instance.removeObserver(popups);
      }
      PopupsV3Hooks.listen(popups._sdk.tracking, null);
    }
    _byShop.clear();
  }
}

/// Движку — SDK магазина: `did`/`sid` через мост, ссылки, профиль, подписка, опросы.
class _SdkPlatform implements PopupsV3Platform {
  _SdkPlatform(this._popups);

  final PopupsV3 _popups;

  PersonalizationSdk get _sdk => _popups._sdk;

  static const Duration _poll = Duration(milliseconds: 200);
  static const Duration _timeout = Duration(seconds: 15);

  @override
  Future<PopupsV3Identity> identity() async {
    final shop = PopupsV3._shopOf(_sdk);
    if (shop.isEmpty) throw StateError('popups v3: unknown shop_id');
    for (var waited = Duration.zero; ; waited += _poll) {
      String? did;
      var sid = '';
      try {
        did = await _sdk.getDid();
        sid = await _sdk.getSid();
      } catch (_) {
        // Инстанс ещё не готов — спросим снова.
      }
      if (did != null && did.isNotEmpty && sid.isNotEmpty) {
        return (shopId: shop, did: did, sid: sid);
      }
      if (waited >= _timeout) {
        throw TimeoutException('popups v3: no did or sid', _timeout);
      }
      await Future<void>.delayed(_poll);
    }
  }

  @override
  Future<bool> openUrl(String url) => _sdk.openUrl(url);

  @override
  Future<void> manageSubscription(ManageSubscriptionParams params) =>
      _sdk.manageSubscription(params);

  @override
  Future<void> setProfile(ProfileParams params) => _sdk.setProfile(params);

  @override
  Future<void> review(String kind, Map<String, Object> body) async {
    final type = switch (kind) {
      'csat' => StoryPollType.csat,
      'ces' => StoryPollType.ces,
      _ => StoryPollType.nps,
    };
    await StoriesPollsApi(_sdk, _popups.appHost).review(type, body);
  }
}
