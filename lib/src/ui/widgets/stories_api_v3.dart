import '../../core/sdk_logs.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../init/sdk_init_handler.dart';
import '../../personalization_sdk.dart';
import '../../popups_v3/popups_v3.dart';
import '../../popups_v3/popups_v3_hooks.dart';
import '../../stories/stories_response.dart';
import '../../tracking/tracking_models.dart';
import 'stories_seen_store.dart';
import 'stories_share.dart';

/// Событие сторис API v3.
enum StoriesV3Event {
  view('view'),
  click('click'),
  share('share'),
  sharedOpen('shared_open');

  const StoriesV3Event(this.wire);

  /// Значение поля `event`.
  final String wire;
}

/// Кто спрашивает API v3 ([StoriesApiV3.identity]).
typedef StoriesV3Identity = ({
  String shopId,
  String did,
  String sid,
  String segment,
  String stream,
  bool testMode,
});

/// Ответ HTTP: код и тело.
typedef StoriesV3Response = ({int status, String body});

/// Отправить запрос [method] на [uri] с телом JSON [body] (`null` — без тела).
typedef StoriesV3Send =
    Future<StoriesV3Response> Function(String method, Uri uri, String? body);

/// Ошибка API v3: HTTP не 2xx, не JSON или `status` не `success`.
class StoriesV3Exception implements Exception {
  StoriesV3Exception(this.message, {this.status});

  final String message;

  /// Код HTTP ответа; `null` — ошибка не в коде (не JSON, `status: fail`).
  final int? status;

  @override
  String toString() => 'StoriesV3Exception: $message';
}

/// Сторис V2 на API v3 — из Dart, без нативного SDK: `dart:io` и `did` через мост.
///
/// Включается хостом: своим у `PersonalizationStoriesV3` над блоком, `show` или
/// просмотром или у `PersonalizationStoriesV3.handleLink` (их `apiV3Domain`), без него —
/// глобальным [domain] (`PersonalizationStoriesV3.apiV3Domain`); см. [host]. Нет
/// хоста — лента и события идут по-старому, через мост (`stories/{code}`,
/// `track/stories`). Есть — все запросы V2 этого блока идут на `https://{host}`:
/// - лента — `GET /api/v3/storefront/stories/{code}`;
/// - кампания по ссылке — `GET /api/v3/storefront/stories/{code}/story/{id}[?slide_id=]`;
/// - события — `POST /api/v3/storefront/stories/{code}/events`;
/// - ответы опросов слайдов — [post] (`/api/v3/polls/...`, `StoriesPollsApi`).
///
/// Запросы несут `shop_id`, `did`, `sid`, `segment`, `stream` и `testmode`, как веб
/// ([identity]). Без `did` сервер отвечает 400, а SDK получает его при init: запрос ждёт
/// его.
abstract final class StoriesApiV3 {
  /// Глобальный хост API v3 без схемы (`app.rees46.ru`) — для блоков без своего;
  /// `null` или пусто — старый API.
  static String? domain;

  /// Как ходить в сеть. Тесты подменяют.
  static StoriesV3Send send = _send;

  /// Как часто спрашивать `did`, пока SDK его не получил.
  static const Duration didPoll = Duration(milliseconds: 200);

  /// Сколько ждать `did` по умолчанию.
  static const Duration didTimeout = Duration(seconds: 15);

  /// Сколько ждать ответа на [post].
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Хост API v3 блока: свой [own], без него (`null`) — глобальный [domain]. Схема и
  /// `/` на конце отбрасываются. `null` — API v3 выключен: хоста нет или он пустой (так
  /// блок уходит на старый API и при заданном глобальном).
  static String? host(String? own) {
    var host = (own ?? domain)?.trim() ?? '';
    host = host.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    while (host.endsWith('/')) {
      host = host.substring(0, host.length - 1);
    }
    return host.isEmpty ? null : host;
  }

  /// Адрес `https://{host}/api/v3/storefront/stories/{segments...}?{query}`.
  static Uri uri(
    String host,
    List<String> segments,
    Map<String, String> query,
  ) => apiUri(host, <String>['storefront', 'stories', ...segments], query);

  /// Адрес `https://{host}/api/v3/{segments...}?{query}`; сегменты кодируются.
  static Uri apiUri(
    String host,
    List<String> segments, [
    Map<String, String> query = const <String, String>{},
  ]) {
    return Uri.parse('https://$host').replace(
      pathSegments: <String>['api', 'v3', ...segments],
      // Пустой запрос — без «?» на конце. Пустое значение — `key=`, как в вебе (сам
      // `Uri` пишет просто `key`).
      query: query.isEmpty
          ? null
          : <String>[
              for (final MapEntry(:key, :value) in query.entries)
                '${Uri.encodeQueryComponent(key)}='
                    '${Uri.encodeQueryComponent(value)}',
            ].join('&'),
    );
  }

