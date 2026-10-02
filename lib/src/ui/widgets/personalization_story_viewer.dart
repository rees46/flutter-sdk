import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../../personalization_sdk.dart';
import '../../stories/stories_response.dart';
import '../components/personalization_toast.dart';
import 'stories_media_cache.dart';
import 'stories_playback.dart';
import 'stories_seen_store.dart';
import 'stories_slide_view.dart';
import 'stories_sound.dart';
import 'stories_support.dart';

/// Полноэкранный просмотр сторис: слайды по таймеру, листание, товары, ссылки.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), фреймы Card/Story
/// (Product, Promo, Discount, Action, Slide, Text) 402×874. Как рисуется слайд — см.
/// [StorySlideView]; логика без UI — [StoriesPlayback].
///
/// Поведение (общие правила всех платформ):
/// - касание левой трети — назад, правой — вперёд, середина ничего не делает; в RTL края
///   меняются местами. Удержание от 200 мс — пауза, отпускание её снимает и никуда не
///   листает. Назад на первом слайде первой сторис перезапускает слайд, вперёд на
///   последнем слайде последней — закрывает просмотр;
/// - свайп вбок листает сторис; заход на сторис (просмотр слайда, трекинг `view`) — только
///   когда страница осела, подглядывание соседней не считается. Свайп вниз дальше 120 или
///   быстрее 800 в секунду закрывает, иначе слайд пружинит назад; пока тянут — пауза;
/// - раскрытая шторка товаров ставит паузу и блокирует листание; тап мимо неё и системное
///   «назад» её закрывают; смена слайда её сбрасывает;
/// - пауза и когда приложение свёрнуто или потеряло фокус, и когда просмотр закрыт другим
///   экраном, и по [paused] от хоста; время слайда в паузе не идёт;
/// - часы слайда стартуют, когда медиа готово; не загрузилось или не успело за 10 с — пауза
///   и кнопка [retryText]; видео ещё и само повторяет загрузку через 15 с;
/// - видео длится по своей реальной длине, прогресс идёт за воспроизведением и стоит на
///   подгрузке; видео не ждёт загрузки целиком: играет по сети, пока кэш на диске
///   ([StoriesMediaCache]) заполняется в фоне, и из файла в следующий раз; следующий слайд
///   подгружается заранее. Звук выключен при первом открытии, выбор помнится до конца
///   процесса, кнопка громкости «вверх» включает звук ([StoriesSound]).
///
/// Трекинг через [sdk] с кодом [code]: `view` — на каждый слайд, ставший текущим на
/// осевшей странице; `click` — кнопка, товар, карусель, копирование промокода. Id, которые
/// не целые положительные числа (`39_0`), не трекаются. Просмотренные слайды с [sdk]
/// запоминаются на устройстве по магазину ([StoriesSeenStore]); хосту о показе слайда
/// сообщает [onSlideShown].
///
/// Кнопки, товары и карусель сначала закрывают просмотр, потом зовут [onLinkClick] /
/// [onProductClick]; не заданы — ссылку открывает система через SDK.
///
/// Открывается маршрутом [route] или встраивается как обычный виджет с [onClose].
class PersonalizationStoryViewer extends StatefulWidget {
  const PersonalizationStoryViewer({
    super.key,
    required this.stories,
    this.initialStory = 0,
    this.seen = const <String, Set<String>>{},
    this.code,
    this.sdk,
    this.paused,
    this.onSlideShown,
    this.onClose,
    this.onLinkClick,
    this.onProductClick,
    this.onPromoCopied,
    this.productButtonText = 'More info',
    this.promoCaption = 'Promo code',
    this.promoCopiedText = 'Copied',
    this.promoToastPosition = PersonalizationToastPosition.top,
    this.showProductsText = 'Used products',
    this.hideProductsText = 'Hide products',
    this.retryText = 'Retry',
    this.closeLabel = 'Close',
    this.soundOnLabel = 'Sound on',
    this.soundOffLabel = 'Sound off',
    this.imageProvider,
    this.iconBuilder,
  });

  /// Сторис блока; сторис без слайдов пропускаются.
  final List<Story> stories;

  /// С какой сторис начать — индекс в [stories].
  final int initialStory;

  /// Уже просмотренные слайды: id слайдов по id сторис. По ним выбирается стартовый слайд
  /// сторис (первый непросмотренный). С [sdk] к ним добавляется сохранённое на устройстве.
  final Map<String, Set<String>> seen;

  /// Код блока для трекинга.
  final String? code;

  /// Инстанс для трекинга, хранения просмотренного и системных ссылок; `null` — без них.
  final PersonalizationSdk? sdk;

