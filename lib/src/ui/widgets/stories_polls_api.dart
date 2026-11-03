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
/// виджета, `show` и `handleLink` (`pollsTransport`).
abstract interface class StoryPollsTransport {
  /// Ответ мини-опроса [code]. [body] — `{option_ids | text, story_id, slide_id}`
  /// ([storyPollAnswerBody]); `shop_id`, `did` и `sid` добавляет транспорт.
  Future<StoryPollReply> answerMiniPoll(String code, Map<String, Object> body);

  /// Оценка шкалы [kind] (NPS, CSAT, CES). [body] — `{channel, category | campaign,
  /// rate}` ([storyPollReviewBody]); `shop_id`, `did` и `sid` добавляет транспорт.
  Future<StoryPollReply> review(StoryPollType kind, Map<String, Object> body);
}

/// Тело ответа мини-опроса: варианты [optionIds] или текст [text]; id кампании —
/// числом, как в ленте; id слайда — всегда строкой (у товарных слайдов он `39_0`).
Map<String, Object> storyPollAnswerBody({
  List<int>? optionIds,
  String? text,
  required String storyId,
  required String slideId,
}) {
  final number = int.tryParse(storyId);
  return <String, Object>{
    'option_ids': ?optionIds,
    'text': ?text,
    if (storyId.isNotEmpty)
      'story_id': number != null && '$number' == storyId ? number : storyId,
    if (slideId.isNotEmpty) 'slide_id': slideId,
  };
}

/// Тело оценки шкалы [poll]: канал опроса (пусто — `stories`), код — `category` у NPS
/// и `campaign` у CSAT и CES.
Map<String, Object> storyPollReviewBody(StoryPollElement poll, int rate) =>
    <String, Object>{
      'channel': poll.channel.isNotEmpty ? poll.channel : 'stories',
      poll.pollType == StoryPollType.nps ? 'category' : 'campaign': poll.code,
      'rate': rate,
    };

/// Опросы API v3 на хосте [host] просмотра, с которого пришла лента:
/// - мини-опрос — `POST /api/v3/polls/mini_polls/{code}/answers`;
/// - шкала — `POST /api/v3/polls/{nps|csat|ces}/reviews`.
///
/// К телу добавляются `shop_id`, `did` (ждём его, как лента: [StoriesApiV3.identity]) и
/// `sid` сеанса SDK — всегда, без сеанса пустой строкой. Транспорт, таймаут и разбор
/// `{status, payload}` — [StoriesApiV3.post]; ошибки — его, в отладочный лог с кодом HTTP
/// и `message` сервера.
class StoriesPollsApi implements StoryPollsTransport {
  StoriesPollsApi(this.sdk, this.host);

  final PersonalizationSdk sdk;

  /// Хост API v3 без схемы (`app.rees46.ru`).
  final String host;

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
      rethrow;
    }
  }

  Future<Map<String, Object>> _identified(Map<String, Object> body) async {
    final id = await StoriesApiV3.identity(sdk);
    var sid = '';
    try {
      sid = await sdk.getSid();
    } catch (_) {
      // Нет сеанса — пустой `sid`.
    }
    return <String, Object>{
      'shop_id': id.shopId,
      'did': id.did,
      'sid': sid,
      ...body,
    };
  }
}
