import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../multi_instance/rees46.dart';
import '../../multi_instance/sdk_exceptions.dart';
import '../../personalization_sdk.dart';
import '../../stories/stories_response.dart';
import '../components/personalization_stories_bar.dart';
import 'personalization_story_viewer.dart';
import 'stories_api_v3.dart';
import 'stories_playback.dart';
import 'stories_seen_store.dart';
import 'stories_share.dart';
import 'stories_support.dart';

/// Программное управление блоком сторис: открыть сторис, пауза, продолжение, перезагрузка.
///
/// Передаётся в [PersonalizationStories.controller] или в [PersonalizationStories.show].
/// - [open] и [openStory] до загрузки блока ждут её и открывают сторис после; при уже
///   открытом просмотре листают на эту сторис внутри него. Future завершается, когда
///   просмотр закроют.
/// - [pause] и [resume] действуют только на открытый просмотр, без него ничего не
///   делают; при закрытии просмотра пауза снимается.
class PersonalizationStoriesController {
  _PersonalizationStoriesState? _bar;
  final ValueNotifier<bool> _paused = ValueNotifier<bool>(false);

  /// Открытый просмотр; `null` — закрыт.
  _StoriesSession? _session;

  /// Открытие, которое ждёт загрузки блока.
  _QueuedOpen? _queued;

  /// Открыть сторис номер [index] ленты — со стартового слайда по общим правилам. Блок
  /// ещё грузится — откроется после загрузки (новая просьба заменяет прежнюю); просмотр
  /// уже открыт — перелистнёт в нём. Нет такой сторис — ничего.
  Future<void> open(int index) => _request(index: index);

  /// Открыть сторис с id [storyId] — как [open]; нет такой — ничего.
  Future<void> openStory(String storyId) => _request(storyId: storyId);

  /// Остановить открытый просмотр; без него — ничего.
  void pause() {
    if (_session != null) _paused.value = true;
  }

  /// Продолжить после [pause]; без открытого просмотра — ничего.
  void resume() {
    if (_session != null) _paused.value = false;
  }

  /// Заново загрузить блок.
  Future<void> reload() => _bar?._load() ?? Future<void>.value();

  Future<void> _request({int? index, String? storyId}) {
    final session = _session;
    if (session != null) return session.turn(index: index, storyId: storyId);
    final bar = _bar;
    if (bar != null && !bar._loading) {
      return bar._openStory(index: index, storyId: storyId);
    }
    final previous = _queued;
    final queued = _queued = _QueuedOpen(index, storyId);
    previous?.done.complete();
    return queued.done.future;
  }

  /// Блок загрузился или не загрузился: отложенное открытие — сейчас.
  void _flush() {
    final queued = _queued;
    if (queued == null) return;
    _queued = null;
    queued.done.complete(
      _request(index: queued.index, storyId: queued.storyId),
    );
  }

  /// Блок ушёл из дерева: отложенное открытие не случится.
  void _drop() {
    final queued = _queued;
    _queued = null;
    queued?.done.complete();
  }

  _StoriesSession _begin(List<Story> stories) =>
      _session = _StoriesSession(stories);

  void _end(_StoriesSession session) {
    session.end();
    if (_session != session) return;
    _session = null;
    _paused.value = false;
  }
}

/// Открытие сторис, которое ждёт загрузки блока.
class _QueuedOpen {
  _QueuedOpen(this.index, this.storyId);

  final int? index;
  final String? storyId;
  final Completer<void> done = Completer<void>();
}

/// Открытый просмотр: его сторис, просьбы перелистнуть и конец.
class _StoriesSession {
  _StoriesSession(this.stories);

  final List<Story> stories;

  /// Индексы сторис, на которые перелистнуть. Не broadcast: просьба до первой сборки
  /// просмотра ждёт его подписки.
  final StreamController<int> turns = StreamController<int>();
  final Completer<void> _closed = Completer<void>();

  /// Перелистнуть на сторис [index] или с id [storyId]; нет такой — ничего. Завершается,
  /// когда просмотр закроют.
  Future<void> turn({int? index, String? storyId}) {
    final target = storyId != null
        ? stories.indexWhere((story) => story.id == storyId)
        : index ?? -1;
    if (target < 0 || target >= stories.length || turns.isClosed) {
      return Future<void>.value();
    }
    turns.add(target);
    return _closed.future;
  }

