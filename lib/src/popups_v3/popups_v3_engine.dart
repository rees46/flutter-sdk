import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../personalization_sdk.dart';
import '../popups/popup_presenter.dart';
import '../profile/profile_params.dart';
import '../subscriptions/manage_subscription_params.dart';
import '../ui/components/personalization_product.dart';
import 'popup_v3.dart';
import 'popups_v3_api.dart';
import 'popups_v3_frequency.dart';

/// Часы и таймеры движка — тесты подменяют.
abstract interface class PopupsV3Clock {
  DateTime now();

  Timer timer(Duration delay, void Function() callback);
}

class _SystemClock implements PopupsV3Clock {
  const _SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Timer timer(Duration delay, void Function() callback) =>
      Timer(delay, callback);
}

/// Что движку нужно от SDK: идентичность запросов, ссылки, профиль, подписка, отзыв.
abstract interface class PopupsV3Platform {
  /// `shop_id`, `did` и `sid`; SDK ещё не готов — ждёт, не дождался — ошибка.
  Future<PopupsV3Identity> identity();

  Future<bool> openUrl(String url);

  Future<void> manageSubscription(ManageSubscriptionParams params);

  Future<void> setProfile(ProfileParams params);

  /// Оценка шкалы [kind] (`nps`, `csat`, `ces`) с телом [body] на API v3 опросов.
  Future<void> review(String kind, Map<String, Object> body);
}

/// Показанный на экране попап.
abstract interface class PopupsV3Shown {
  /// Завершается, когда попап ушёл с экрана — по любой причине.
  Future<void> get closed;

  /// Убрать попап без события `close`.
  void dismiss();
}

/// Рендер попапов: рисует [popup] и отдаёт действия его элементов в [actions].
abstract interface class PopupsV3Presenter {
  /// Показать попап с витринными переменными [variables] (`promo_code`). `null` —
  /// показать не удалось (нет навигатора).
  Future<PopupsV3Shown?> present(
    PopupV3 popup,
    Map<String, String> variables,
    PopupV3Actions actions,
  );
}

/// Данные формы профиля попапа.
class PopupV3ProfileSubmission {
  const PopupV3ProfileSubmission({
    this.email,
    this.phone,
    this.firstName,
    this.lastName,
    this.birthday,
    this.gender,
    this.custom = const <String, String>{},
    this.consentFields = const <String>[],
    this.segmentId,
  });

  final String? email;
  final String? phone;
  final String? firstName;
  final String? lastName;

  /// `YYYY-MM-DD`.
  final String? birthday;

  /// `m` или `f`.
  final String? gender;

  /// Свои свойства клиента: ключ → значение.
  final Map<String, String> custom;

  /// Флаги подписки, если согласие отмечено (`email_bulk` …).
  final List<String> consentFields;
  final String? segmentId;
}

/// Действия элементов показанного попапа: события, ссылки, формы, опрос.
abstract interface class PopupV3Actions {
  /// Инстанс SDK попапа — для блока рекомендаций.
  PersonalizationSdk get sdk;

  /// Событие попапа ([PopupV3Event.close] шлёт рендер при любом закрытии).
  void event(PopupV3Event event, {String? channel});

  /// Открыть ссылку: сначала обработчик хоста, потом система. Пустая ссылка,
  /// `javascript:` и `data:` не открываются.
  Future<void> openLink(String url);

  /// Нажатие на товар блока рекомендаций: сначала обработчику хоста, не открыл он —
  /// ссылка товара. `true` — товар открыл хост, попап закрывается без события `close`.
  bool openProduct(PersonalizationProduct product);

  /// Подписка на email с флагами [consentFields] и сегментом; ошибка — исключение.
  Future<void> subscribeEmail({
    required String email,
    required List<String> consentFields,
    String? segmentId,
  });

  /// Форма профиля; ошибка — исключение.
  Future<void> submitProfile(PopupV3ProfileSubmission submission);

  /// Оценка опроса [kind] (`nps`, `csat`, `ces`) в кампанию [code]; ошибка — исключение.
  Future<void> review({
    required String kind,
    required String code,
    required int rate,
    String? comment,
  });
}

/// Слоты экрана, общие на процесс: окно одно (вместе со старыми попапами), баннер —
/// по одному сверху и снизу.
abstract final class PopupsV3Slots {
  static const String modal = 'modal';

