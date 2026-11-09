import 'package:flutter/widgets.dart';

import 'stories_poll.dart';
import 'stories_polls_api.dart';

/// Режим API v3 сторис V2: хост, «Поделиться» и опросы слайдов. Внутренность кита: хост
/// задаёт режим через `PersonalizationStoriesV3` шлюза v3 (`src/v3/personalization_v3.dart`),
/// блок, `show`, ссылка и просмотр читают его отсюда.
@immutable
class StoriesV3Options {
  const StoriesV3Options({
    this.apiV3Domain,
    this.shareLabel = 'Share',
    this.shareUrlTransform,
    this.pollsTransport,
    this.pollTexts = const StoryPollTexts(),
  });

  /// Хост API v3 без схемы; `null` — глобальный (`StoriesApiV3.domain`), пустая строка —
  /// старый API и при заданном глобальном.
  final String? apiV3Domain;

  /// Подпись «Поделиться» для скринридера.
  final String shareLabel;

  /// Что сделать со ссылкой слайда перед окном «Поделиться»; `null` — ссылка как есть.
  final String Function(String url)? shareUrlTransform;

  /// Куда отправлять ответы опросов; `null` — HTTP API v3 хоста.
  final StoryPollsTransport? pollsTransport;

  /// Тексты карточки опроса от хоста.
  final StoryPollTexts pollTexts;

  /// Те же настройки без своего транспорта опросов.
  StoriesV3Options withoutPollsTransport() => StoriesV3Options(
    apiV3Domain: apiV3Domain,
    shareLabel: shareLabel,
    shareUrlTransform: shareUrlTransform,
    pollTexts: pollTexts,
  );

  @override
  bool operator ==(Object other) =>
      other is StoriesV3Options &&
      other.apiV3Domain == apiV3Domain &&
      other.shareLabel == shareLabel &&
      other.shareUrlTransform == shareUrlTransform &&
      other.pollsTransport == pollsTransport &&
      other.pollTexts.reanswer == pollTexts.reanswer &&
      other.pollTexts.error == pollTexts.error &&
      other.pollTexts.submit == pollTexts.submit;

  @override
  int get hashCode => Object.hash(
    apiV3Domain,
    shareLabel,
    shareUrlTransform,
    pollsTransport,
    pollTexts.reanswer,
    pollTexts.error,
    pollTexts.submit,
  );
}

/// Режим API v3 поддерева ([StoriesV3Options]). Ставит его `PersonalizationStoriesV3`, а
/// `show` и ссылки — вокруг своего просмотра: тот открывается на корневом навигаторе,
/// вне поддерева хоста.
class StoriesV3Scope extends InheritedWidget {
  const StoriesV3Scope({
    super.key,
    required this.options,
    required super.child,
  });

  final StoriesV3Options options;

  /// Режим над [context] с подпиской на смену; `null` — его нет.
  static StoriesV3Options? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoriesV3Scope>()?.options;

  /// Режим над [context] без подписки — вне сборки (`show`).
  static StoriesV3Options? peek(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoriesV3Scope>()?.options;

  @override
  bool updateShouldNotify(StoriesV3Scope oldWidget) =>
      options != oldWidget.options;
}