  /// `POST https://{host}/api/v3/{segments...}` с телом JSON [body] — ответ
  /// `{status, payload}` целиком. Ошибка — нет сети, нет ответа за [requestTimeout],
  /// HTTP не 2xx ([StoriesV3Exception.status] — код, в сообщении `message` сервера), не
  /// JSON или `status` `fail` / `error`.
  static Future<Map<String, dynamic>> post(
    String host,
    List<String> segments,
    Map<String, Object?> body,
  ) async {
    final response = await send(
      'POST',
      apiUri(host, segments),
      jsonEncode(body),
    ).timeout(requestTimeout);
    final json = _decode(response);
    final status = json['status'];
    if (status == 'fail' || status == 'error') {
      throw StoriesV3Exception(
        '$status: ${json['message'] ?? _short(response)}',
      );
    }
    return json;
  }

  /// Тело ответа объектом JSON. HTTP не 2xx — ошибка с кодом и `message` сервера, если
  /// он есть; не JSON или не объект — ошибка.
  static Map<String, dynamic> _decode(StoriesV3Response response) {
    Object? json;
    try {
      json = jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    final ok = response.status >= 200 && response.status < 300;
    if (!ok) {
      final message = json is Map ? json['message'] : null;
      throw StoriesV3Exception(
        'HTTP ${response.status}: ${message ?? _short(response)}',
        status: response.status,
      );
    }
    if (json is! Map) {
      throw StoriesV3Exception('not JSON: ${_short(response)}');
    }
    return Map<String, dynamic>.from(json);
  }

  /// Последний `did` каждого магазина, которым ходили запросы: ключ сохранённых ответов
  /// опросов, когда копии моста ещё нет ([knownDid]).
  static final Map<String, String> _dids = <String, String>{};

  /// Кто спрашивает: магазин, устройство и сеанс, группа A/B устройства, поток и
  /// тестовый режим. `did` берётся из копии моста, без неё спрашивается раз в
  /// [didPoll], пока SDK его не получит; не дождались за [timeout] —
  /// [TimeoutException]. `sid` — сеанс моста (нет — пустая строка), `segment` —
  /// `segments.getAbGroup()` (до init пустой), `stream` — поток init (по умолчанию
  /// `flutter`), тестовый режим — у попапов v3 (`sdk.popups.testMode`).
  static Future<StoriesV3Identity> identity(
    PersonalizationSdk sdk, {
    Duration timeout = didTimeout,
  }) async {
    final shop = StoriesSeenStore.shopOf(sdk);
    if (shop.isEmpty) throw StateError('stories API v3: unknown shop_id');
    final did = await _did(sdk, timeout);
    _dids[shop] = did;
    var segment = '';
    try {
      segment = sdk.segments.getAbGroup();
    } catch (_) {
      // Группы ещё нет — пустая строка, как без согласия в вебе.
    }
    return (
      shopId: shop,
      did: did,
      sid: await _sid(sdk),
      segment: segment,
      stream: streamOf(sdk),
      testMode: PopupsV3.testModeOf(sdk),
    );
  }

  /// `did` магазина [sdk] сейчас, без ожидания: копия моста, иначе последний, с которым
  /// ходили запросы; не знаем — пустая строка.
  static String knownDid(PersonalizationSdk sdk) {
    final mirrored = sdk.deviceId ?? '';
    if (mirrored.isNotEmpty) return mirrored;
    return _dids[StoriesSeenStore.shopOf(sdk)] ?? '';
  }

  /// Поток магазина [sdk] из init; не задан — `flutter`.
  static String streamOf(PersonalizationSdk sdk) {
    final stream = PopupsV3Hooks.configOf(sdk.tracking)?.stream?.trim() ?? '';
    return stream.isEmpty ? SdkInitHandler.defaultStream : stream;
  }

  static Future<String> _did(PersonalizationSdk sdk, Duration timeout) async {
    for (var waited = Duration.zero; ; waited += didPoll) {
      var did = sdk.deviceId;
      if (did == null || did.isEmpty) {
        try {
          did = await sdk.getDid();
        } catch (_) {
          // Инстанс ещё не готов — спросим снова.
        }
      }
      if (did != null && did.isNotEmpty) return did;
      if (waited >= timeout) {
        throw TimeoutException('stories API v3: no did', timeout);
      }
      await Future<void>.delayed(didPoll);
    }
  }

  static Future<String> _sid(PersonalizationSdk sdk) async {
    final mirrored = sdk.sessionId ?? '';
    if (mirrored.isNotEmpty) return mirrored;
    try {
      return await sdk.getSid();
    } catch (_) {
      // Нет сеанса — пустой `sid`.
      return '';
    }
  }

  /// Параметры ленты и сторис по ссылке: `shop_id`, `did`, `sid`, `segment`, `stream` и
  /// `testmode=true` только в тестовом режиме.
  static Map<String, String> identityQuery(StoriesV3Identity id) =>
      <String, String>{
        'shop_id': id.shopId,
        'did': id.did,
        'sid': id.sid,
        'segment': id.segment,
        'stream': id.stream,
        if (id.testMode) 'testmode': 'true',
      };

  /// Лента блока [code] с хоста [host].
  static Future<StoriesBlock> feed(
    PersonalizationSdk sdk,
    String host,
    String code,
  ) async {
    final id = await identity(sdk);
    final response = await send(
      'GET',
      uri(host, <String>[code], identityQuery(id)),
      null,
    );
    return parseResponse(response);
  }

  /// Кампания ссылки [link] в формате ленты (обычно одна); `start_position` — слайд
  /// ссылки. Нет кампании, она выключена или ей нельзя делиться — 404, ошибка.
  static Future<StoriesBlock> story(
    PersonalizationSdk sdk,
    String host,
    StoriesShareLink link,
  ) async {
    final id = await identity(sdk);
    final response = await send(
      'GET',
      uri(
        host,
        <String>[link.code, 'story', link.storyId],
        <String, String>{
          ...identityQuery(id),
          if (link.slideId != null) 'slide_id': link.slideId!,
        },
      ),
      null,
    );
    return parseResponse(response);
  }

  /// Событие [event] слайда [slideId] кампании [storyId] блока [code]. Ошибки — в лог:
  /// просмотр от трекинга не зависит. `view` и `click` ещё и ставят источник следующих
  /// событий — блок сторис, как это делает натив при старом трекинге.
  static Future<void> track(
    PersonalizationSdk sdk,
    String host, {
    required String code,
    required StoriesV3Event event,
    required String storyId,
    required String slideId,
  }) async {
    if (code.isEmpty || storyId.isEmpty || slideId.isEmpty) return;
    if (event == StoriesV3Event.view || event == StoriesV3Event.click) {
      sdk.tracking.setSource(
        TrackingSource(type: TrackingSourceType.stories, code: code),
      );
    }
    try {
      final id = await identity(sdk);
      final response = await send(
        'POST',
        uri(host, <String>[code, 'events'], const <String, String>{}),
        jsonEncode(
          eventBody(id, event: event, storyId: storyId, slideId: slideId),
        ),
      );
      if (response.status < 200 || response.status >= 300) {
        throw StoriesV3Exception('HTTP ${response.status}: ${response.body}');
      }
    } catch (error) {
      debugPrint('PersonalizationStories: v3 ${event.wire} — $error');
      SdkLogs.log(
        LogLevel.warning,
        'stories_v3',
        'event ${event.wire} not sent',
        shopId: sdk.shopId,
        context: <String, Object?>{
          if (error is StoriesV3Exception && error.status != null)
            'http_code': error.status,
        },
      );
    }
  }

  /// Тело события: кто спрашивает ([identityQuery], `testmode` — `true`), событие, id
  /// кампании — числом, если он числовой, как в ленте; id слайда — всегда строкой
  /// (`12_0` тоже).
  static Map<String, Object> eventBody(
    StoriesV3Identity id, {
    required StoriesV3Event event,
    required String storyId,
    required String slideId,
  }) {
    final number = int.tryParse(storyId);
    return <String, Object>{
      'shop_id': id.shopId,
      'did': id.did,
      'sid': id.sid,
      'segment': id.segment,
      'stream': id.stream,
      if (id.testMode) 'testmode': true,
      'event': event.wire,
      'story_id': number != null && '$number' == storyId ? number : storyId,
      'slide_id': slideId,
    };
  }

  /// Ответ GET: `{"status":"success","payload":{id, settings, stories}}` — `payload` тем
  /// же разбором, что и старая лента, плюс то, что есть только у API v3
  /// ([parseStoriesBlockV3]). HTTP не 2xx, не JSON, `status` не `success` или
  /// нет `payload` — [StoriesV3Exception].
  static StoriesBlock parseResponse(StoriesV3Response response) {
    final json = _decode(response);
    if (json['status'] != 'success' || json['payload'] is! Map) {
      throw StoriesV3Exception('unexpected response: ${_short(response)}');
    }
    return parseStoriesBlockV3(
      Map<String, dynamic>.from(json['payload'] as Map),
    );
  }

  static String _short(StoriesV3Response response) {
    final body = response.body;
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }

  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  static Future<StoriesV3Response> _send(
    String method,
    Uri uri,
    String? body,
  ) async {
    final request = await _client.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    return (status: response.statusCode, body: text);
  }
}