  void end() {
    unawaited(turns.close());
    if (!_closed.isCompleted) _closed.complete();
  }
}

/// Блок сторис с данными SDK: лента превью, по нажатию — полноэкранный просмотр.
///
/// Паттерн «Блок сторис на странице» из Figma (страница Stories, 1:32), источник —
/// `stories/{code}`. Визуальный слой — [PersonalizationStoriesBar] и
/// [PersonalizationStoryViewer]. Без ленты сторис показывает [show].
///
/// Инстанс SDK: [sdk] явно, иначе [shopId] выбирает магазин при нескольких
/// зарегистрированных; без него берётся единственный (`REES46.getInstance`). Магазин ещё
/// не зарегистрирован — виджет ждёт регистрации до 15 с ([registrationTimeout]).
///
/// Пока блок грузится, в ленте заглушки. Пустой блок — виджет исчезает. Ошибка загрузки,
/// пустой [code], магазин не зарегистрирован за 15 с или неоднозначен, загрузка дольше
/// 15 с — виджет исчезает и зовёт [onError]; вечных заглушек нет. Сторис без слайдов
/// выпадают.
///
/// Просмотренные слайды хранятся на устройстве по магазину и переживают перезапуск:
/// сторис просмотрена, когда так говорит сервер или просмотрены все её слайды; дуги
/// кольца горят по просмотренным слайдам; сторис открывается с первого
/// непросмотренного. Тексты и колбэки уходят в просмотр как есть.
///
/// API v3 — свой хост блока (параметр `apiV3Domain`, [ownApiV3Domain]), без него
/// глобальный [apiV3Domain]: лента, кампания по ссылке и события — на v3, у слайдов кнопка
/// «Поделиться», ссылки открывает [handleLink]. Два блока на одном экране независимы:
/// один может идти в старый API, другой — в v3. Открыт один просмотр V2 из виджета,
/// [show] или [handleLink]: ссылка закрывает прежний перед показом своего.
class PersonalizationStories extends StatefulWidget {
  const PersonalizationStories({
    super.key,
    required this.code,
    this.sdk,
    this.shopId,
    this.controller,
    this.onLinkClick,
    this.onProductClick,
    this.onPromoCopied,
    this.onError,
    this.promoCopiedText = 'Copied',
    this.promoCaption = 'Promo code',
    this.productButtonText = 'More info',
    this.showProductsText = 'Used products',
    this.hideProductsText = 'Hide products',
    this.retryText = 'Retry',
    this.closeLabel = 'Close',
    this.shareLabel = 'Share',
    this.soundOnLabel = 'Sound on',
    this.soundOffLabel = 'Sound off',
    this.padding = const EdgeInsets.all(16),
    this.imageProvider,
    this.iconBuilder,
    this.shareUrlTransform,
    String? apiV3Domain,
  }) : ownApiV3Domain = apiV3Domain;

  /// Код блока сторис.
  final String code;

  /// Свой хост API v3 блока без схемы (параметр `apiV3Domain`, например `app.rees46.ru`):
  /// лента, события и кнопка «Поделиться» его просмотра. `null` — глобальный
  /// [apiV3Domain]; пустая строка — старый API и при заданном глобальном.
  final String? ownApiV3Domain;

  /// Явный инстанс; иначе резолв по [shopId].
  final PersonalizationSdk? sdk;

  /// Магазин при нескольких зарегистрированных; без него — единственный.
  final String? shopId;

  /// Программное управление; см. [PersonalizationStoriesController].
  final PersonalizationStoriesController? controller;

  /// См. [PersonalizationStoryViewer.onLinkClick].
  final ValueChanged<String>? onLinkClick;

  /// См. [PersonalizationStoryViewer.onProductClick].
  final ValueChanged<StoryProduct>? onProductClick;
  final ValueChanged<String>? onPromoCopied;
  final ValueChanged<Object>? onError;

  /// Тексты просмотра — см. одноимённые у [PersonalizationStoryViewer].
  final String promoCopiedText;
  final String promoCaption;
  final String productButtonText;
  final String showProductsText;
  final String hideProductsText;
  final String retryText;
  final String closeLabel;
  final String shareLabel;
  final String soundOnLabel;
  final String soundOffLabel;