  static final Map<String, Object> _taken = <String, Object>{};
  static final Set<void Function()> _listeners = <void Function()>{};

  /// Занят ли экран старым попапом.
  static bool Function() legacyModal = () => PopupPresenter.isPresenting;

  static String of(PopupV3 popup) =>
      popup.isModal ? modal : 'banner_${popup.placement.name}';

  static bool isFree(String slot) =>
      !_taken.containsKey(slot) && !(slot == modal && legacyModal());

  static bool isTaken(String slot) => _taken.containsKey(slot);

  static void take(String slot, Object owner) => _taken[slot] = owner;

  static void release(String slot, Object owner) {
    if (!identical(_taken[slot], owner)) return;
    _taken.remove(slot);
    if (slot == modal) PopupPresenter.resume();
    notify();
  }

  /// Слот освободился: движки показывают свои очереди.
  static void notify() {
    for (final listener in _listeners.toList()) {
      listener();
    }
  }

  static void listen(void Function() listener) => _listeners.add(listener);

  static void unlisten(void Function() listener) => _listeners.remove(listener);

  @visibleForTesting
  static void reset() {
    _taken.clear();
    _listeners.clear();
    legacyModal = () => PopupPresenter.isPresenting;
  }
}

typedef _ListCache = ({
  String sid,
  bool testMode,
  DateTime expires,
  PopupsV3List list,
});

typedef _Open = ({PopupV3 popup, PopupsV3Shown shown, String slot});

/// Движок попапов v3 одного инстанса SDK: загрузка и кеш списка, экраны и триггеры,
/// частота, очередь на слот, промокод до показа, события.
class PopupsV3Engine {
  PopupsV3Engine({
    required this.sdk,
    required this.platform,
    required this.presenter,
    PopupsV3Api? api,
    PopupsV3Storage? storage,
    PopupsV3Clock? clock,
    this.logTag = '',
  }) : api = api ?? PopupsV3Api(),
       clock = clock ?? const _SystemClock(),
       frequency = PopupsV3FrequencyRules(storage ?? PopupsV3MemoryStorage());

  /// Инстанс SDK магазина; переинициализация магазина подставляет новый.
  PersonalizationSdk sdk;
  final PopupsV3Platform platform;
  final PopupsV3Presenter presenter;
  final PopupsV3Api api;
  final PopupsV3Clock clock;
  final PopupsV3FrequencyRules frequency;

  /// Метка в логе (магазин).
  final String logTag;

  /// Хост ЛК без схемы.
  String appHost = 'app.rees46.ru';

  /// API-хост магазина без схемы — промокоды и сегменты.
  String apiHost = 'api.rees46.ru';

  /// Тестовый режим: попапы со статусом «Тест», частота не пишется.
  bool testMode = false;

  /// `debug=1` в списке и каждое решение движка в лог.
  bool debug = false;

  /// Обработчик ссылок хоста: `true` — ссылку открыл он.
  bool Function(String url)? onLink;

  /// Нажатие на товар рекомендаций в попапе: `true` — товар открыл хост, иначе
  /// открывается ссылка товара.
  bool Function(PersonalizationProduct product)? onProductClick;

  /// Показывать ли попапы самим (`enableAutoPopupPresentation` из init); ручной показ
  /// — всегда.
  bool Function() autoPresentation = _autoPresentation;

  static bool _autoPresentation() => true;

  /// Сброс кеша после смены контекста — с такой задержкой.
  static const Duration invalidateDelay = Duration(seconds: 2);

  /// Сколько событий `track_event` держать, пока список не пришёл, и как долго.
  static const int bufferLimit = 20;
  static const Duration bufferWindow = Duration(seconds: 10);

  bool _active = false;
  String? _sid;
  _ListCache? _cache;
  Map<int, PopupV3> _popups = <int, PopupV3>{};
  bool _armed = false;
  Future<void> _loading = Future<void>.value();

  String? _screen;
  int _screenSeq = 0;
  DateTime? _screenAt;
  final Set<int> _screenEvaluated = <int>{};
  final Map<int, Timer> _screenTimers = <int, Timer>{};
  bool _foreground = true;

  final List<({String event, DateTime at})> _buffer =
      <({String event, DateTime at})>[];
  final Set<int> _showing = <int>{};
  final Map<int, _Open> _open = <int, _Open>{};
  final List<({PopupV3 popup, bool manual})> _queue =
      <({PopupV3 popup, bool manual})>[];
  final Map<String, String> _signatures = <String, String>{};
  Timer? _invalidateTimer;

