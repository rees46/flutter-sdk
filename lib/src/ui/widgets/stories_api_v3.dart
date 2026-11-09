import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../personalization_sdk.dart';
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
/// Запросу нужны `shop_id` и `did`, `sid` не нужен. Без `did` сервер отвечает 400, а SDK
/// получает его при init: запрос ждёт его ([identity]).
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
      // Пустой запрос — без «?» на конце.
      queryParameters: query.isEmpty ? null : query,
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

  /// `shop_id` и `did` магазина [sdk]. `did` спрашивается раз в [didPoll], пока SDK его
  /// не получит; не дождались за [timeout] — [TimeoutException].
  static Future<({String shopId, String did})> identity(
    PersonalizationSdk sdk, {
    Duration timeout = didTimeout,
  }) async {
    final shop = StoriesSeenStore.shopOf(sdk);
    if (shop.isEmpty) throw StateError('stories API v3: unknown shop_id');
    for (var waited = Duration.zero; ; waited += didPoll) {
      String? did;
      try {
        did = await sdk.getDid();
      } catch (_) {
        // Инстанс ещё не готов — спросим снова.
      }
      if (did != null && did.isNotEmpty) return (shopId: shop, did: did);
      if (waited >= timeout) {
        throw TimeoutException('stories API v3: no did', timeout);
      }
      await Future<void>.delayed(didPoll);
    }
  }

  /// Лента блока [code] с хоста [host].
  static Future<StoriesBlock> feed(
    PersonalizationSdk sdk,
    String host,
    String code,
  ) async {
    final id = await identity(sdk);
    final response = await send(
      'GET',
      uri(
        host,
        <String>[code],
        <String, String>{'shop_id': id.shopId, 'did': id.did},
      ),
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
          'shop_id': id.shopId,
          'did': id.did,
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
    try {
      if (event == StoriesV3Event.view || event == StoriesV3Event.click) {
        await sdk.tracking.setSource(
          TrackingSource(type: TrackingSourceType.stories, code: code),
        );
      }
    } catch (error) {
      debugPrint('PersonalizationStories: tracking source — $error');
    }
    try {
      final id = await identity(sdk);
      final response = await send(
        'POST',
        uri(host, <String>[code, 'events'], const <String, String>{}),
        jsonEncode(
          eventBody(
            shopId: id.shopId,
            did: id.did,
            event: event,
            storyId: storyId,
            slideId: slideId,
          ),
        ),
      );
      if (response.status < 200 || response.status >= 300) {
        throw StoriesV3Exception('HTTP ${response.status}: ${response.body}');
      }
    } catch (error) {
      debugPrint('PersonalizationStories: v3 ${event.wire} — $error');
    }
  }

  /// Тело события: id кампании — числом, как в ленте; id слайда — всегда строкой.
  static Map<String, Object> eventBody({
    required String shopId,
    required String did,
    required StoriesV3Event event,
    required String storyId,
    required String slideId,
  }) {
    final number = int.tryParse(storyId);
    return <String, Object>{
      'shop_id': shopId,
      'did': did,
      'event': event.wire,
      'story_id': number != null && '$number' == storyId ? number : storyId,
      'slide_id': slideId,
    };
  }

  /// Ответ GET: `{"status":"success","payload":{id, settings, stories}}` — `payload` тем
  /// же разбором, что и старая лента. HTTP не 2xx, не JSON, `status` не `success` или
  /// нет `payload` — [StoriesV3Exception].
  static StoriesBlock parseResponse(StoriesV3Response response) {
    final json = _decode(response);
    if (json['status'] != 'success' || json['payload'] is! Map) {
      throw StoriesV3Exception('unexpected response: ${_short(response)}');
    }
    return StoriesBlock.fromJson(
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
