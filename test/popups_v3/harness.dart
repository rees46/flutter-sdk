import 'dart:async';
import 'dart:convert';

import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/personalization_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/popups_v3/popup_v3.dart';
import 'package:rees46_sdk/src/popups_v3/popups_v3_api.dart';
import 'package:rees46_sdk/src/popups_v3/popups_v3_engine.dart';
import 'package:rees46_sdk/src/popups_v3/popups_v3_frequency.dart';
import 'package:rees46_sdk/src/ui/components/personalization_product.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_api_v3.dart';

/// Мост без натива: `did`, `sid` и вызовы профиля, подписки, ссылок.
class FakeHostApi extends pigeon.PersonalizationHostApi {
  String? did = 'DID123';
  String sid = 'SID123';
  final List<pigeon.ProfileParamsWire> profiles = <pigeon.ProfileParamsWire>[];
  final List<pigeon.ManageSubscriptionParamsWire> subscriptions =
      <pigeon.ManageSubscriptionParamsWire>[];
  final List<String> opened = <String>[];

  @override
  Future<void> initialize(pigeon.InitConfig config) async {}

  @override
  Future<String?> getDid(String? shopId) async => did;

  @override
  Future<String> getSid(String? shopId) async => sid;

  @override
  Future<void> setProfile(
    pigeon.ProfileParamsWire params,
    String? shopId,
  ) async => profiles.add(params);

  @override
  Future<void> manageSubscription(
    pigeon.ManageSubscriptionParamsWire params,
    String? shopId,
  ) async => subscriptions.add(params);

  @override
  Future<bool> openUrl(String url) async {
    opened.add(url);
    return true;
  }
}

/// Часы, которые идут только по [advance].
class FakeClock implements PopupsV3Clock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime(2026, 11, 3, 12);

  DateTime _now;
  final List<_FakeTimer> _timers = <_FakeTimer>[];

  @override
  DateTime now() => _now;

  @override
  Timer timer(Duration delay, void Function() callback) {
    final timer = _FakeTimer(_now.add(delay), callback);
    _timers.add(timer);
    return timer;
  }

  /// Сдвинуть время на [by], срабатывая таймеры по порядку.
  void advance(Duration by) {
    final target = _now.add(by);
    while (true) {
      final due =
          _timers
              .where((timer) => timer.isActive && !timer.at.isAfter(target))
              .toList()
            ..sort((a, b) => a.at.compareTo(b.at));
      if (due.isEmpty) break;
      final timer = due.first;
      _now = timer.at;
      timer.fire();
    }
    _now = target;
    _timers.removeWhere((timer) => !timer.isActive);
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.at, this._callback);

  final DateTime at;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// Показ без экрана: какие попапы на экране и их действия.
class FakePresenter implements PopupsV3Presenter {
  final List<int> shown = <int>[];
  final Map<int, FakeShown> open = <int, FakeShown>{};
  final Map<int, PopupV3Actions> actions = <int, PopupV3Actions>{};
  final Map<int, Map<String, String>> variables = <int, Map<String, String>>{};

  @override
  Future<PopupsV3Shown?> present(
    PopupV3 popup,
    Map<String, String> variables,
    PopupV3Actions actions,
  ) async {
    shown.add(popup.id);
    this.actions[popup.id] = actions;
    this.variables[popup.id] = variables;
    return open[popup.id] = FakeShown(() => open.remove(popup.id));
  }

  /// Закрыть попап [id] пользователем.
  void close(int id) {
    actions[id]?.event(PopupV3Event.close);
    open[id]?.dismiss();
  }
}

class FakeShown implements PopupsV3Shown {
  FakeShown(this._onClosed);

  final void Function() _onClosed;
  final Completer<void> _closed = Completer<void>();

  @override
  Future<void> get closed => _closed.future;

  @override
  void dismiss() {
    if (_closed.isCompleted) return;
    _onClosed();
    _closed.complete();
  }
}

/// Платформа движка поверх [FakeHostApi]; отзывы — в [reviews].
class FakePlatform implements PopupsV3Platform {
  FakePlatform(this.sdk, this.host);

  final PersonalizationSdk sdk;
  final FakeHostApi host;
  final List<({String kind, Map<String, Object> body})> reviews =
      <({String kind, Map<String, Object> body})>[];
  Object? reviewError;

  @override
  Future<PopupsV3Identity> identity() async =>
      (shopId: 'c1140c8254976de297c3caf971701a', did: host.did!, sid: host.sid);

  @override
  Future<bool> openUrl(String url) => sdk.openUrl(url);

  @override
  Future<void> manageSubscription(ManageSubscriptionParams params) =>
      sdk.manageSubscription(params);