  /// Работает ли движок (хост включил, флаг или принудительное включение).
  bool get active => _active;

  /// Текущий экран.
  String? get screen => _screen;

  /// Попапы текущего списка.
  List<PopupV3> get popups => _popups.values.toList();

  /// Показанные сейчас попапы.
  List<int> get openIds => _open.keys.toList();

  /// Ждут слота.
  List<int> get queuedIds => <int>[for (final item in _queue) item.popup.id];

  /// Запустить: загрузить список и поставить триггеры. Повторный вызов — обновить.
  Future<void> start() {
    if (!_active) {
      _active = true;
      PopupsV3Slots.listen(_processQueue);
    }
    return refresh();
  }

  /// Остановить: таймеры сняты, список забыт; показанные попапы остаются.
  void stop() {
    if (!_active) return;
    _active = false;
    PopupsV3Slots.unlisten(_processQueue);
    _cancelScreenTimers();
    _invalidateTimer?.cancel();
    _invalidateTimer = null;
    _popups = <int, PopupV3>{};
    _armed = false;
    _queue.clear();
  }

  /// Обновить список: кеш годен — из кеша, иначе запрос. Новая сессия — заново
  /// триггеры запуска. Запросы идут по одному.
  Future<void> refresh({bool force = false}) {
    final next = _loading.then((_) => _refresh(force));
    _loading = next.catchError((Object error) {
      _log('list not loaded — $error', always: true);
    });
    return _loading;
  }

  Future<void> _refresh(bool force) async {
    if (!_active) return;
    final id = await platform.identity();
    if (!_active) return;
    if (_sid != id.sid) {
      if (_sid != null) _log('new session ${id.sid}');
      _sid = id.sid;
      _signatures.clear();
      // Новая сессия — и новая «страница» для частоты `every_page`.
      frequency.newPage();
    }
    final cache = _cache;
    if (!force &&
        cache != null &&
        cache.sid == id.sid &&
        cache.testMode == testMode &&
        clock.now().isBefore(cache.expires)) {
      _setList(cache.list);
      return;
    }
    final result = await api.list(
      appHost,
      id,
      testMode: testMode,
      debug: debug,
    );
    if (!_active) return;
    switch (result.outcome) {
      case PopupsV3ListOutcome.success:
        _cache = (
          sid: id.sid,
          testMode: testMode,
          expires: clock.now().add(result.list.ttl),
          list: result.list,
        );
      case PopupsV3ListOutcome.clientError:
        _log('list request failed: ${result.error}', always: true);
        _cache = (
          sid: id.sid,
          testMode: testMode,
          expires: clock.now().add(PopupsV3List.defaultTtl),
          list: PopupsV3List.empty,
        );
      case PopupsV3ListOutcome.failure:
        _log('list request failed: ${result.error}', always: true);
        return;
    }
    _setList(result.list);
  }

  void _setList(PopupsV3List list) {
    for (final excluded in list.excluded) {
      _log('popup ${excluded.id} excluded by the server: ${excluded.reason}');
    }
    list.skipped.forEach((id, reason) => _log('popup $id skipped: $reason'));

    final next = <int, PopupV3>{
      for (final popup in list.popups) popup.id: popup,
    };
    for (final id in _popups.keys) {
      if (next.containsKey(id)) continue;
      _screenTimers.remove(id)?.cancel();
      _queue.removeWhere((item) => item.popup.id == id && !item.manual);
    }
    _popups = next;
    _armed = true;
    _log('${next.length} popup(s) loaded');

    // Запуск проверяется на каждой загрузке списка и на каждом открытом экране:
    // повтор отсекает частота (`every_page` — раз на экран).
    for (final popup in next.values) {
      if (popup.trigger != PopupV3Trigger.appStart) continue;
      _screenEvaluated.add(popup.id);
      if (popup.matchesScreen(_screen)) {
        _fire(popup);
      } else {
        _log('popup ${popup.id} waits for screen ${popup.targetScreens}');
      }
    }
    if (_screen != null) {
      for (final popup in next.values) {
        if (!_screenEvaluated.contains(popup.id)) _evaluateScreen(popup);
      }
    }
    final since = clock.now().subtract(bufferWindow);
    final buffered = _buffer.where((item) => !item.at.isBefore(since)).toList();
    _buffer.clear();
    for (final item in buffered) {
      onTrackEvent(item.event);
    }
  }

