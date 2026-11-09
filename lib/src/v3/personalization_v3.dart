/// Шлюз v3: попапы нового конструктора и сторис на API v3.
///
/// v3 — не публичный API. Код живёт в пакете и работает в наших демо, но интеграторам
/// он недоступен: `package:rees46_sdk/rees46_sdk.dart` и кит в нём его не экспортируют.
/// Шлюз снимается, только когда v3 станет публичным.
///
/// Демо берёт v3 прямым импортом; анализатор помечает его как implementation import, и
/// это ожидаемо:
///
/// ```dart
/// // ignore: implementation_imports
/// import 'package:rees46_sdk/src/v3/personalization_v3.dart';
/// ```
///
/// v3 спит, пока хост не прошёл через этот шлюз: движок попапов выключен, пока его не
/// включат через `sdk.popups`, а сторис ходят в старый API, пока над ними нет
/// `PersonalizationStoriesV3` и не задан его глобальный `apiV3Domain`.
library;

// Попапы нового конструктора (документ design): `sdk.popups` — включение, экраны,
// ручной показ, — и наблюдатель экранов навигатора. Движок и рендер — внутренности.
export '../popups_v3/popups_v3.dart';
export '../ui/popups_v3/personalization_screen_observer.dart';

// Сторис V2 на API v3: хост (свой и глобальный), «Поделиться», ссылки и опросы.
export '../ui/widgets/personalization_stories.dart'
    show PersonalizationStoriesV3;
export '../stories/stories_response.dart'
    show
        StoryShareV3,
        StorySlideShareV3,
        StoryPollType,
        StoryMiniPollKind,
        StoryPollOption,
        StoryPollBand,
        StoryPollAnswer,
        StoryPollResults,
        StoryPollLabels,
        StoryPollElement;
// Опросы слайдов: шов транспорта ответов (тесты, офлайн-демо). Карточка и её логика —
// внутренности просмотра.
export '../ui/widgets/stories_polls_api.dart'
    show StoryPollsTransport, StoryPollReply;
