import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../personalization_sdk.dart';
import '../../stories/stories_response.dart';
import '../components/personalization_button.dart';
import '../components/personalization_product.dart';
import '../components/personalization_story_navigation.dart';
import '../components/personalization_story_price.dart';
import '../components/personalization_story_sound_button.dart';
import '../components/personalization_story_used_products.dart';
import '../components/personalization_toast.dart';
import '../personalization_colors.dart';
import '../personalization_theme.dart';
import 'stories_support.dart';

/// Полноэкранный просмотр сторис: слайды по таймеру, листание, товары, ссылки.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), фреймы Card/Story
/// (Product, Promo, Discount, Action, Slide, Text) 402×874.
///
/// Раскладка: поля 16, шаг 16. Фон — картинка или видео слайда (cover), под ними цвет
/// `background_color`; сверху и снизу затемнение: чёрный 30% (50% на слайдах с медиа)
/// до прозрачного к 21% и от 86% высоты.
///
/// - Слайды с медиа (`image` / `video`) всегда в тёмных токенах кита — белые хром и
///   текст, тёмный лист товаров: поддерево переключается на тёмную тему. Бренд темы
///   хоста (Brand/Primary и кнопки) сохраняется.
/// - Слайд с товаром следует теме приложения: фон Background/Generic, текст
///   Text/Primary. Сверху шапка (бренд SemiBold 20, название SemiBold 16, межстрочный
///   140%, шаг 8), посередине белая карточка картинки (скругление 12, поля 16,
///   квадрат по ширине — на низком экране ужимается), внизу с шагом 16
///   [PersonalizationStoryPrice] и кнопка LG — подпись кнопки слайда, без неё
///   [moreInfoText]. Вид цены: промокод — promoCode, скидка — discount, иначе price.
/// - На слайде с медиа текстовые блоки стоят на `y_offset` процентов высоты слайда во
///   всю ширину без полей, кнопки — внизу кнопками LG, товары —
///   [PersonalizationStoryUsedProducts]. У видео слева внизу кнопка звука; звук по
///   умолчанию выключен, как в прежних сторис Android, и переключается на весь просмотр.
///
/// Поведение: слайд идёт `duration` секунд (отсчёт начинается, когда загрузилась
/// картинка или видео); касание левой трети — предыдущий слайд, остального — следующий;
/// удержание — пауза прогресса и видео; раскрытые товары — тоже пауза; свайп вниз
/// закрывает; свайп вбок — соседняя сторис; после последнего слайда последней сторис
/// просмотр закрывается. Каждая сторис начинается со слайда из [startSlides], иначе с
/// `start_position`.
///
/// Трекинг через [sdk]: `view` на каждый показанный слайд, `click` на кнопку, товар и
/// промокод. О показе слайда узнаёт и хост — [onSlideShown] (лента по нему отмечает
/// просмотренное). Ссылки: [onLinkClick], если задан, иначе системный обработчик через
/// SDK (`link_android` / `link_ios`, иначе `link`; у товара — диплинк, иначе `url`).
///
/// Открывается маршрутом [route] или встраивается как обычный виджет с [onClose].
class PersonalizationStoryViewer extends StatefulWidget {
  const PersonalizationStoryViewer({
    super.key,
    required this.stories,
    this.initialStory = 0,
    this.startSlides = const <String, int>{},
    this.code,
    this.sdk,
    this.onSlideShown,
    this.onClose,
    this.onLinkClick,
    this.onProductClick,
    this.onPromoCopied,
    this.moreInfoText = 'More info',
    this.promoCodeCaption = 'Promo code',
    this.promoCopiedText = 'Copied',
    this.usedProductsText = 'Used products',
    this.hideProductsText = 'Hide products',
    this.imageProvider,
    this.iconBuilder,
  });

  final List<Story> stories;

  /// С какой сторис начать.
  final int initialStory;

  /// С какого слайда начать сторис, по её id; нет в списке — `start_position`.
  final Map<String, int> startSlides;

  /// Код блока для трекинга.
  final String? code;

  /// Инстанс для трекинга и системных ссылок; `null` — без них.
  final PersonalizationSdk? sdk;

  /// Показан слайд [slideIndex] сторис [story].
  final void Function(Story story, int slideIndex)? onSlideShown;

  /// Закрыть просмотр; не задан — `Navigator.maybePop`.
  final VoidCallback? onClose;