  /// Открыт экран [name] — код, который маркетолог пишет в `target_screens`.
  void screenOpened(String name) {
    final screen = name.trim();
    if (screen.isEmpty) return;
    _log('screen $screen');
    _screen = screen;
    _screenSeq++;
    _screenAt = clock.now();
    _screenEvaluated.clear();
    _cancelScreenTimers();
    frequency.newPage();
    if (!_active || !_armed) return;
    for (final popup in _popups.values) {
      _evaluateScreen(popup);
    }
  }

  void _evaluateScreen(PopupV3 popup) {
    _screenEvaluated.add(popup.id);
    if (!popup.matchesScreen(_screen)) return;
    switch (popup.trigger) {
      case PopupV3Trigger.appStart:
      case PopupV3Trigger.screenOpen:
        _fire(popup);
      case PopupV3Trigger.timeOnScreen:
        _startTimer(popup);
      case PopupV3Trigger.trackEvent:
      case PopupV3Trigger.manual:
        break;
    }
  }

  void _startTimer(PopupV3 popup) {
    if (!_foreground) return;
    final since = clock.now().difference(_screenAt ?? clock.now());
    final left = popup.triggerDelay - since;
    final seq = _screenSeq;
    _screenTimers.remove(popup.id)?.cancel();
    _screenTimers[popup.id] = clock.timer(
      left.isNegative ? Duration.zero : left,
      () {
        _screenTimers.remove(popup.id);
        if (_active && _foreground && seq == _screenSeq) _fire(popup);
      },
    );
  }

  void _cancelScreenTimers() {
    for (final timer in _screenTimers.values) {
      timer.cancel();
    }
    _screenTimers.clear();
  }

  /// Приложение ушло в фон: таймеры «время на экране» сброшены.
  void onBackground() {
    _foreground = false;
    _cancelScreenTimers();
  }

  /// Приложение вернулось: таймеры «время на экране» заново, список — если сменилась
  /// сессия или истёк кеш.
  void onForeground() {
    if (_foreground) return;
    _foreground = true;
    _screenAt = clock.now();
    if (_active && _armed) {
      for (final popup in _popups.values) {
        if (popup.trigger == PopupV3Trigger.timeOnScreen &&
            popup.matchesScreen(_screen)) {
          _startTimer(popup);
        }
      }
    }
    if (_active) unawaited(refresh());
  }

  /// Своё событие SDK [event] — триггер `track_event`. Экран должен подходить: событие
  /// не ждёт экрана. Пока список не пришёл, последние события копятся.
  void onTrackEvent(String event) {
    if (!_active) return;
    if (!_armed) {
      _buffer.add((event: event, at: clock.now()));
      if (_buffer.length > bufferLimit) {
        _buffer.removeRange(0, _buffer.length - bufferLimit);
      }
      return;
    }
    for (final popup in _popups.values) {
      if (popup.trigger != PopupV3Trigger.trackEvent ||
          popup.triggerEvent != event) {
        continue;
      }
      if (popup.matchesScreen(_screen)) {
        _fire(popup);
      } else {
        _log(
          'popup ${popup.id} skipped: screen $_screen is not in ${popup.targetScreens}',
        );
      }
    }
  }

  /// Смена контекста клиента: кеш сбрасывается и список запрашивается заново через
  /// [invalidateDelay]. Те же данные повторно в той же сессии кеш не сбрасывают.
  void onContextChanged(String type, String action, Object? data) {
    if (!_active) return;
    String signature;
    try {
      signature = jsonEncode(<Object?>[action, data]);
    } catch (_) {
      signature = '${math.Random().nextDouble()}';
    }
    if (_signatures[type] == signature) return;
    _signatures[type] = signature;
    _invalidate();
  }

  /// Покупка: список заново через [invalidateDelay].
  void onPurchase() {
    if (_active) _invalidate();
  }

  void _invalidate() {
    _invalidateTimer?.cancel();
    _invalidateTimer = clock.timer(invalidateDelay, () {
      _invalidateTimer = null;
      _log('list invalidated');
      _cache = null;
      unawaited(refresh(force: true));
    });
  }