  /// Пауза от хоста: пока `true`, слайд стоит.
  final ValueListenable<bool>? paused;

  /// Слайд [slideIndex] сторис [story] стал текущим.
  final void Function(Story story, int slideIndex)? onSlideShown;

  /// Закрыть просмотр; не задан — `Navigator.maybePop`.
  final VoidCallback? onClose;

  /// Ссылка кнопки; не задан — ссылку открывает система.
  final ValueChanged<String>? onLinkClick;

  /// Нажатие на товар (карточка товарного слайда или карусель); не задан — открывается
  /// ссылка товара.
  final ValueChanged<StoryProduct>? onProductClick;

  /// Промокод скопирован.
  final ValueChanged<String>? onPromoCopied;

  /// Подпись кнопки товарного слайда, когда у слайда своих кнопок нет.
  final String productButtonText;

  /// Подпись над промокодом, когда в админке у товара нет своей.
  final String promoCaption;

  /// Текст тоста после копирования промокода.
  final String promoCopiedText;

  /// У какого края показать этот тост.
  final PersonalizationToastPosition promoToastPosition;

  /// Подписи переключателя товаров, когда их не прислал сервер.
  final String showProductsText;
  final String hideProductsText;

  /// Подпись кнопки повтора загрузки медиа.
  final String retryText;

  /// Подписи для скринридера: крестик и кнопка звука (включить / выключить).
  final String closeLabel;
  final String soundOnLabel;
  final String soundOffLabel;

  /// Картинка по адресу; не задан — [NetworkImage].
  final PersonalizationStoryImageProvider? imageProvider;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  /// Маршрут просмотра: во весь экран, с появлением. Непрозрачен только сам просмотр —
  /// при свайпе вниз под ним виден экран хоста.
  static Route<void> route(Widget viewer) => PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => viewer,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );

  @override
  State<PersonalizationStoryViewer> createState() =>
      _PersonalizationStoryViewerState();
}