  @override
  Future<void> setProfile(ProfileParams params) => sdk.setProfile(params);

  @override
  Future<void> review(String kind, Map<String, Object> body) async {
    final error = reviewError;
    if (error != null) throw error;
    reviews.add((kind: kind, body: body));
  }
}

/// Один HTTP-запрос.
typedef FakeRequest = ({String method, Uri uri, Map<String, Object?>? body});

/// Сервер попапов: список, один попап, события, промокоды, сегменты.
class FakeServer {
  FakeServer({List<Map<String, Object?>>? popups})
    : popups = popups ?? <Map<String, Object?>>[];

  List<Map<String, Object?>> popups;
  final List<FakeRequest> requests = <FakeRequest>[];

  /// Ответ на список: код и тело; `null` — список [popups].
  StoriesV3Response? listReply;

  /// Код ответа на события.
  int eventsStatus = 200;

  /// Промокод; `null` — 404.
  String? promoCode;

  Future<StoriesV3Response> send(String method, Uri uri, String? body) async {
    requests.add((
      method: method,
      uri: uri,
      body: body == null ? null : jsonDecode(body) as Map<String, Object?>,
    ));
    final path = uri.path;
    if (path == '/api/v3/storefront/popups') {
      return listReply ??
          (
            status: 200,
            body: jsonEncode(<String, Object?>{
              'status': 'success',
              'payload': <String, Object?>{'ttl': 300, 'popups': popups},
            }),
          );
    }
    if (path.endsWith('/events')) {
      return (status: eventsStatus, body: '{"status":"success"}');
    }
    final one = RegExp(r'^/api/v3/storefront/popups/(\d+)$').firstMatch(path);
    if (one != null) {
      final id = int.parse(one.group(1)!);
      for (final popup in popups) {
        if (popup['id'] == id) {
          return (
            status: 200,
            body: jsonEncode(<String, Object?>{
              'status': 'success',
              'payload': <String, Object?>{'popup': popup},
            }),
          );
        }
      }
      return (
        status: 404,
        body: '{"status":"fail","message":"Resource not found"}',
      );
    }
    if (path == '/promo_codes/fetch') {
      final code = promoCode;
      return code == null
          ? (
              status: 404,
              body:
                  '{"status":"error","message":"Promo codes list is not found"}',
            )
          : (status: 200, body: jsonEncode(<String, Object?>{'code': code}));
    }
    if (path == '/segments/add') {
      return (status: 200, body: '{"status":"success"}');
    }
    return (status: 404, body: '{}');
  }

  List<FakeRequest> where(bool Function(FakeRequest request) test) =>
      requests.where(test).toList();

  List<FakeRequest> get lists =>
      where((request) => request.uri.path == '/api/v3/storefront/popups');

  /// События: `(id, event)`.
  List<String> get events => <String>[
    for (final request in where(
      (request) => request.uri.path.endsWith('/events'),
    ))
      '${request.uri.pathSegments[4]}:${request.body!['event']}',
  ];
}

/// Движок на подставных часах, сервере, хранилище и показе.
class EngineHarness {
  EngineHarness({
    FakeServer? server,
    PopupsV3MemoryStorage? storage,
    FakeClock? clock,
    FakeHostApi? host,
  }) : server = server ?? FakeServer(),
       storage = storage ?? PopupsV3MemoryStorage(),
       clock = clock ?? FakeClock(),
       host = host ?? FakeHostApi() {
    sdk = PersonalizationSdk(
      api: this.host,
      shopId: 'c1140c8254976de297c3caf971701a',
    );
    platform = FakePlatform(sdk, this.host);
    engine = PopupsV3Engine(
      sdk: sdk,
      platform: platform,
      presenter: presenter,
      api: PopupsV3Api(send: this.server.send, now: this.clock.now),
      storage: this.storage,
      clock: this.clock,
    );
  }

  final FakeServer server;
  final PopupsV3MemoryStorage storage;
  final FakeClock clock;
  final FakeHostApi host;
  final FakePresenter presenter = FakePresenter();
  late final PersonalizationSdk sdk;
  late final FakePlatform platform;
  late final PopupsV3Engine engine;

  /// Тот же «телефон» после перезапуска приложения: хранилище, часы, сервер и сеанс
  /// прежние, движок новый.
  EngineHarness restart() =>
      EngineHarness(server: server, storage: storage, clock: clock, host: host);
}

/// Товар для действий рекомендаций.
const PersonalizationProduct fakeProduct = PersonalizationProduct(
  id: '868',
  name: 'Товар',
  price: '100 ₽',
  url: 'https://demo.rees46.ru/product/868',
);