  /// Показать попап [id] вручную: без триггера, экранов и частоты; слот и промокод —
  /// как обычно.
  Future<void> show(int id) async {
    final PopupsV3Identity identity;
    try {
      identity = await platform.identity();
    } catch (error) {
      _log('popup $id not loaded — $error', always: true);
      return;
    }
    final popup = await api.one(
      appHost,
      id,
      identity,
      testMode: testMode,
      onError: (error) => _log('popup $id not loaded — $error', always: true),
    );
    if (popup != null) await _show(popup, manual: true);
  }

  void _fire(PopupV3 popup) {
    _log('popup ${popup.id} triggered (${popup.trigger.wire})');
    unawaited(_show(popup, manual: false));
  }

  Future<void> _show(PopupV3 popup, {required bool manual}) async {
    final id = popup.id;
    if (_showing.contains(id) || _open.containsKey(id)) return;
    _showing.add(id);
    try {
      if (!manual) {
        final reason = await frequency.check(
          popup,
          now: clock.now(),
          sid: _sid,
        );
        if (reason != null) {
          _log('popup $id skipped: $reason');
          return;
        }
        if (!autoPresentation()) {
          _log(
            'popup $id skipped: automatic popup presentation is off',
            always: true,
          );
          return;
        }
      }
      final slot = PopupsV3Slots.of(popup);
      if (!PopupsV3Slots.isFree(slot)) {
        _postpone(popup, manual, slot);
        return;
      }
      final variables = <String, String>{};
      if (popup.needsPromoCode) {
        final code = await _promoCode(popup);
        if (code == null) {
          _log('popup $id skipped: no promo code', always: true);
          return;
        }
        variables['promo_code'] = code;
      }
      // Пока ждали промокод, слот мог занять другой попап.
      if (!PopupsV3Slots.isFree(slot)) {
        _postpone(popup, manual, slot);
        return;
      }
      PopupsV3Slots.take(slot, this);
      final PopupsV3Shown? shown;
      try {
        shown = await presenter.present(
          popup,
          variables,
          _EngineActions(this, popup),
        );
      } catch (error) {
        PopupsV3Slots.release(slot, this);
        rethrow;
      }
      if (shown == null) {
        PopupsV3Slots.release(slot, this);
        _log('popup $id not shown: nothing to show it on', always: true);
        return;
      }
      _open[id] = (popup: popup, shown: shown, slot: slot);
      if (!manual) {
        await frequency.record(
          popup,
          now: clock.now(),
          sid: _sid,
          testMode: testMode,
        );
      }
      _log('popup $id shown');
      sendEvent(popup, PopupV3Event.show);
      unawaited(
        shown.closed.whenComplete(() {
          _open.remove(id);
          PopupsV3Slots.release(slot, this);
        }),
      );
    } catch (error, stack) {
      _log('popup $id failed — $error\n$stack', always: true);
    } finally {
      _showing.remove(id);
    }
  }

  void _postpone(PopupV3 popup, bool manual, String slot) {
    _log('popup ${popup.id} postponed: $slot is busy');
    if (_queue.any((item) => item.popup.id == popup.id)) return;
    _queue.add((popup: popup, manual: manual));
  }

  void _processQueue() {
    if (_queue.isEmpty) return;
    final queued = _queue.toList();
    _queue.clear();
    for (final item in queued) {
      final current = item.manual ? item.popup : _popups[item.popup.id];
      if (current != null) unawaited(_show(current, manual: item.manual));
    }
  }

  Future<String?> _promoCode(PopupV3 popup) async {
    try {
      final identity = await platform.identity();
      return await api.promoCode(apiHost, identity, popup.promoCodeListId!);
    } catch (error) {
      _log('promo code of popup ${popup.id} — $error', always: true);
      return null;
    }
  }

  /// Событие [event] попапа [popup] — «выстрелил и забыл».
  void sendEvent(PopupV3 popup, PopupV3Event event, {String? channel}) {
    unawaited(() async {
      try {
        final identity = await platform.identity();
        final status = await api.event(
          appHost,
          popup.id,
          identity,
          event,
          channel: channel,
        );
        _log(
          'event ${event.wire}${channel == null ? '' : ' ($channel)'} of popup '
          '${popup.id}: ${status == null ? 'not sent' : 'HTTP $status'}',
        );
      } catch (error) {
        _log('event ${event.wire} of popup ${popup.id} — $error', always: true);
      }
    }());
  }

  /// Закрыть все показанные попапы этого движка без событий.
  void dismissAll() {
    for (final open in _open.values.toList()) {
      open.shown.dismiss();
    }
  }