class _PersonalizationStoryViewerState extends State<PersonalizationStoryViewer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final StoriesPlayback _playback = StoriesPlayback(
    stories: widget.stories,
    initialStory: widget.initialStory,
    seen: _initialSeen(),
  );
  late final PageController _pages = PageController(
    initialPage: _playback.storyIndex,
  );
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  /// Доля прошедшего времени слайда — для прогресса; перестраивает только шапку.
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  /// Насколько просмотр стянут вниз; перестраивает только сдвиг, не страницы.
  final ValueNotifier<double> _drag = ValueNotifier<double>(0);

  VideoPlayerController? _video;
  bool _videoReady = false;
  bool _videoPlaying = false;
  Timer? _timeout;
  Timer? _autoRetry;
  bool _closing = false;

  static const Duration _turn = Duration(milliseconds: 300);
  static const Duration _readyTimeout = Duration(seconds: 10);
  static const Duration _videoRetry = Duration(seconds: 15);
  static const double _closeDistance = 120;
  static const double _closeVelocity = 800;

  Map<String, Set<String>> _initialSeen() {
    final sdk = widget.sdk;
    final stored = sdk == null
        ? const <String, Set<String>>{}
        : StoriesSeenStore.instance.seen(sdk);
    return <String, Set<String>>{
      for (final entry in stored.entries) entry.key: entry.value,
      for (final entry in widget.seen.entries)
        entry.key: <String>{...?stored[entry.key], ...entry.value},
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    StoriesSound.instance.attach();
    StoriesSound.instance.muted.addListener(_onMuted);
    widget.paused?.addListener(_onHostPause);
    _onHostPause();
    _onLifecycle(WidgetsBinding.instance.lifecycleState);
    // Первая страница осела сразу: заход после кадра — загрузка картинки читает контекст.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_playback.isEmpty) _settled(_playback.storyIndex);
    });
  }

  @override
  void didUpdateWidget(PersonalizationStoryViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) {
      oldWidget.paused?.removeListener(_onHostPause);
      widget.paused?.addListener(_onHostPause);
      _onHostPause();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Просмотр закрыт непрозрачным экраном — навигатор глушит тикеры его поддерева.
    _setPaused(
      StoriesPauseReason.covered,
      !TickerMode.valuesOf(context).enabled,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _onLifecycle(state);

  void _onLifecycle(AppLifecycleState? state) => _setPaused(
    StoriesPauseReason.background,
    state != null && state != AppLifecycleState.resumed,
  );

  void _onHostPause() =>
      _setPaused(StoriesPauseReason.host, widget.paused?.value ?? false);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.paused?.removeListener(_onHostPause);
    StoriesSound.instance.muted.removeListener(_onMuted);
    _timeout?.cancel();
    _autoRetry?.cancel();
    _ticker.dispose();
    _disposeVideo();
    StoriesSound.instance.detach();
    _pages.dispose();
    _progress.dispose();
    _drag.dispose();
    super.dispose();
  }

  /// Поставить или снять паузу [reason]; часы и видео меняются только на переходе.
  void _setPaused(StoriesPauseReason reason, bool paused) {
    final changed = paused ? _playback.pause(reason) : _playback.resume(reason);
    if (changed) _sync();
  }

  /// Часы и видео идут, только пока слайд не стоит. Вызывается на переходах, не на кадре.
  void _sync() {
    final running = _playback.running;
    if (running && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!running && _ticker.isActive) {
      _ticker.stop();
    }
    final video = _video;
    if (video == null || !_videoReady || running == _videoPlaying) return;
    _videoPlaying = running;
    running ? video.play() : video.pause();
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    final video = _video?.value;
    // У видео время идёт, только пока оно играет, а не подгружается.
    if (_playback.followsVideo &&
        (video == null || !video.isPlaying || video.isBuffering)) {
      return;
    }
    final ended = _playback.tick(delta);
    _progress.value = _playback.progress;
    if (ended) _step(_playback.next());
  }

  // --- Навигация ----------------------------------------------------------------------

  /// Страница осела на [index]: заход на сторис или просто конец листания.
  void _settled(int index) {
    if (_playback.settle(index)) {
      _entered();
    } else {
      _sync();
    }
    setState(() {});
  }

  /// Исполнить шаг машины.
  void _step(StoriesStep step) {
    switch (step) {
      case StoriesStep.none:
        return;
      case StoriesStep.slide:
        _entered();
      case StoriesStep.turn:
        _sync();
        final target = _playback.turnTarget!;
        if (_pages.hasClients) {
          _pages.animateToPage(
            target,
            duration: _turn,
            curve: Curves.easeInOut,
          );
        } else {
          _settled(target);
        }
      case StoriesStep.close:
        _close();
    }
    if (mounted) setState(() {});
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _ticker.stop();
    _video?.pause();
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    // Не maybePop: при раскрытой шторке PopScope держит маршрут, а закрыть просмотр
    // нужно и из карусели товаров.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  /// Закрыть просмотр, потом [action] — переход по ссылке или к товару.
  void _closeThen(VoidCallback action) {
    _close();
    action();
  }

  /// Новый заход на слайд: прогресс с нуля, медиа, просмотренное, трекинг, хост.
  void _entered() {
    final story = _playback.story;
    final slide = _playback.slide;
    final index = _playback.slideIndex;
    final generation = _playback.generation;
    _progress.value = 0;
    _load(generation);
    final sdk = widget.sdk;
    if (sdk != null) {
      StoriesSeenStore.instance.mark(sdk, story.id, slide.id);
      if (storyTrackableId(story.id) && storyTrackableId(slide.id)) {
        sdk.tracking
            .storyView(storyId: story.id, slideId: slide.id, code: widget.code)
            .catchError((Object error) {
              debugPrint('PersonalizationStoryViewer: storyView — $error');
            });
      }
    }
    // Хосту — после кадра: заход бывает посреди сборки, а хост в ответ перестраивает
    // свой экран под маршрутом.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _playback.generation) {
        widget.onSlideShown?.call(story, index);
      }
    });
  }

  void _clicked() {
    final sdk = widget.sdk;
    final story = _playback.story;
    final slide = _playback.slide;
    if (sdk == null ||
        !storyTrackableId(story.id) ||
        !storyTrackableId(slide.id)) {
      return;
    }
    sdk.tracking
        .storyClick(storyId: story.id, slideId: slide.id, code: widget.code)
        .catchError((Object error) {
          debugPrint('PersonalizationStoryViewer: storyClick — $error');
        });
  }

  // --- Медиа --------------------------------------------------------------------------

  /// Загрузка медиа захода [generation]. Готово — часы пошли; ошибка или 10 с без
  /// готовности — пауза и «Повторить». Ответы прошлых заходов отбрасываются.
  void _load(int generation) {
    _timeout?.cancel();
    _autoRetry?.cancel();
    _disposeVideo();
    _sync();
    final slide = _playback.slide;
    switch (storyMediaOf(slide)) {
      case StoryMedia.none:
        _ready(generation);
      case StoryMedia.image:
        _timeout = Timer(_readyTimeout, () => _failed(generation));
        _loadImage(slide.background, generation);
      case StoryMedia.video:
        _timeout = Timer(_readyTimeout, () => _failed(generation));
        _loadVideo(slide.background, generation);
    }
  }

  void _loadImage(String url, int generation) {
    final image = storyImage(url, widget.imageProvider);
    if (image == null) return _ready(generation);
    var failed = false;
    precacheImage(
      image,
      context,
      onError: (_, _) => failed = true,
    ).then((_) => failed ? _failed(generation) : _ready(generation));
  }

  /// Видео из кэша, а нет файла — сразу по сети, пока кэш заполняется в фоне: загрузка
  /// целиком не ждётся. Готово — когда плеер готов играть.
  Future<void> _loadVideo(String url, int generation) async {
    try {
      await StoriesSound.instance.beforeVideo();
      final cache = StoriesMediaCache.instance;
      final file = await cache.cached(url);
      if (!_current(generation)) return;
      if (file == null) cache.fill(url);
      final options = VideoPlayerOptions(mixWithOthers: true);
      final video = file != null
          ? VideoPlayerController.file(file, videoPlayerOptions: options)
          : VideoPlayerController.networkUrl(
              Uri.parse(url),
              videoPlayerOptions: options,
            );
      _video = video;
      await video.initialize();
      if (!_current(generation) || _video != video) return;
      await video.setLooping(false);
      await video.setVolume(StoriesSound.instance.muted.value ? 0 : 1);
      await StoriesSound.instance.afterVideo();
      if (!_current(generation) || _video != video) return;
      video.addListener(_onVideo);
      _playback.useVideoDuration(video.value.duration);
      _videoReady = true;
      _videoPlaying = false;
      _ready(generation);
    } catch (error) {
      debugPrint('PersonalizationStoryViewer: video $url — $error');
      _failed(generation);
    }
  }

  bool _current(int generation) =>
      mounted && generation == _playback.generation;

  void _ready(int generation) {
    if (!_current(generation) || _playback.pausedBy(StoriesPauseReason.error)) {
      return;
    }
    _timeout?.cancel();
    _playback.mediaReady(generation);
    _sync();
    _preloadNext();
    setState(() {});
  }

  void _failed(int generation) {
    if (!_current(generation)) return;
    _timeout?.cancel();
    _playback.mediaFailed(generation);
    _sync();
    if (storyMediaOf(_playback.slide) == StoryMedia.video) {
      // Видео повторяет загрузку и само.
      _autoRetry?.cancel();
      _autoRetry = Timer(_videoRetry, _retry);
    }
    setState(() {});
  }

  void _retry() {
    final slide = _playback.slide;
    final image = storyMediaOf(slide) == StoryMedia.image
        ? storyImage(slide.background, widget.imageProvider)
        : null;
    image?.evict();
    final generation = _playback.retry();
    _progress.value = 0;
    _load(generation);
    setState(() {});
  }

  void _onVideo() {
    final video = _video;
    if (video == null) return;
    final value = video.value;
    if (value.hasError) {
      video.removeListener(_onVideo);
      return _failed(_playback.generation);
    }
    _playback.syncVideoPosition(value.position);
    _progress.value = _playback.progress;
    final ended =
        value.isCompleted ||
        (value.duration > Duration.zero && value.position >= value.duration);
    if (ended && _playback.running) _step(_playback.next());
  }

  void _disposeVideo() {
    final video = _video;
    _video = null;
    _videoReady = false;
    _videoPlaying = false;
    if (video == null) return;
    video.removeListener(_onVideo);
    video.dispose();
  }

  void _onMuted() {
    _video?.setVolume(StoriesSound.instance.muted.value ? 0 : 1);
    if (mounted) setState(() {});
  }

  /// Следующий слайд — тот же сторис или стартовый следующей — грузится заранее.
  void _preloadNext() {
    final stories = _playback.stories;
    final story = _playback.storyIndex;
    final StorySlide next;
    if (_playback.slideIndex < _playback.story.slides.length - 1) {
      next = _playback.story.slides[_playback.slideIndex + 1];
    } else if (story < stories.length - 1) {
      next = stories[story + 1].slides[_playback.startSlideFor(story + 1)];
    } else {
      return;
    }
    switch (storyMediaOf(next)) {
      case StoryMedia.none:
        break;
      case StoryMedia.image:
        final image = storyImage(next.background, widget.imageProvider);
        if (image != null) precacheImage(image, context, onError: (_, _) {});
      case StoryMedia.video:
        StoriesMediaCache.instance.preload(next.background);
        final poster = storyImage(next.preview, widget.imageProvider);
        if (poster != null) precacheImage(poster, context, onError: (_, _) {});
    }
  }

  // --- Действия -----------------------------------------------------------------------

  /// Касание: левая треть — назад, правая — вперёд, середина — ничего; в RTL зеркально.
  void _tap(double dx, double width) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (dx < width / 3) {
      _step(rtl ? _playback.next() : _playback.previous());
    } else if (dx > width * 2 / 3) {
      _step(rtl ? _playback.previous() : _playback.next());
    }
  }

  void _sheet(bool open) {
    final changed = open ? _playback.openSheet() : _playback.closeSheet();
    if (!changed) return;
    _sync();
    setState(() {});
  }

  void _button(StoryButtonElement button) {
    _clicked();
    final product = storyProductElement(_playback.slide)?.item;
    final own = storyButtonLink(button);
    if (own.isEmpty && product != null) return _closeThen(() => _goTo(product));
    _closeThen(() => _openLink(own));
  }

  void _product(StoryProduct product) {
    _clicked();
    _closeThen(() => _goTo(product));
  }

  void _promo(String code) {
    _clicked();
    widget.onPromoCopied?.call(code);
  }

  void _goTo(StoryProduct product) {
    final onProduct = widget.onProductClick;
    if (onProduct != null) return onProduct(product);
    _openUrl(storyProductLink(product));
  }

  void _openLink(String url) {
    if (url.isEmpty) return;
    final onLink = widget.onLinkClick;
    if (onLink != null) return onLink(url);
    _openUrl(url);
  }

  void _openUrl(String url) {
    if (url.isEmpty) return;
    widget.sdk?.openUrl(url).catchError((Object error) {
      debugPrint('PersonalizationStoryViewer: cannot open $url — $error');
      return false;
    });
  }

  // --- Сборка -------------------------------------------------------------------------

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _setPaused(StoriesPauseReason.drag, true);
    } else if (notification is ScrollEndNotification && _pages.hasClients) {
      _settled(_pages.page?.round() ?? _playback.storyIndex);
    }
    return false;
  }

  void _dragEnd(double velocity) {
    if (_drag.value > _closeDistance || velocity > _closeVelocity) {
      _close();
      return;
    }
    _drag.value = 0;
    _setPaused(StoriesPauseReason.drag, false);
  }

  @override
  Widget build(BuildContext context) {
    if (_playback.isEmpty) return const ColoredBox(color: Color(0xFF000000));
    final sheet = _playback.sheetOpen;
    return PopScope(
      // Системное «назад» сперва сворачивает шторку товаров.
      canPop: !sheet,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _sheet(false);
      },
      // В корневом маршруте нет Material: без этого Text взял бы аварийный стиль
      // приложения — с жёлтым подчёркиванием.
      child: DefaultTextStyle(
        style: const TextStyle(),
        child: GestureDetector(
          onVerticalDragStart: sheet
              ? null
              : (_) => _setPaused(StoriesPauseReason.drag, true),
          onVerticalDragUpdate: sheet
              ? null
              : (details) =>
                    _drag.value = math.max(0, _drag.value + details.delta.dy),
          onVerticalDragEnd: sheet
              ? null
              : (details) => _dragEnd(details.primaryVelocity ?? 0),
          onVerticalDragCancel: sheet ? null : () => _dragEnd(0),
          child: ValueListenableBuilder<double>(
            valueListenable: _drag,
            builder: (context, drag, child) => Transform.translate(
              offset: Offset(0, drag),
              child: Transform.scale(
                scale: 1 - math.min(drag / 2000, 0.1),
                child: child,
              ),
            ),
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: PageView.builder(
                controller: _pages,
                physics: sheet ? const NeverScrollableScrollPhysics() : null,
                itemCount: _playback.stories.length,
                itemBuilder: _page,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _page(BuildContext context, int index) {
    final story = _playback.stories[index];
    final live = _playback.entered && index == _playback.storyIndex;
    return StorySlideView(
      key: ValueKey<String>('story-${story.id}-$index'),
      story: story,
      slideIndex: live ? _playback.slideIndex : _playback.startSlideFor(index),
      config: widget,
      live: live,
      generation: live ? _playback.generation : 0,
      progress: live ? _progress : null,
      video: live && _videoReady ? _video : null,
      muted: StoriesSound.instance.muted.value,
      sheetOpen: live && _playback.sheetOpen,
      failed: live && _playback.pausedBy(StoriesPauseReason.error),
      onTap: _tap,
      onHold: (held) => _setPaused(StoriesPauseReason.hold, held),
      onClose: _close,
      onToggleMute: StoriesSound.instance.toggle,
      onSheet: _sheet,
      onButton: _button,
      onProduct: _product,
      onPromoCopied: _promo,
      onRetry: _retry,
    );
  }
}
