import '../../core/sdk_logs.dart';
import 'package:flutter/foundation.dart';

import '../../personalization_sdk.dart';
import '../../stories/stories_response.dart';
import 'stories_api_v3.dart';

/// Успешная отправка ответа опроса: что вернул сервер.
class StoryPollReply {
  const StoryPollReply({this.answer, this.results});

  /// Ответ, как его запомнил сервер (`payload.answer`); `null` — не прислал.
  final StoryPollAnswer? answer;

  /// Итоги мини-опроса (`payload.results`, только при `show_results`).
  final StoryPollResults? results;
}

/// Как отправлять ответы опросов слайдов. Ошибка отправки — Future с ошибкой; в лог её
/// пишет сам транспорт (карточка не пишет).
///
/// По умолчанию — [StoriesPollsApi] (HTTP API v3). Тесты и офлайн-демо подменяют его у
/// `PersonalizationStoriesV3` и `PersonalizationStoriesV3.handleLink` (`pollsTransport`).
abstract interface class StoryPollsTransport {
  /// Ответ мини-опроса [code]. [body] — `{option_ids | text}` и источник ответа
  /// ([storyPollAnswerBody]); `shop_id`, `did`, `sid`, `stream` и `testmode` добавляет
  /// транспорт.
  Future<StoryPollReply> answerMiniPoll(String code, Map<String, Object> body);

  /// Оценка шкалы [kind] (NPS, CSAT, CES). [body] — `{channel, category | campaign,
  /// rate[, comment]}` и источник ([storyPollReviewBody]); `shop_id`, `did`, `sid`,
  /// `stream` и `testmode` добавляет транспорт.
  Future<StoryPollReply> review(StoryPollType kind, Map<String, Object> body);
}

/// Источник ответа для отчётов опросов, как в вебе: `source_type: stories`,
/// `source_id` — кампания, `source_item_id` — слайд, всё строками (у слайдов товарных
/// кампаний id вида `12_0`). Без кампании источника нет; пустой слайд не уходит.
Map<String, Object> storyPollSource({
  required String storyId,
  required String slideId,
}) => storyId.isEmpty
    ? const <String, Object>{}
    : <String, Object>{
        'source_type': 'stories',
        'source_id': storyId,
        if (slideId.isNotEmpty) 'source_item_id': slideId,
      };

/// Тело ответа мини-опроса: варианты [optionIds] или текст [text] и источник ответа
/// ([storyPollSource]).
Map<String, Object> storyPollAnswerBody({
  List<int>? optionIds,
  String? text,
  required String storyId,
  required String slideId,
}) => <String, Object>{
  'option_ids': ?optionIds,
  'text': ?text,
  ...storyPollSource(storyId: storyId, slideId: slideId),
};

/// Тело оценки [rate] шкалы [poll]: канал опроса (пусто — `stories`), код — `category`
/// у NPS и `campaign` у CSAT и CES, комментарий [comment] — только непустой (ответ на
/// вопрос полосы уходит второй оценкой с той же оценкой), и источник ответа
/// ([storyPollSource]).
Map<String, Object> storyPollReviewBody(
  StoryPollElement poll,
  num rate, {
  String? comment,
  String storyId = '',
  String slideId = '',
}) => <String, Object>{
  'channel': poll.channel.isNotEmpty ? poll.channel : 'stories',
  poll.pollType == StoryPollType.nps ? 'category' : 'campaign': poll.code,
  'rate': rate,
  if (comment != null && comment.isNotEmpty) 'comment': comment,
  ...storyPollSource(storyId: storyId, slideId: slideId),
};

/// Опросы API v3 на хосте [host] просмотра, с которого пришла лента:
/// - мини-опрос — `POST /api/v3/polls/mini_polls/{code}/answers`;
/// - шкала — `POST /api/v3/polls/{nps|csat|ces}/reviews`.
///
/// К телу добавляются `shop_id`, `did` (ждём его, как лента: [StoriesApiV3.identity]),
/// `sid` сеанса SDK — всегда, без сеанса пустой строкой, — `stream` и `testmode: true` в
/// тестовом режиме; `segment`, как и веб, — нет. Транспорт, таймаут и разбор
/// `{status, payload}` — [StoriesApiV3.post]; ошибки — его, в отладочный лог с кодом HTTP
/// и `message` сервера.
class StoriesPollsApi implements StoryPollsTransport {
  StoriesPollsApi(this.sdk, this.host, {this.streamAndTestMode = true});

  final PersonalizationSdk sdk;

  /// Хост API v3 без схемы (`app.rees46.ru`).
  final String host;

  /// Слать `stream` и `testmode`, как опросы сторис; отзывы попапов v3 их не шлют.
  final bool streamAndTestMode;

  @override
  Future<StoryPollReply> answerMiniPoll(
    String code,
    Map<String, Object> body,
  ) async {
    final json = await _logged(
      'mini poll "$code"',
      () async => StoriesApiV3.post(host, <String>[
        'polls',
        'mini_polls',
        code,
        'answers',
      ], await _identified(body)),
    );
    final payload = json['payload'];
    if (payload is! Map) return const StoryPollReply();
    return StoryPollReply(
      answer: StoryPollAnswer.tryParse(payload['answer']),
      results: StoryPollResults.tryParse(payload['results']),
    );
  }

  @override
  Future<StoryPollReply> review(
    StoryPollType kind,
    Map<String, Object> body,
  ) async {
    await _logged(
      '${kind.wire} "${body['category'] ?? body['campaign'] ?? ''}"',
      () async => StoriesApiV3.post(host, <String>[
        'polls',
        kind.wire,
        'reviews',
      ], await _identified(body)),
    );
    return const StoryPollReply();
  }

  /// Запрос [request] опроса [what]; ошибка — в отладочный лог и дальше.
  static Future<Map<String, dynamic>> _logged(
    String what,
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } catch (error) {
      debugPrint('PersonalizationStories: poll $what not sent — $error');
      SdkLogs.log(LogLevel.warning, 'stories_v3', 'poll $what not sent');
      rethrow;
    }
  }

  Future<Map<String, Object>> _identified(Map<String, Object> body) async =>
      identifiedBody(
        await StoriesApiV3.identity(sdk),
        body,
        streamAndTestMode: streamAndTestMode,
      );

  /// Тело запроса опроса: кто спрашивает и [body].
  static Map<String, Object> identifiedBody(
    StoriesV3Identity id,
    Map<String, Object> body, {
    bool streamAndTestMode = true,
  }) => <String, Object>{
    'shop_id': id.shopId,
    'did': id.did,
    'sid': id.sid,
    if (streamAndTestMode) ...<String, Object>{
      'stream': id.stream,
      if (id.testMode) 'testmode': true,
    },
    ...body,
  };
}
