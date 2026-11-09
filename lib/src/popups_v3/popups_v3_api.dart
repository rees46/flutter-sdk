import 'dart:async';
import 'dart:convert';

import '../ui/widgets/stories_api_v3.dart';
import 'popup_v3.dart';
import 'popup_v3_values.dart';

/// `shop_id`, `did` и `sid`, с которыми идут запросы попапов.
typedef PopupsV3Identity = ({String shopId, String did, String sid});

/// Событие попапа для `POST /api/v3/storefront/popups/:id/events`.
enum PopupV3Event {
  show('show'),
  close('close'),
  click('click'),
  submit('submit'),
  subscribe('subscribe'),

  /// Зарезервировано под колесо фортуны, на mobile не отправляется.
  prize('prize');

  const PopupV3Event(this.wire);

  final String wire;
}

/// Чем кончился запрос списка.
enum PopupsV3ListOutcome {
  /// Список пришёл.
  success,

  /// 4xx или не тот ответ: кешируем пустой список на 300 с.
  clientError,

  /// Нет сети или 5xx: не кешируем, спросим при следующем поводе.
  failure,
}

/// Ответ на запрос списка.
typedef PopupsV3ListResult = ({
  PopupsV3ListOutcome outcome,
  PopupsV3List list,
  String? error,
});

/// HTTP попапов v3: список, один попап, события — на хосте ЛК (`app.rees46.ru`);
/// промокод и сегмент — на API-хосте магазина (`api.rees46.ru`).
///
/// Транспорт общий со сторис API v3 ([StoriesApiV3.send]): тот же шов для тестов и
/// офлайн-демо.
class PopupsV3Api {
  PopupsV3Api({StoriesV3Send? send, DateTime Function()? now})
    : _send =
          send ?? ((method, uri, body) => StoriesApiV3.send(method, uri, body)),
      _now = now ?? DateTime.now;

  final StoriesV3Send _send;
  final DateTime Function() _now;

  /// Ожидание ответа на любой запрос.
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Ожидание промокода: дольше попап не ждёт.
  static const Duration promoTimeout = Duration(seconds: 10);

  /// Сколько помнить выданный промокод списка.
  static const Duration promoCacheTtl = Duration(hours: 2);

  /// Пауза отправки событий после 429.
  static const Duration eventsPause = Duration(seconds: 60);

  final Map<String, ({String code, DateTime expires})> _promoCodes =
      <String, ({String code, DateTime expires})>{};
  DateTime? _eventsPausedUntil;

  /// `GET https://{appHost}/api/v3/storefront/popups?shop_id&did&sid&channel=mobile`
  /// `[&testmode=true][&debug=1]`.
  static Uri listUri(
    String appHost,
    PopupsV3Identity id, {
    bool testMode = false,
    bool debug = false,
  }) => StoriesApiV3.apiUri(
    appHost,
    const <String>['storefront', 'popups'],
    <String, String>{
      'shop_id': id.shopId,
      'did': id.did,
      'sid': id.sid,
      'channel': 'mobile',
      if (testMode) 'testmode': 'true',
      if (debug) 'debug': '1',
    },
  );

  /// `GET https://{appHost}/api/v3/storefront/popups/:id?shop_id&did&sid[&testmode=true]`.
  static Uri oneUri(
    String appHost,
    int popupId,
    PopupsV3Identity id, {
    bool testMode = false,
  }) => StoriesApiV3.apiUri(
    appHost,
    <String>['storefront', 'popups', '$popupId'],
    <String, String>{
      'shop_id': id.shopId,
      'did': id.did,
      'sid': id.sid,
      if (testMode) 'testmode': 'true',
    },
  );

  /// `POST https://{appHost}/api/v3/storefront/popups/:id/events`.
  static Uri eventsUri(String appHost, int popupId) => StoriesApiV3.apiUri(
    appHost,
    <String>['storefront', 'popups', '$popupId', 'events'],
  );

  /// Тело события: `channel` — только у `subscribe`.
  static Map<String, String> eventBody(
    PopupsV3Identity id,
    PopupV3Event event, {
    String? channel,
  }) => <String, String>{
    'shop_id': id.shopId,
    'did': id.did,
    'sid': id.sid,
    'event': event.wire,
    if (event == PopupV3Event.subscribe && channel != null) 'channel': channel,
  };

  /// `GET https://{apiHost}/promo_codes/fetch?shop_id&did&sid&id`.
  static Uri promoUri(String apiHost, PopupsV3Identity id, String listId) =>
      Uri.parse('https://$apiHost').replace(
        pathSegments: const <String>['promo_codes', 'fetch'],
        queryParameters: <String, String>{
          'shop_id': id.shopId,
          'did': id.did,
          'sid': id.sid,
          'id': listId,
        },
      );

  /// `POST https://{apiHost}/segments/add`.
  static Uri segmentUri(String apiHost) => Uri.parse(
    'https://$apiHost',
  ).replace(pathSegments: const <String>['segments', 'add']);