  /// Ссылка кнопки или товара; не задан — ссылку открывает система.
  final ValueChanged<String>? onLinkClick;

  /// Нажатие на товар в карусели слайда; не задан — открывается ссылка товара.
  final ValueChanged<StoryProduct>? onProductClick;

  /// Промокод скопирован.
  final ValueChanged<String>? onPromoCopied;

  /// Подпись кнопки слайда с товаром, когда у слайда своей кнопки нет.
  final String moreInfoText;
  final String promoCodeCaption;

  /// Текст тоста после копирования промокода.
  final String promoCopiedText;

  /// Подписи переключателя товаров, когда их не прислал сервер.
  final String usedProductsText;
  final String hideProductsText;

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

class _PersonalizationStoryViewerState
    extends State<PersonalizationStoryViewer> {
  late final int _initial = widget.stories.isEmpty
      ? 0
      : widget.initialStory.clamp(0, widget.stories.length - 1);
  late final PageController _pages = PageController(initialPage: _initial);
  late int _current = _initial;
  bool _muted = true;
  double _drag = 0;
  bool _closing = false;

  static const Duration _turn = Duration(milliseconds: 300);

  /// Свайп вниз дальше этого — закрыть.
  static const double _closeDistance = 120;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _nextStory() {
    if (_current < widget.stories.length - 1) {
      _pages.nextPage(duration: _turn, curve: Curves.easeInOut);
    } else {
      _close();
    }
  }

  /// К предыдущей сторис; `false` — это первая.
  bool _previousStory() {
    if (_current == 0) return false;
    _pages.previousPage(duration: _turn, curve: Curves.easeInOut);
    return true;
  }

  int _startOf(Story story) {
    final start = widget.startSlides[story.id] ?? story.startPosition;
    return story.slides.isEmpty ? 0 : start.clamp(0, story.slides.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final stories = widget.stories;
    // В корневом маршруте нет Material: без этого Text взял бы аварийный стиль
    // приложения — с жёлтым подчёркиванием.
    return DefaultTextStyle(
      style: const TextStyle(),
      child: GestureDetector(
        onVerticalDragUpdate: (details) =>
            setState(() => _drag = math.max(0, _drag + details.delta.dy)),
        onVerticalDragEnd: (details) {
          if (_drag > _closeDistance || (details.primaryVelocity ?? 0) > 800) {
            _close();
          } else {
            setState(() => _drag = 0);
          }
        },
        onVerticalDragCancel: () => setState(() => _drag = 0),
        child: Transform.translate(
          offset: Offset(0, _drag),
          child: Transform.scale(
            scale: 1 - math.min(_drag / 2000, 0.1),
            child: stories.isEmpty
                ? const ColoredBox(color: Color(0xFF000000))
                : PageView.builder(
                    controller: _pages,
                    itemCount: stories.length,
                    onPageChanged: (index) => setState(() => _current = index),
                    itemBuilder: (context, index) {
                      final story = stories[index];
                      return _StoryPage(
                        key: ValueKey<String>('story-${story.id}-$index'),
                        story: story,
                        startSlide: _startOf(story),
                        active: index == _current,
                        held: _drag > 0,
                        muted: _muted,
                        config: widget,
                        onToggleMute: () => setState(() => _muted = !_muted),
                        onFinished: _nextStory,
                        onBeforeFirst: _previousStory,
                        onClose: _close,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// Одна сторис: текущий слайд, его таймер, медиа и касания.
class _StoryPage extends StatefulWidget {
  const _StoryPage({
    super.key,
    required this.story,
    required this.startSlide,
    required this.active,
    required this.held,
    required this.muted,
    required this.config,
    required this.onToggleMute,
    required this.onFinished,
    required this.onBeforeFirst,
    required this.onClose,
  });

  final Story story;
  final int startSlide;

  /// Сторис на экране; остальные страницы стоят.
  final bool active;

  /// Просмотр придержан снаружи — тянут вниз.
  final bool held;
  final bool muted;
  final PersonalizationStoryViewer config;
  final VoidCallback onToggleMute;

  /// Последний слайд досмотрен или пролистан.
  final VoidCallback onFinished;

  /// Листают назад с первого слайда; `false` — предыдущей сторис нет.
  final bool Function() onBeforeFirst;
  final VoidCallback onClose;

  @override
  State<_StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<_StoryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this)
    ..addStatusListener(_onStatus);
  late int _slide = widget.startSlide;
  VideoPlayerController? _video;
  bool _videoReady = false;

  /// Медиа слайда загружено — можно считать время.
  bool _ready = false;

  /// Удерживают палец.
  bool _hold = false;

  /// Раскрыты товары слайда.
  bool _productsOpen = false;

  /// Номер захода на слайд: ответы загрузок от прошлых заходов отбрасываются.
  int _generation = 0;

  PersonalizationStoryViewer get _config => widget.config;

  StorySlide? get _current =>
      widget.story.slides.isEmpty ? null : widget.story.slides[_slide];

  bool get _running =>
      widget.active && !widget.held && !_hold && !_productsOpen && _ready;

  @override
  void initState() {
    super.initState();
    // Загрузка картинки читает контекст (MediaQuery, ассеты) — после первой сборки.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) _enter();
    });
  }

  @override
  void didUpdateWidget(_StoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.muted != widget.muted) {
      _video?.setVolume(widget.muted ? 0 : 1);
    }
    if (widget.active && !oldWidget.active) {
      _enter();
    } else {
      _sync();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _video?.dispose();
    super.dispose();
  }

  /// Заход на текущий слайд: прогресс с нуля, загрузка медиа, трекинг показа.
  void _enter() {
    final slide = _current;
    if (slide == null) {
      // Сторис без слайдов пропускается — после кадра: заход бывает посреди сборки.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished();
      });
      return;
    }
    final generation = ++_generation;
    _progress
      ..stop()
      ..value = 0
      ..duration = slide.duration;
    _ready = false;
    _productsOpen = false;
    _disposeVideo();
    if (mounted) setState(() {});
    _prepare(slide, generation);
    _shown(slide, generation);
  }

  void _disposeVideo() {
    final video = _video;
    _video = null;
    _videoReady = false;
    video?.dispose();
  }

  Future<void> _prepare(StorySlide slide, int generation) async {
    switch (slide.type) {
      case StorySlideType.product:
        break;
      case StorySlideType.image:
        final image = storyImage(slide.background, _config.imageProvider);
        if (image != null) {
          await precacheImage(image, context, onError: (_, _) {});
        }
      case StorySlideType.video:
        final uri = Uri.tryParse(slide.background);
        if (uri != null && slide.background.isNotEmpty) {
          final video = VideoPlayerController.networkUrl(uri);
          _video = video;
          try {
            await video.initialize();
            if (generation != _generation) return;
            await video.setLooping(true);
            await video.setVolume(widget.muted ? 0 : 1);
            _videoReady = true;
          } catch (error) {
            // Видео не открылось — остаётся постер, слайд идёт по таймеру.
            debugPrint(
              'PersonalizationStoryViewer: video ${slide.id} — $error',
            );
          }
        }
    }
    if (!mounted || generation != _generation) return;
    setState(() => _ready = true);
    _sync();
  }

  /// Прогресс и видео идут, только когда ничто их не держит.
  void _sync() {
    if (_running) {
      if (!_progress.isAnimating && _progress.value < 1) _progress.forward();
      _video?.play();
    } else {
      _progress.stop();
      _video?.pause();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _next();
  }

  void _next() {
    if (_slide < widget.story.slides.length - 1) {
      _slide++;
      _enter();
    } else {
      _progress.stop();
      widget.onFinished();
    }
  }

  void _previous() {
    if (_slide > 0) {
      _slide--;
      _enter();
    } else if (!widget.onBeforeFirst()) {
      _enter();
    }
  }

  void _setHold(bool hold) {
    _hold = hold;
    _sync();
  }

  // --- Трекинг и действия ----------------------------------------------------------------

  void _shown(StorySlide slide, int generation) {
    // Хосту — после кадра: заход на слайд бывает посреди сборки (смена сторис), а хост
    // в ответ перестраивает свой экран под маршрутом.
    final index = _slide;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) {
        _config.onSlideShown?.call(widget.story, index);
      }
    });
    final sdk = _config.sdk;
    if (sdk == null || widget.story.id.isEmpty || slide.id.isEmpty) return;
    sdk.tracking
        .storyView(
          storyId: widget.story.id,
          slideId: slide.id,
          code: _config.code,
        )
        .catchError((Object error) {
          debugPrint('PersonalizationStoryViewer: storyView — $error');
        });
  }

  void _clicked() {
    final slide = _current;
    final sdk = _config.sdk;
    if (slide == null ||
        sdk == null ||
        widget.story.id.isEmpty ||
        slide.id.isEmpty) {
      return;
    }
    sdk.tracking
        .storyClick(
          storyId: widget.story.id,
          slideId: slide.id,
          code: _config.code,
        )
        .catchError((Object error) {
          debugPrint('PersonalizationStoryViewer: storyClick — $error');
        });
  }

  void _open(String url) {
    if (url.isEmpty) return;
    final onLink = _config.onLinkClick;
    if (onLink != null) {
      onLink(url);
      return;
    }
    _config.sdk?.openUrl(url).catchError((Object error) {
      debugPrint('PersonalizationStoryViewer: cannot open $url — $error');
      return false;
    });
  }

  void _productTapped(StoryProduct product) {
    _clicked();
    final onProduct = _config.onProductClick;
    if (onProduct != null) {
      onProduct(product);
    } else {
      _open(storyProductLink(product));
    }
  }

  void _promoCopied(String code) {
    _clicked();
    _config.onPromoCopied?.call(code);
  }

  // --- Сборка ------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final slide = _current;
    if (slide == null) return const ColoredBox(color: Color(0xFF000000));
    final media = slide.type != StorySlideType.product;
    final base = Theme.of(context);
    return Theme(
      data: media ? _mediaTheme(base) : base,
      child: Builder(builder: (context) => _body(context, slide, media)),
    );
  }

  /// Тема слайдов с медиа: тёмные токены кита. Тема хоста уже тёмная — берётся она,
  /// иначе тёмный набор кита с брендом, радиусами и шрифтом хоста.
  ThemeData _mediaTheme(ThemeData base) {
    final host = base.extension<PersonalizationTheme>();
    final PersonalizationTheme dark;
    if (host != null && base.brightness == Brightness.dark) {
      dark = host;
    } else {
      final source = host ?? PersonalizationTheme.light;
      final brand = source.colors;
      dark = PersonalizationTheme.dark.copyWith(
        radius: source.radius,
        fontFamily: source.fontFamily,
        colors: PersonalizationColors.dark.copyWith(
          brandPrimary: brand.brandPrimary,
          buttonPrimary: brand.buttonPrimary,
          buttonPrimaryDisabled: brand.buttonPrimaryDisabled,
          lineBrand: brand.lineBrand,
          textBrand: brand.textBrand,
        ),
      );
    }
    return base.copyWith(
      extensions: [
        for (final extension in base.extensions.values)
          if (extension is! PersonalizationTheme) extension,
        dark,
      ],
    );
  }

  Widget _body(BuildContext context, StorySlide slide, bool media) {
    final colors = PersonalizationTheme.of(context).colors;
    final background =
        parseStoryColor(slide.backgroundColor) ??
        (media ? const Color(0xFF000000) : colors.backgroundGeneric);
    final light = colors.textPrimary.computeLuminance() > 0.5;
    final product = slide.product;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: light ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) =>
              details.localPosition.dx < constraints.maxWidth / 3
              ? _previous()
              : _next(),
          onLongPressStart: (_) => _setHold(true),
          onLongPressEnd: (_) => _setHold(false),
          child: ColoredBox(
            color: background,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (media) _background(slide),
                _scrim(media),
                SafeArea(
                  child: media || product == null
                      ? _mediaContent(context, slide)
                      : _productContent(context, slide, product),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _background(StorySlide slide) {
    final video = _video;
    if (slide.type == StorySlideType.video && video != null && _videoReady) {
      final size = video.value.size;
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(video),
          ),
        ),
      );
    }
    final url = slide.type == StorySlideType.video
        ? slide.preview
        : slide.background;
    final image = storyImage(url, _config.imageProvider);
    if (image == null) return const SizedBox.shrink();
    return Image(image: image, fit: BoxFit.cover, gaplessPlayback: true);
  }

  Widget _scrim(bool media) {
    final shade = const Color(0xFF000000).withValues(alpha: media ? 0.5 : 0.3);
    const clear = Color(0x00000000);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[shade, clear, clear, shade],
            stops: const <double>[0, 0.21, 0.86, 1],
          ),
        ),
      ),
    );
  }

  Widget _navigation() => AnimatedBuilder(
    animation: _progress,
    builder: (context, _) => PersonalizationStoryNavigation(
      count: widget.story.slides.length,
      current: _slide,
      progress: _progress.value,
      onClose: widget.onClose,
      iconBuilder: _config.iconBuilder,
    ),
  );

  Widget _productContent(
    BuildContext context,
    StorySlide slide,
    StoryProduct product,
  ) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final price = storyPriceOf(product);
    StoryButtonElement? button;
    for (final element in slide.elements) {
      if (element is StoryButtonElement) {
        button = element;
        break;
      }
    }
    final buttonLink = button == null ? '' : storyButtonLink(button);
    final image = storyImage(product.image, _config.imageProvider);

    TextStyle header(double size) => TextStyle(
      fontSize: size,
      height: 1.4,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      fontFamily: theme.fontFamily.familyFor(FontWeight.w600),
      package: theme.fontFamily.package,
      color: colors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _navigation(),
          const SizedBox(height: 16),
          if (product.brand.isNotEmpty) ...<Widget>[
            Text(
              product.brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: header(20),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            product.name,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: header(16),
          ),
          // Карточка — квадрат во всю ширину; на низком экране ужимается по высоте.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: image == null
                          ? null
                          : Image(image: image, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PersonalizationStoryPrice(
            type: price.type,
            price: price.price,
            oldPrice: price.oldPrice,
            discount: price.discount,
            promoCode: price.promoCode,
            promoCodeCaption: _config.promoCodeCaption,
            copiedText: _config.promoCopiedText,
            onPromoCopied: _promoCopied,
            iconBuilder: _config.iconBuilder,
          ),
          const SizedBox(height: 16),
          PersonalizationButton(
            label: button != null && button.title.trim().isNotEmpty
                ? button.title
                : _config.moreInfoText,
            iconBuilder: _config.iconBuilder,
            onPressed: () {
              _clicked();
              _open(
                buttonLink.isNotEmpty ? buttonLink : storyProductLink(product),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _mediaContent(BuildContext context, StorySlide slide) {
    final texts = slide.elements.whereType<StoryTextBlockElement>().toList();
    final buttons = slide.elements
        .whereType<StoryButtonElement>()
        .where((button) => button.title.trim().isNotEmpty)
        .toList();
    StoryProductsElement? products;
    for (final element in slide.elements) {
      if (element is StoryProductsElement && element.products.isNotEmpty) {
        products = element;
        break;
      }
    }
    final sound = slide.type == StorySlideType.video
        ? PersonalizationStorySoundButton(
            muted: widget.muted,
            onPressed: widget.onToggleMute,
            iconBuilder: _config.iconBuilder,
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          for (final text in texts)
            Positioned(
              left: 16,
              right: 16,
              top: constraints.maxHeight * text.yOffset.clamp(0, 100) / 100,
              child: _textBlock(context, text),
            ),
          Positioned(left: 16, top: 16, right: 16, child: _navigation()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final button in buttons)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: PersonalizationButton(
                      label: button.title,
                      iconBuilder: _config.iconBuilder,
                      onPressed: () {
                        _clicked();
                        _open(storyButtonLink(button));
                      },
                    ),
                  ),
                if (products != null)
                  _usedProducts(products, sound)
                else if (sound != null)
                  SizedBox(
                    height: 64,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: sound,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _usedProducts(StoryProductsElement element, Widget? sound) {
    final byId = <String, StoryProduct>{
      for (final product in element.products) product.id: product,
    };
    return PersonalizationStoryUsedProducts(
      key: ValueKey<String>('products-$_slide'),
      products: <PersonalizationProduct>[
        for (final product in element.products)
          storyCardProduct(product, _config.imageProvider),
      ],
      showText: element.showLabel.isNotEmpty
          ? element.showLabel
          : _config.usedProductsText,
      hideText: element.hideLabel.isNotEmpty
          ? element.hideLabel
          : _config.hideProductsText,
      onExpandedChanged: (open) {
        _productsOpen = open;
        _sync();
      },
      onProductTap: (card) {
        final product = byId[card.id];
        if (product != null) _productTapped(product);
      },
      leading: sound,
      iconBuilder: _config.iconBuilder,
    );
  }

  Widget _textBlock(BuildContext context, StoryTextBlockElement element) {
    final block = storyTextBlock(element);
    final code = element.promocode;
    if (code == null) return block;
    // Блок с промокодом копирует его, как в прежних сторис.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        PersonalizationToast.show(context, _config.promoCopiedText);
        _promoCopied(code);
      },
      child: block,
    );
  }
}
