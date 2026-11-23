part of 'personalization_stories.dart';

/// Сторис V2 поверх API v3 для поддерева: блоки [PersonalizationStories] под ним,
/// [PersonalizationStories.show] с контекстом под ним и просмотры
/// [PersonalizationStoryViewer] под ним.
///
/// Не публичный API: только шлюз v3 (`src/v3/personalization_v3.dart`).
///
/// API v3 — свой хост ([ownApiV3Domain], параметр `apiV3Domain`), без него глобальный
/// [apiV3Domain]: лента, кампания по ссылке и события — на v3, у слайдов со ссылкой кнопка
/// «Поделиться», ссылки открывает [handleLink]. Пустой свой хост — старый API и при
/// заданном глобальном. Действует ближайший над блоком [PersonalizationStoriesV3]; два
/// блока на одном экране независимы: один может идти в старый API, другой — в v3.
/// Сменился хост — блок грузится заново. Открыт один просмотр V2 из блока, `show` или
/// [handleLink]: ссылка закрывает прежний перед показом своего.
///
/// Сторис с API v3 ведут себя, как в веб-SDK: открываются со слайда `start_position`
/// сервера (за сессию — где остановились), просмотренной сторис становится по `viewed`
/// сервера или когда с неё ушли вперёд; слайд не фото, не видео и без товара
/// пропускается, сторис из таких слайдов остаётся в ленте, а открыть её — досмотреть:
/// она просмотрена и открывается следующая; медиа решает тип слайда, слайд без медиа — цвета
/// `background_color`; шапка `header` рисуется, её нажатие — `click` и её ссылка; кнопка
/// без ссылки — только `click`; копирование промокода `click` не шлёт; кнопка звука —
/// только у видео со звуком, выбор звука помнится на устройстве; «Поделиться» отдаёт
/// ссылку слайда, без неё — ссылку кампании как есть.
///
/// Опросы слайдов — тоже только с API v3: ответы уходят на хост блока, а
/// [pollsTransport] их подменяет (тесты, офлайн-демо). Просмотр под
/// [PersonalizationStoriesV3] со своим [pollsTransport] рисует опросы и без API v3. Ответ
/// хранится на устройстве по `did` 90 дней, как в вебе; ответ из ленты важнее него.
///
/// ```dart
/// PersonalizationStoriesV3(
///   apiV3Domain: 'app.rees46.ru',
///   shareUrlTransform: (url) => url.replaceFirst('https://', 'myapp://'),
///   child: PersonalizationStories(code: code),
/// )
/// ```
class PersonalizationStoriesV3 extends StatelessWidget {
  const PersonalizationStoriesV3({
    super.key,
    String? apiV3Domain,
    this.shareLabel = 'Share',
    this.shareUrlTransform,
    this.pollsTransport,
    this.pollReanswerText,
    this.pollSubmitText,
    this.pollErrorText,
    required this.child,
  }) : ownApiV3Domain = apiV3Domain;

  /// Свой хост API v3 без схемы (параметр `apiV3Domain`, например `app.rees46.ru`): лента,
  /// события и кнопка «Поделиться» поддерева. `null` — глобальный [apiV3Domain]; пустая
  /// строка — старый API и при заданном глобальном.
  final String? ownApiV3Domain;

  /// Подпись «Поделиться» для скринридера.
  final String shareLabel;

  /// Что сделать со ссылкой слайда перед системным окном «Поделиться», например сменить
  /// `https://` на схему приложения; `null` — ссылка как есть. Событие `share` не меняется.
  final String Function(String url)? shareUrlTransform;

  /// Куда отправлять ответы опросов слайдов; `null` — HTTP API v3 хоста. Блоку без API v3
  /// опросов нет и с ним.
  final StoryPollsTransport? pollsTransport;

  /// Тексты карточки опроса: ссылка «Ответить заново», кнопка отправки без своей подписи
  /// опроса (и кнопка комментария к оценке шкалы) и ошибка отправки. Непустые `labels`
  /// опроса от сервера важнее; `null` или пусто — встроенные по языку устройства
  /// (русские или английские).
  final String? pollReanswerText;
  final String? pollSubmitText;
  final String? pollErrorText;

  /// Поддерево в режиме v3.
  final Widget child;

  /// Глобальный хост API v3 сторис V2 без схемы, как `REES46Config.apiDomain`, например
  /// `app.rees46.ru`, — для блоков, `show` и [handleLink] без своего хоста. `null` (по
  /// умолчанию) — у них всё по-старому: лента `stories/{code}` и трекинг `track/stories`
  /// через нативный SDK. Задан — их запросы V2 идут на `https://{apiV3Domain}`: лента и
  /// события из Dart, у слайдов со ссылкой — кнопка «Поделиться», [handleLink] открывает
  /// ссылки.
  static String? get apiV3Domain => StoriesApiV3.domain;
  static set apiV3Domain(String? value) => StoriesApiV3.domain = value;