  void _log(String message, {bool always = false}) {
    if (!always && !debug) return;
    debugPrint(
      'PersonalizationPopupsV3${logTag.isEmpty ? '' : ' [$logTag]'}: $message',
    );
  }

  /// Запись в лог от действий попапа.
  void log(String message, {bool always = false}) =>
      _log(message, always: always);
}

final RegExp _unsafeScheme = RegExp(
  r'^\s*(javascript|data|vbscript):',
  caseSensitive: false,
);

/// Ссылка, которую можно открыть: не пустая и не `javascript:`/`data:`.
String? popupV3SafeLink(String? url) {
  final link = url?.trim() ?? '';
  if (link.isEmpty || _unsafeScheme.hasMatch(link)) return null;
  return link;
}

class _EngineActions implements PopupV3Actions {
  _EngineActions(this.engine, this.popup);

  final PopupsV3Engine engine;
  final PopupV3 popup;

  @override
  PersonalizationSdk get sdk => engine.sdk;

  @override
  void event(PopupV3Event event, {String? channel}) =>
      engine.sendEvent(popup, event, channel: channel);

  @override
  Future<void> openLink(String url) async {
    final link = popupV3SafeLink(url);
    if (link == null) return;
    try {
      if (engine.onLink?.call(link) ?? false) return;
      final opened = await engine.platform.openUrl(link);
      if (!opened) engine.log('nothing opens $link', always: true);
    } catch (error) {
      engine.log('link $link — $error', always: true);
    }
  }

  @override
  bool openProduct(PersonalizationProduct product) {
    final handler = engine.onProductClick;
    if (handler != null) {
      try {
        if (handler(product)) return true;
      } catch (error) {
        engine.log('product ${product.id} — $error', always: true);
      }
    }
    final deeplink = product.deeplink?.trim() ?? '';
    final link = deeplink.isNotEmpty ? deeplink : product.url;
    if (link != null) unawaited(openLink(link));
    return false;
  }

  @override
  Future<void> subscribeEmail({
    required String email,
    required List<String> consentFields,
    String? segmentId,
  }) async {
    await engine.platform.manageSubscription(
      _consent(consentFields, email: email),
    );
    await _segment(segmentId);
    event(PopupV3Event.subscribe, channel: 'email');
    event(PopupV3Event.submit);
  }

  @override
  Future<void> submitProfile(PopupV3ProfileSubmission submission) async {
    await engine.platform.setProfile(
      ProfileParams(
        email: submission.email,
        phone: submission.phone,
        firstName: submission.firstName,
        lastName: submission.lastName,
        birthday: submission.birthday,
        gender: switch (submission.gender) {
          'm' => ProfileGender.male,
          'f' => ProfileGender.female,
          _ => null,
        },
        customProperties: submission.custom.isEmpty ? null : submission.custom,
      ),
    );
    if (submission.consentFields.isNotEmpty) {
      if (submission.email != null || submission.phone != null) {
        await engine.platform.manageSubscription(
          _consent(
            submission.consentFields,
            email: submission.email,
            phone: submission.phone,
          ),
        );
      } else {
        engine.log('form of popup ${popup.id}: consent without a contact');
      }
    }
    await _segment(submission.segmentId);
    event(PopupV3Event.submit);
  }

  @override
  Future<void> review({
    required String kind,
    required String code,
    required int rate,
    String? comment,
  }) async {
    await engine.platform.review(kind, <String, Object>{
      'channel': 'popup',
      kind == 'nps' ? 'category' : 'campaign': code,
      'rate': rate,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
    });
    event(PopupV3Event.submit);
  }

  Future<void> _segment(String? segmentId) async {
    final id = segmentId?.trim() ?? '';
    if (id.isEmpty) return;
    try {
      final identity = await engine.platform.identity();
      await engine.api.segmentAdd(engine.apiHost, identity, id);
      engine.onContextChanged('segment', 'add', <String, String>{
        'segment_id': id,
      });
    } catch (error) {
      engine.log('segment $id of popup ${popup.id} — $error', always: true);
    }
  }

  static ManageSubscriptionParams _consent(
    List<String> fields, {
    String? email,
    String? phone,
  }) => ManageSubscriptionParams(
    email: email,
    phone: phone,
    emailBulk: fields.contains('email_bulk') ? true : null,
    emailChain: fields.contains('email_chain') ? true : null,
    emailTransactional: fields.contains('email_transactional') ? true : null,
  );
}