  /// Поля ленты.
  final EdgeInsetsGeometry padding;

  /// Картинка по адресу; не задан — загрузчик SDK ([PersonalizationStoryImageProvider]).
  final PersonalizationStoryImageProvider? imageProvider;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  /// Глобальный хост API v3 сторис V2 без схемы, как `REES46Config.apiDomain`, например
  /// `app.rees46.ru`, — для блоков, [show] и [handleLink] без своего `apiV3Domain`.
  /// `null` (по умолчанию) — у них всё по-старому: лента `stories/{code}` и трекинг
  /// `track/stories` через нативный SDK. Задан — их запросы V2 идут на
  /// `https://{apiV3Domain}`: лента и события из Dart, у слайдов со ссылкой — кнопка
  /// «Поделиться», [handleLink] открывает ссылки.
  static String? get apiV3Domain => StoriesApiV3.domain;
  static set apiV3Domain(String? value) => StoriesApiV3.domain = value;

  /// Что сделать со ссылкой слайда перед системным окном «Поделиться», например сменить
  /// `https://` на схему приложения; `null` — ссылка как есть. Событие `share` не меняется.
  final String Function(String url)? shareUrlTransform;

  /// Сколько ждать блок, прежде чем сдаться и позвать [onError].
  static const Duration loadTimeout = Duration(seconds: 15);

  /// Сколько ждать регистрации SDK (`REES46.initialize` / `registerShops`), когда
  /// инстанс не передан явно, прежде чем сдаться и позвать [onError].
  static const Duration registrationTimeout = Duration(seconds: 15);

  /// Показать сторис блока [code] без ленты: загрузить блок и открыть просмотр — со
  /// сторис [startStoryId] (нет такой — с первой). Тексты, колбэки, [controller],
  /// `shareUrlTransform` и `apiV3Domain` — как у виджета. Ошибка (пустой код, магазин не зарегистрирован за 15 с или неоднозначен,
  /// загрузка не удалась или дольше 15 с, в блоке нет сторис) уходит в [onError],
  /// просмотр не открывается, Future завершается. Иначе Future завершается, когда
  /// просмотр закроют.
  static Future<void> show(
    BuildContext context, {
    required String code,
    PersonalizationSdk? sdk,
    String? shopId,
    String? startStoryId,
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
    String? apiV3Domain,
  }) async {
    // Носитель текстов и колбэков для просмотра; в дерево не вставляется.
    final config = PersonalizationStories(
      code: code,
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
      shareLabel: shareLabel,
      soundOnLabel: soundOnLabel,
      soundOffLabel: soundOffLabel,
      imageProvider: imageProvider,
      iconBuilder: iconBuilder,
      shareUrlTransform: shareUrlTransform,
      apiV3Domain: apiV3Domain,
    );
    final PersonalizationSdk resolved;
    final List<Story> stories;
    try {
      resolved = await _resolve(sdk, shopId);
      stories = await _fetch(resolved, code, apiV3Domain: apiV3Domain);
      if (stories.isEmpty) {
        throw StateError('stories block "$code" has no stories');
      }
    } catch (error) {
      debugPrint('PersonalizationStories.show: $code — $error');
      onError?.call(error);
      return;
    }
    if (!context.mounted) return;
    final index = stories.indexWhere((story) => story.id == startStoryId);
    await _present(
      context,
      config: config,
      sdk: resolved,
      stories: stories,
      index: index < 0 ? 0 : index,
      controller: controller,
    );
  }