  /// Список попапов. Ответ не `success`, без `payload` или 4xx — пустой список с
  /// [PopupsV3ListOutcome.clientError]; нет сети или 5xx — [PopupsV3ListOutcome.failure].
  Future<PopupsV3ListResult> list(
    String appHost,
    PopupsV3Identity id, {
    bool testMode = false,
    bool debug = false,
  }) async {
    final StoriesV3Response response;
    try {
      response = await _send(
        'GET',
        listUri(appHost, id, testMode: testMode, debug: debug),
        null,
      ).timeout(requestTimeout);
    } catch (error) {
      return (
        outcome: PopupsV3ListOutcome.failure,
        list: PopupsV3List.empty,
        error: '$error',
      );
    }
    if (response.status >= 500) {
      return (
        outcome: PopupsV3ListOutcome.failure,
        list: PopupsV3List.empty,
        error: 'HTTP ${response.status}: ${_short(response.body)}',
      );
    }
    final json = _json(response.body);
    final payload = json?['payload'];
    if (response.status >= 300 ||
        json?['status'] != 'success' ||
        payload is! Map) {
      return (
        outcome: PopupsV3ListOutcome.clientError,
        list: PopupsV3List.empty,
        error: 'HTTP ${response.status}: ${_short(response.body)}',
      );
    }
    return (
      outcome: PopupsV3ListOutcome.success,
      list: PopupsV3List.parse(Map<String, Object?>.from(payload)),
      error: null,
    );
  }

  /// Один попап для ручного показа; нет его (404) или ошибка — `null` и причина в
  /// [onError].
  Future<PopupV3?> one(
    String appHost,
    int popupId,
    PopupsV3Identity id, {
    bool testMode = false,
    void Function(String error)? onError,
  }) async {
    try {
      final response = await _send(
        'GET',
        oneUri(appHost, popupId, id, testMode: testMode),
        null,
      ).timeout(requestTimeout);
      final json = _json(response.body);
      final payload = json?['payload'];
      if (response.status < 200 ||
          response.status >= 300 ||
          json?['status'] != 'success' ||
          payload is! Map) {
        onError?.call('HTTP ${response.status}: ${_short(response.body)}');
        return null;
      }
      String? skipped;
      final popup = PopupV3.tryParse(
        payload['popup'],
        onSkip: (_, reason) => skipped = reason,
      );
      if (popup == null) onError?.call(skipped ?? 'no popup');
      return popup;
    } catch (error) {
      onError?.call('$error');
      return null;
    }
  }

  /// Событие [event] попапа [popupId]. «Выстрелил и забыл»: один повтор при ошибке
  /// сети или 5xx, 4xx не повторяем, после 429 события минуту не отправляются.
  /// Возвращает код ответа (`null` — не отправлено) для лога.
  Future<int?> event(
    String appHost,
    int popupId,
    PopupsV3Identity id,
    PopupV3Event event, {
    String? channel,
  }) async {
    final pausedUntil = _eventsPausedUntil;
    if (pausedUntil != null && _now().isBefore(pausedUntil)) return null;
    final uri = eventsUri(appHost, popupId);
    final body = jsonEncode(eventBody(id, event, channel: channel));
    for (var attempt = 0; attempt < 2; attempt++) {
      int? status;
      try {
        status = (await _send(
          'POST',
          uri,
          body,
        ).timeout(requestTimeout)).status;
      } catch (_) {
        status = null;
      }
      if (status == 429) {
        _eventsPausedUntil = _now().add(eventsPause);
        return status;
      }
      if (status != null && status < 500) return status;
    }
    return null;
  }

  /// Персональный промокод из списка [listId]; нет кода, ошибка или нет ответа за
  /// [promoTimeout] — `null`. Выданный код помнится [promoCacheTtl].
  Future<String?> promoCode(
    String apiHost,
    PopupsV3Identity id,
    String listId,
  ) async {
    final cached = _promoCodes[listId];
    if (cached != null && _now().isBefore(cached.expires)) return cached.code;
    try {
      final response = await _send(
        'GET',
        promoUri(apiHost, id, listId),
        null,
      ).timeout(promoTimeout);
      if (response.status < 200 || response.status >= 300) return null;
      final code = cssPresent(_json(response.body)?['code'])?.trim();
      if (code == null) return null;
      _promoCodes[listId] = (code: code, expires: _now().add(promoCacheTtl));
      return code;
    } catch (_) {
      return null;
    }
  }

  /// Добавить устройство в сегмент [segmentId] (`segments/add` по `did`). Ошибка —
  /// исключение.
  Future<void> segmentAdd(
    String apiHost,
    PopupsV3Identity id,
    String segmentId,
  ) async {
    final number = int.tryParse(segmentId);
    final response = await _send(
      'POST',
      segmentUri(apiHost),
      jsonEncode(<String, Object>{
        'shop_id': id.shopId,
        'did': id.did,
        'sid': id.sid,
        'segment_id': number ?? segmentId,
      }),
    ).timeout(requestTimeout);
    final json = _json(response.body);
    if (response.status < 200 ||
        response.status >= 300 ||
        json?['status'] == 'error' ||
        json?['status'] == 'fail') {
      throw StoriesV3Exception(
        'segments/add HTTP ${response.status}: ${_short(response.body)}',
        status: response.status,
      );
    }
  }

  static Map<String, Object?>? _json(String body) {
    try {
      final json = jsonDecode(body);
      return json is Map ? Map<String, Object?>.from(json) : null;
    } on FormatException {
      return null;
    }
  }

  static String _short(String body) =>
      body.length > 200 ? '${body.substring(0, 200)}…' : body;
}