  @override
  Widget build(BuildContext context) => StoriesV3Scope(
    options: StoriesV3Options(
      apiV3Domain: ownApiV3Domain,
      shareLabel: shareLabel,
      shareUrlTransform: shareUrlTransform,
      pollsTransport: pollsTransport,
      pollTexts: StoryPollTexts(
        reanswer: pollReanswerText ?? '',
        error: pollErrorText ?? '',
        submit: pollSubmitText ?? '',
      ),
    ),
    child: child,
  );

  /// Открыть сторис по ссылке «Поделиться» [url]:
  /// `https://<сайт>/<путь>?r46_stories=<code>&r46_story=<id>[&r46_slide=<id>]`.
  ///
  /// `false` — не ссылка сторис или API v3 выключен (нет ни `apiV3Domain`, ни
  /// глобального [apiV3Domain]): ничего не делает. `true` — дальше асинхронно: дождаться
  /// SDK (как [PersonalizationStories.show]), загрузить кампанию ссылки (`/story/{id}`
  /// API v3), закрыть открытый просмотр V2 и открыть свой — с первой сторис ответа.
  /// Слайд ссылки (`r46_slide`), если он есть в ответе, иначе `start_position`, — только
  /// слайд её первого открытия: дальше она открывается, как любая сторис API v3, — где
  /// остановились; показать с него нечего — она досмотрена и открывается следующая, а
  /// пустой просмотр не открывается. Один раз — событие `shared_open` со слайдом, с
  /// которого её открыли (досмотрена сразу — с первым). Ошибка, 404, пустой ответ или
  /// дольше 15 с — [onError], ничего не показывается, событий нет. Та же ссылка, пока
  /// прежняя грузится или её просмотр открыт, — ничего, но `true`. Тексты, колбэки и
  /// [controller] — как у [PersonalizationStories.show], остальное — как у
  /// [PersonalizationStoriesV3].
  static bool handleLink(
    BuildContext context,
    String url, {
    PersonalizationSdk? sdk,
    String? shopId,
    PersonalizationStoriesController? controller,
    ValueChanged<String>? onLinkClick,
    ValueChanged<StoryProduct>? onProductClick,
    ValueChanged<String>? onPromoCopied,
    ValueChanged<Object>? onError,
    String promoCopiedText = 'Copied',
    String promoCaption = 'Promo code',
    String productButtonText = 'More info',
    String showProductsText = 'Used products',
    String hideProductsText = 'Hide products',
    String retryText = 'Retry',
    String closeLabel = 'Close',
    String shareLabel = 'Share',
    String soundOnLabel = 'Sound on',
    String soundOffLabel = 'Sound off',
    PersonalizationStoryImageProvider? imageProvider,
    Widget Function(
      BuildContext context,
      String asset,
      double size,
      Color color,
    )?
    iconBuilder,
    String Function(String url)? shareUrlTransform,
    StoryPollsTransport? pollsTransport,
    String? pollReanswerText,
    String? pollSubmitText,
    String? pollErrorText,
    String? apiV3Domain,
  }) {
    final link = parseStoriesShareLink(url);
    if (link == null) return false;
    // Хост — сейчас: дальше ссылка идёт на него, даже если глобальный поменяют.
    final host = StoriesApiV3.host(apiV3Domain);
    if (host == null) {
      debugPrint('PersonalizationStoriesV3.handleLink: links need apiV3Domain');
      return false;
    }
    if (_linkBusy(link.key)) return true;
    _openLinks[link.key] = null;
    // Носитель текстов и колбэков для просмотра, как у show; в дерево не вставляется.
    final config = PersonalizationStories(
      code: link.code,
      onLinkClick: onLinkClick,
      onProductClick: onProductClick,
      onPromoCopied: onPromoCopied,
      promoCopiedText: promoCopiedText,
      promoCaption: promoCaption,
      productButtonText: productButtonText,
      showProductsText: showProductsText,
      hideProductsText: hideProductsText,
      retryText: retryText,
      closeLabel: closeLabel,
      soundOnLabel: soundOnLabel,
      soundOffLabel: soundOffLabel,
      imageProvider: imageProvider,
      iconBuilder: iconBuilder,
    );
    final v3 = StoriesV3Options(
      apiV3Domain: host,
      shareLabel: shareLabel,
      shareUrlTransform: shareUrlTransform,
      pollsTransport: pollsTransport,
      pollTexts: StoryPollTexts(
        reanswer: pollReanswerText ?? '',
        error: pollErrorText ?? '',
        submit: pollSubmitText ?? '',
      ),
    );
    unawaited(
      _openLink(
        context,
        link,
        config: config,
        v3: v3,
        sdk: sdk,
        shopId: shopId,
        controller: controller,
        onError: onError,
      ).whenComplete(() => _openLinks.remove(link.key)),
    );
    return true;
  }
}