  /// Открыть сторис по ссылке «Поделиться» [url]:
  /// `https://<сайт>/<путь>?r46_stories=<code>&r46_story=<id>[&r46_slide=<id>]`.
  ///
  /// `false` — не ссылка сторис или API v3 выключен (нет ни `apiV3Domain`, ни
  /// глобального [apiV3Domain]): ничего не делает. `true` —
  /// дальше асинхронно: дождаться SDK (как [show]), загрузить кампанию ссылки
  /// (`/story/{id}` API v3), закрыть открытый просмотр V2 и открыть свой — с первой
  /// сторис ответа, со слайда `start_position` (в обход правила «первый
  /// непросмотренный»). После показа один раз — событие `shared_open`. Ошибка, 404,
  /// пустой ответ или дольше 15 с — [onError], ничего не показывается, событий нет. Та
  /// же ссылка, пока прежняя грузится или её просмотр открыт, — ничего, но `true`.
  /// Остальное — как у [show].
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
    String? apiV3Domain,
  }) {
    final link = parseStoriesShareLink(url);
    if (link == null) return false;
    // Хост — сейчас: дальше ссылка идёт на него, даже если глобальный поменяют.
    final host = StoriesApiV3.host(apiV3Domain);
    if (host == null) {
      debugPrint('PersonalizationStories.handleLink: links need apiV3Domain');
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
      shareLabel: shareLabel,
      soundOnLabel: soundOnLabel,
      soundOffLabel: soundOffLabel,
      imageProvider: imageProvider,
      iconBuilder: iconBuilder,
      shareUrlTransform: shareUrlTransform,
      apiV3Domain: host,
    );
    unawaited(
      _openLink(
        context,
        link,
        config: config,
        sdk: sdk,
        shopId: shopId,
        controller: controller,
        onError: onError,
      ).whenComplete(() => _openLinks.remove(link.key)),
    );
    return true;
  }

  @override
  State<PersonalizationStories> createState() => _PersonalizationStoriesState();
}

/// Ссылки [PersonalizationStories.handleLink], которые грузятся (`null`) или открыты
/// (маршрут просмотра): повтор той же ссылки в это время ничего не делает.
final Map<String, Route<void>?> _openLinks = <String, Route<void>?>{};

/// Ссылка [key] грузится или её просмотр открыт. Маршрут, который ушёл без закрытия
/// (навигатор убран вместе с ним), ссылку не держит.
bool _linkBusy(String key) {
  if (!_openLinks.containsKey(key)) return false;
  final route = _openLinks[key];
  return route == null || route.isActive;
}

/// Открытый просмотр V2 — виджета, `show` или `handleLink`; `null` — нет.
Route<void>? _openViewer;

/// Закрыть открытый просмотр V2, если он есть: сверху — обычным закрытием, под другим
/// экраном — сразу.
void _closeOpenViewer() {
  final route = _openViewer;
  _openViewer = null;
  final navigator = route?.navigator;
  if (route == null || navigator == null || !route.isActive) return;
  if (route.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(route);
  }
}

/// Загрузить кампанию ссылки [link] и открыть её вместо открытого просмотра V2.
/// Завершается, когда просмотр закроют или загрузка не удалась.
Future<void> _openLink(
  BuildContext context,
  StoriesShareLink link, {
  required PersonalizationStories config,
  PersonalizationSdk? sdk,
  String? shopId,
  PersonalizationStoriesController? controller,
  ValueChanged<Object>? onError,
}) async {
  final PersonalizationSdk resolved;
  final List<Story> stories;
  try {
    resolved = await _resolve(sdk, shopId);
    stories = await _fetch(
      resolved,
      link.code,
      link: link,
      apiV3Domain: config.ownApiV3Domain,
    );
    if (stories.isEmpty) {
      throw StateError('stories link ${link.key} has no stories');
    }
  } catch (error) {
    debugPrint('PersonalizationStories.handleLink: ${link.key} — $error');
    onError?.call(error);
    return;
  }
  if (!context.mounted) return;
  final story = stories.first;
  final start = story.startPosition.clamp(0, story.slides.length - 1);
  var opened = false;
  _closeOpenViewer();
  await _present(
    context,
    config: config,
    sdk: resolved,
    stories: stories,
    index: 0,
    initialSlide: start,
    controller: controller,
    onRoute: (route) => _openLinks[link.key] = route,
    onSlideShown: (_, _) {
      // `shared_open` — один раз, после показа: кампания и слайд ссылки.
      if (opened) return;
      opened = true;
      unawaited(
        StoriesApiV3.track(
          resolved,
          config.ownApiV3Domain!,
          code: link.code,
          event: StoriesV3Event.sharedOpen,
          storyId: story.id,
          slideId: story.slides[start].id,
        ),
      );
    },
  );
}

/// Открыть просмотр [stories] со сторис [index] поверх корневого навигатора; тексты и
/// колбэки — из [config]. Пока просмотр открыт, [controller] ставит его на паузу и
/// листает. Завершается, когда просмотр закроют.
Future<void> _present(
  BuildContext context, {
  required PersonalizationStories config,
  required PersonalizationSdk? sdk,
  required List<Story> stories,
  required int index,
  int? initialSlide,
  PersonalizationStoriesController? controller,
  void Function(Story story, int slideIndex)? onSlideShown,
  ValueChanged<Route<void>>? onRoute,
}) async {
  final session = controller?._begin(stories);
  final viewer = PersonalizationStoryViewer(
    stories: stories,
    initialStory: index,
    initialSlide: initialSlide,
    seen: sdk == null
        ? const <String, Set<String>>{}
        : StoriesSeenStore.instance.seen(sdk),
    code: config.code,
    sdk: sdk,
    paused: controller?._paused,
    storyRequests: session?.turns.stream,
    onSlideShown: onSlideShown,
    onLinkClick: config.onLinkClick,
    onProductClick: config.onProductClick,
    onPromoCopied: config.onPromoCopied,
    productButtonText: config.productButtonText,
    promoCaption: config.promoCaption,
    promoCopiedText: config.promoCopiedText,
    showProductsText: config.showProductsText,
    hideProductsText: config.hideProductsText,
    retryText: config.retryText,
    closeLabel: config.closeLabel,
    shareLabel: config.shareLabel,
    soundOnLabel: config.soundOnLabel,
    soundOffLabel: config.soundOffLabel,
    imageProvider: config.imageProvider,
    iconBuilder: config.iconBuilder,
    shareUrlTransform: config.shareUrlTransform,
    apiV3Domain: config.ownApiV3Domain,
  );
  final navigator = Navigator.of(context, rootNavigator: true);
  // Тема едет с просмотром: хост мог задать её поддереву, а не приложению.
  final route = PersonalizationStoryViewer.route(
    InheritedTheme.capture(from: context, to: navigator.context).wrap(viewer),
  );
  _openViewer = route;
  onRoute?.call(route);
  try {
    await navigator.push(route);
  } finally {
    if (_openViewer == route) _openViewer = null;
    if (session != null) controller?._end(session);
  }
}

/// SDK по [sdk] или [shopId]. Магазин ещё не зарегистрирован — ждём регистрации до
/// [PersonalizationStories.registrationTimeout], проверяя раз в 100 мс; не дождались —
/// [UnknownShopIdException]. Неоднозначный выбор ([AmbiguousShopException]) — сразу.
/// [alive] вернул `false` — ждать больше незачем, та же ошибка.
Future<PersonalizationSdk> _resolve(
  PersonalizationSdk? sdk,
  String? shopId, {
  bool Function()? alive,
}) async {
  if (sdk != null) return sdk;
  const poll = Duration(milliseconds: 100);
  for (var waited = Duration.zero; ; waited += poll) {
    try {
      return REES46.getInstance(shopId);
    } on UnknownShopIdException {
      final waiting = alive?.call() ?? true;
      if (!waiting || waited >= PersonalizationStories.registrationTimeout) {
        rethrow;
      }
    }
    await Future<void>.delayed(poll);
  }
}

/// Блок [code] со сторис, у которых есть слайды, и просмотренное магазина — не дольше
/// [PersonalizationStories.loadTimeout]. С хостом API v3 ([apiV3Domain], без него —
/// глобальный) — лента v3, а с [link] — кампания ссылки; без хоста — лента через мост.
Future<List<Story>> _fetch(
  PersonalizationSdk sdk,
  String code, {
  StoriesShareLink? link,
  String? apiV3Domain,
}) async {
  if (code.isEmpty) {
    throw ArgumentError.value(code, 'code', 'must be non-empty');
  }
  final host = StoriesApiV3.host(apiV3Domain);
  final Future<StoriesBlock> request;
  if (host != null && link != null) {
    request = StoriesApiV3.story(sdk, host, link);
  } else if (link != null) {
    throw StateError('stories links need API v3');
  } else if (host != null) {
    request = StoriesApiV3.feed(sdk, host, code);
  } else {
    request = sdk.getStories(code);
  }
  // Просмотренное читается вместе с блоком; ошибка блока приходит как есть.
  final results = await Future.wait<Object>(<Future<Object>>[
    request,
    StoriesSeenStore.instance.load(sdk),
  ]).timeout(PersonalizationStories.loadTimeout);
  final block = results.first as StoriesBlock;
  return playableStories(block.stories);
}

class _PersonalizationStoriesState extends State<PersonalizationStories> {
  PersonalizationSdk? _sdk;
  List<Story> _stories = const <Story>[];
  bool _loading = true;
  int _seq = 0;
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._bar = this;
    _load();
  }

  @override
  void didUpdateWidget(PersonalizationStories oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    if (controllerChanged) {
      if (oldWidget.controller?._bar == this) oldWidget.controller?._bar = null;
      widget.controller?._bar = this;
    }
    if (oldWidget.sdk != widget.sdk ||
        oldWidget.shopId != widget.shopId ||
        oldWidget.code != widget.code ||
        oldWidget.ownApiV3Domain != widget.ownApiV3Domain) {
      _load();
    } else if (controllerChanged) {
      // Новый контроллер мог ждать загрузки, а блок уже загружен. После кадра: открытие
      // просмотра посреди сборки запрещено.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loading) widget.controller?._flush();
      });
    }
  }

  @override
  void dispose() {
    final controller = widget.controller;
    if (controller?._bar == this) {
      controller?._bar = null;
      controller?._drop();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() => _loading = true);
    try {
      final sdk = await _resolve(
        widget.sdk,
        widget.shopId,
        alive: () => mounted && seq == _seq,
      );
      final stories = await _fetch(
        sdk,
        widget.code,
        apiV3Domain: widget.ownApiV3Domain,
      );
      if (!mounted || seq != _seq) return;
      setState(() {
        _sdk = sdk;
        _loading = false;
        _stories = stories;
      });
      widget.controller?._flush();
    } catch (error) {
      if (!mounted || seq != _seq) return;
      debugPrint('PersonalizationStories: ${widget.code} — $error');
      setState(() {
        _loading = false;
        _stories = const <Story>[];
      });
      widget.controller?._flush();
      // После кадра: ошибка бывает и до первой сборки, а хост в ответ может, например,
      // показать снекбар — посреди сборки это запрещено.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onError?.call(error);
      });
    }
  }

  /// Открыть сторис номер [index] или с id [storyId]; нет такой — ничего.
  Future<void> _openStory({int? index, String? storyId}) => _open(
    storyId != null
        ? _stories.indexWhere((story) => story.id == storyId)
        : index ?? -1,
  );

  Future<void> _open(int index) async {
    final sdk = _sdk;
    if (_presenting || index < 0 || index >= _stories.length) return;
    _presenting = true;
    try {
      await _present(
        context,
        config: widget,
        sdk: sdk,
        stories: _stories,
        index: index,
        controller: widget.controller,
        onSlideShown: (_, _) {
          if (mounted) setState(() {});
        },
      );
    } finally {
      _presenting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return PersonalizationStoriesBar(loading: true, padding: widget.padding);
    }
    final stories = _stories;
    final sdk = _sdk;
    if (stories.isEmpty || sdk == null) return const SizedBox.shrink();
    final seen = StoriesSeenStore.instance.seen(sdk);
    return PersonalizationStoriesBar(
      padding: widget.padding,
      items: <PersonalizationStoryItem>[
        for (final story in stories)
          _item(story, seen[story.id] ?? const <String>{}),
      ],
      onItemTap: (item) =>
          _open(stories.indexWhere((story) => story.id == item.id)),
      iconBuilder: widget.iconBuilder,
    );
  }

  PersonalizationStoryItem _item(Story story, Set<String> seen) =>
      PersonalizationStoryItem(
        id: story.id,
        label: story.name,
        image: storyImage(story.avatar, widget.imageProvider),
        pinned: story.pinned,
        viewed: StoriesPlayback.isViewed(story, seen),
        segments: story.slides.length,
        seenSegments: <int>{
          for (var i = 0; i < story.slides.length; i++)
            if (seen.contains(story.slides[i].id)) i,
        },
      );
}
