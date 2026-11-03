import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../stories/stories_response.dart';
import '../components/personalization_button.dart';
import '../components/personalization_product.dart';
import '../components/personalization_story_navigation.dart';
import '../components/personalization_story_poll.dart';
import '../components/personalization_story_price.dart';
import '../components/personalization_story_sound_button.dart';
import '../components/personalization_story_used_products.dart';
import '../components/personalization_toast.dart';
import '../personalization_theme.dart';
import 'personalization_story_viewer.dart';
import 'stories_gif_player.dart';
import 'stories_poll.dart';
import 'stories_polls_api.dart';
import 'stories_share.dart';
import 'stories_support.dart';

/// Один слайд просмотра сторис: фон, затемнение, содержимое, касания.
///
/// - Фото и видео вписываются целиком (contain), поля — `background_color` слайда, без
///   него чёрные; такой слайд всегда в тёмных токенах кита. Слайд без медиа — на
///   Background/Card темы приложения, цвет админки не берётся.
/// - Затемнение сверху и снизу на каждом слайде: 50% у голого медиа, иначе 30%
///   ([storyScrimOpacity]), до прозрачного к 21% и от 86% высоты.
/// - Товарный слайд — карточка товара кита, все кнопки слайда (Primary LG друг под
///   другом), «Используемые товары» и звук у видео; текстовые блоки на нём не рисуются,
///   но промокод текстового блока, если у товара своего нет, показывает блок цены.
/// - Медиа-слайд — непустые текстовые блоки на `y_offset`% высоты, кнопки внизу,
///   «Используемые товары», звук у видео.
/// - GIF фона живого слайда рисует [StoryGifPlayer]; у соседних страниц и до готовности
///   — первый кадр.
/// - Медиа не загрузилось — по центру кнопка кита [PersonalizationStoryViewer.retryText].
/// - У слайда есть ссылка «Поделиться» ([storySlideShareUrl]) и задан [onShare] — в шапке
///   кнопка слева от крестика.
/// - Опрос слайда ([storyPollOf]) при заданном [pollsTransport] — карточка
///   [PersonalizationStoryPoll] на `y_offset`% высоты всего слайда, и на товарном слайде
///   тоже, но целиком между шапкой и нижними кнопками; не влезает — прокрутка в ней.
///   Открыта клавиатура — карточка над ней (+16), слайд не сжимается, тап мимо
///   карточки только прячет клавиатуру.
///
/// Живой ([live]) — только текущий слайд осевшей страницы: у него часы, видео, касания и
/// шторка. Соседние страницы показывают свой стартовый слайд неподвижно.
class StorySlideView extends StatelessWidget {
  const StorySlideView({
    super.key,
    required this.story,
    required this.slideIndex,
    required this.config,
    this.live = false,
    this.generation = 0,
    this.progress,
    this.video,
    this.gif,
    this.muted = true,
    this.sheetOpen = false,
    this.failed = false,
    this.onTap,
    this.onHold,
    this.onClose,
    this.onShare,
    this.onToggleMute,
    this.onSheet,
    this.onButton,
    this.onProduct,
    this.onPromoCopied,
    this.onRetry,
    this.pollsTransport,
    this.pollShopId = '',
    this.onPollHold,
  });

  final Story story;
  final int slideIndex;

  /// Тексты, картинки и иконки — из просмотра.
  final PersonalizationStoryViewer config;
  final bool live;

  /// Номер захода: картинка фона пересоздаётся на каждый — без кадра прошлого слайда.
  final int generation;
  final ValueListenable<double>? progress;

  /// Готовое видео живого слайда; `null` — постер.
  final VideoPlayerController? video;

  /// GIF живого слайда; с кадром — рисуется он, иначе картинка по адресу (у GIF — его
  /// первый кадр).
  final StoryGifPlayer? gif;
  final bool muted;
  final bool sheetOpen;
  final bool failed;

  /// Касание по горизонтали [dx] при ширине [width].
  final void Function(double dx, double width)? onTap;
  final ValueChanged<bool>? onHold;
  final VoidCallback? onClose;

  /// «Поделиться» ссылкой [url]; [anchor] — кнопка в глобальных координатах.
  final void Function(String url, Rect anchor)? onShare;
  final VoidCallback? onToggleMute;
  final ValueChanged<bool>? onSheet;
  final ValueChanged<StoryButtonElement>? onButton;
  final ValueChanged<StoryProduct>? onProduct;
  final ValueChanged<String>? onPromoCopied;
  final VoidCallback? onRetry;

  /// Куда отправлять ответы опросов; `null` — опросы не рисуются.
  final StoryPollsTransport? pollsTransport;

  /// Магазин — ключ хранилища ответов опросов сессии.
  final String pollShopId;

  /// Опрос держит слайд (`true`) или отпускает.
  final ValueChanged<bool>? onPollHold;

  /// Удержание дольше этого — пауза, а не касание.
  static const Duration holdDelay = Duration(milliseconds: 200);

  StorySlide get slide => story.slides[slideIndex];

  @override
  Widget build(BuildContext context) {
    final slide = this.slide;
    final media = storyMediaOf(slide) != StoryMedia.none;
    final body = Builder(builder: (context) => _body(context, slide, media));
    // Слайды с медиа — тёмные токены кита: текст и кнопки лежат на фото или видео.
    return media
        ? PersonalizationBrightness(brightness: Brightness.dark, child: body)
        : body;
  }

  Widget _body(BuildContext context, StorySlide slide, bool media) {
    final colors = PersonalizationTheme.of(context).colors;
    final light = colors.textPrimary.computeLuminance() > 0.5;
    final product = storyProductElement(slide);
    // Нижний отступ — системный и при открытой клавиатуре: слайд под ней не сжимается.
    final content = SafeArea(
      maintainBottomViewPadding: true,
      child: product != null
          ? _productContent(context, slide, product)
          : _mediaContent(context, slide),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: light ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: LayoutBuilder(
        builder: (context, constraints) => _gestures(
          width: constraints.maxWidth,
          child: ColoredBox(
            color: media ? storyLetterbox(slide) : colors.backgroundCard,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (media) _background(slide),
                _scrim(slide),
                content,
                if (failed) Center(child: _retryButton()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Касания по третям и удержание от 200 мс; у неживой страницы — никаких.
  Widget _gestures({required double width, required Widget child}) {
    if (!live) return child;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        _SlideTap: GestureRecognizerFactoryWithHandlers<_SlideTap>(
          _SlideTap.new,
          (recognizer) =>
              recognizer.onTapUp = (details) =>
                  onTap?.call(details.localPosition.dx, width),
        ),
        _SlideHold: GestureRecognizerFactoryWithHandlers<_SlideHold>(
          () => _SlideHold(duration: holdDelay),
          (recognizer) {
            recognizer
              ..onLongPressStart = ((_) => onHold?.call(true))
              ..onLongPressEnd = ((_) => onHold?.call(false))
              ..onLongPressCancel = (() => onHold?.call(false));
          },
        ),
      },
      child: child,
    );
  }

  Widget _background(StorySlide slide) {
    final video = this.video;
    if (video != null && video.value.isInitialized) {
      final size = video.value.size;
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(video),
        ),
      );
    }
    final gif = this.gif;
    if (gif != null && gif.frame != null) {
      // Кадры GIF меняет проигрыватель — перерисовывается только картинка.
      return ListenableBuilder(
        listenable: gif,
        builder: (context, _) =>
            RawImage(image: gif.frame, fit: BoxFit.contain),
      );
    }
    final url = storyMediaOf(slide) == StoryMedia.video
        ? slide.preview
        : slide.background;
    final image = storyImage(url, config.imageProvider);
    if (image == null) return const SizedBox.shrink();
    // Своя картинка на каждый заход: без gaplessPlayback под текстом нового слайда не
    // остаётся фото прошлого.
    return Image(
      key: ValueKey<String>('${slide.id}-$generation'),
      image: image,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _scrim(StorySlide slide) {
    final shade = const Color(
      0xFF000000,
    ).withValues(alpha: storyScrimOpacity(slide));
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

  Widget _retryButton() => PersonalizationButton(
    label: config.retryText,
    size: PersonalizationButtonSize.md,
    iconBuilder: config.iconBuilder,
    onPressed: onRetry,
  );

  Widget _navigation() {
    final share = onShare;
    final url = share == null ? null : storySlideShareUrl(story, slide);
    Widget header(double value) => PersonalizationStoryNavigation(
      count: story.slides.length,
      current: slideIndex,
      progress: value,
      onClose: onClose,
      closeLabel: config.closeLabel,
      // Кнопка видна и у соседних страниц, нажимается только у живой.
      onShare: share == null || url == null
          ? null
          : (anchor) {
              if (live) share(url, anchor);
            },
      shareLabel: config.shareLabel,
      iconBuilder: config.iconBuilder,
    );
    final progress = this.progress;
    if (progress == null) return header(0);
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, value, _) => header(value),
    );
  }

  /// Шапка поверх всего слайда, и подложки шторки тоже: крестик закрывает просмотр и
  /// при раскрытой шторке; мимо крестика касание доходит до подложки.
  Widget _header() => Positioned(
    left: 16,
    top: 16,
    right: 16,
    child: _keyboardShield(_navigation()),
  );

  /// Кнопка звука — только у видео.
  Widget? _sound(StorySlide slide) {
    if (storyMediaOf(slide) != StoryMedia.video) return null;
    return PersonalizationStorySoundButton(
      muted: muted,
      onPressed: onToggleMute,
      soundOnLabel: config.soundOnLabel,
      soundOffLabel: config.soundOffLabel,
      iconBuilder: config.iconBuilder,
    );
  }

  // --- Содержимое ---------------------------------------------------------------------

  Widget _primaryButtons(List<StoryButtonElement> buttons) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (final button in buttons)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: PersonalizationButton(
            label: button.title,
            iconBuilder: config.iconBuilder,
            onPressed: live ? () => onButton?.call(button) : null,
          ),
        ),
    ],
  );

  /// Нижняя строка: «Используемые товары» со звуком в начале или только звук. Под
  /// раскрытой шторкой — подложка: тап мимо шторки её закрывает и никуда не листает;
  /// крестик шапки над ней и закрывает просмотр.
  List<Widget> _bottomRow(StorySlide slide) {
    final products = storyProducts(slide);
    final sound = _sound(slide);
    if (products == null && sound == null) return const <Widget>[];
    final Widget row;
    if (products == null) {
      row = SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: sound,
          ),
        ),
      );
    } else {
      final byId = <String, StoryProduct>{
        for (final product in products.products) product.id: product,
      };
      row = PersonalizationStoryUsedProducts(
        products: <PersonalizationProduct>[
          for (final product in products.products)
            storyCardProduct(product, config.imageProvider),
        ],
        showText: products.showLabel.isNotEmpty
            ? products.showLabel
            : config.showProductsText,
        hideText: products.hideLabel.isNotEmpty
            ? products.hideLabel
            : config.hideProductsText,
        expanded: sheetOpen,
        onExpandedChanged: live ? onSheet : null,
        onProductTap: (card) {
          final product = byId[card.id];
          if (live && product != null) onProduct?.call(product);
        },
        leading: sound,
        iconBuilder: config.iconBuilder,
      );
    }
    return <Widget>[
      if (sheetOpen)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSheet?.call(false),
            onLongPress: () {},
            onVerticalDragStart: (_) {},
            onHorizontalDragStart: (_) {},
          ),
        ),
      Positioned(left: 0, right: 0, bottom: 0, child: _keyboardShield(row)),
    ];
  }

  bool _hasRow(StorySlide slide) =>
      storyProducts(slide) != null || _sound(slide) != null;

  Widget _mediaContent(BuildContext context, StorySlide slide) {
    final texts = storyTextBlocks(slide);
    final buttons = storyButtons(slide);
    final polls = _poll(
      context,
      slide,
      bottom:
          (_hasRow(slide) ? 64 : 16) + buttons.length * _buttonSpace(context),
    );
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
          Positioned(
            left: 16,
            right: 16,
            bottom: _hasRow(slide) ? 64 : 16,
            child: _primaryButtons(buttons),
          ),
          ...polls,
          ..._bottomRow(slide),
          _header(),
        ],
      ),
    );
  }

  Widget _textBlock(BuildContext context, StoryTextBlockElement element) {
    final block = storyTextBlock(element);
    final code = element.promocode;
    if (code == null || !live) return block;
    // Блок с промокодом копирует его: тост сверху и `click` в трекинг.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        PersonalizationToast.show(
          context,
          config.promoCopiedText,
          position: PersonalizationToastPosition.top,
        );
        onPromoCopied?.call(code);
      },
      child: block,
    );
  }

  /// Товарный слайд: шапка (бренд SemiBold 20, название SemiBold 16, межстрочный 140%,
  /// шаг 8), белая карточка картинки (скругление 12, поля 16, квадрат по ширине — на
  /// низком экране ужимается), цена, кнопки слайда; без своих кнопок — одна
  /// [PersonalizationStoryViewer.productButtonText], ведёт к товару. Товар открывают
  /// только кнопки: шапка и картинка не нажимаются, касание по ним листает, как по слайду.
  Widget _productContent(
    BuildContext context,
    StorySlide slide,
    StoryProductElement element,
  ) {
    final product = element.item!;
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    // Промокод текстового блока слайда идёт в блок цены: сам блок здесь не рисуется.
    final price = storyPriceOf(product, slidePromo: storySlidePromocode(slide));
    final image = storyImage(product.image, config.imageProvider);
    final buttons = storyButtons(slide);

    TextStyle header(double size) => TextStyle(
      fontSize: size,
      height: 1.4,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      fontFamily: theme.fontFamily.familyFor(FontWeight.w600),
      package: theme.fontFamily.package,
      color: colors.textPrimary,
    );

    final column = Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, _hasRow(slide) ? 64 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Место шапки: сама она поверх всего ([_header]).
          const SizedBox(height: PersonalizationStoryNavigation.height),
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              // Картинка не нажимается: касание по ней — касание слайда (листает по
              // третям, удержание — пауза).
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
            promoCaption: storyPromoCaption(element, config.promoCaption),
            copiedText: config.promoCopiedText,
            onPromoCopied: live ? onPromoCopied : null,
            iconBuilder: config.iconBuilder,
          ),
          if (buttons.isNotEmpty)
            _primaryButtons(buttons)
          else
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: PersonalizationButton(
                label: config.productButtonText,
                iconBuilder: config.iconBuilder,
                onPressed: live ? () => onProduct?.call(product) : null,
              ),
            ),
        ],
      ),
    );
    final polls = _poll(
      context,
      slide,
      bottom:
          (_hasRow(slide) ? 64 : 16) +
          math.max(1, buttons.length) * _buttonSpace(context),
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[column, ...polls, ..._bottomRow(slide), _header()],
    );
  }

  // --- Опрос --------------------------------------------------------------------------

  /// Верх места карточки опроса: под шапкой, с зазором 8.
  static const double _pollTop = 16 + PersonalizationStoryNavigation.height + 8;

  /// Место под кнопкой Primary LG слайда: зазор 16 и кнопка — строка 32 и поля по 8.
  double _buttonSpace(BuildContext context) =>
      16 + MediaQuery.textScalerOf(context).scale(32) + 16;

  /// Опрос, который рисуется: есть элемент и транспорт.
  StoryPollElement? _pollOf(StorySlide slide) =>
      pollsTransport == null ? null : storyPollOf(slide);

  /// Открыта клавиатура (поле опроса живого слайда).
  bool _keyboardOpen(BuildContext context) =>
      live && MediaQuery.viewInsetsOf(context).bottom > 0;

  /// Подложка под открытой клавиатурой и карточка опроса. [bottom] — место нижних
  /// кнопок и строки «товары»; [outer] — контекст над SafeArea, с системными отступами:
  /// `y_offset` считается от всего слайда, а клавиатура перекрывает слайд на свою высоту
  /// без нижнего.
  List<Widget> _poll(
    BuildContext outer,
    StorySlide slide, {
    required double bottom,
  }) {
    final poll = _pollOf(slide);
    final transport = pollsTransport;
    if (poll == null || transport == null) return const <Widget>[];
    // Отступы SafeArea слайда (снизу — системный и при клавиатуре).
    final safeTop = MediaQuery.paddingOf(outer).top;
    final safeBottom = MediaQuery.viewPaddingOf(outer).bottom;
    return <Widget>[
      Positioned.fill(
        child: Builder(
          builder: (context) => IgnorePointer(
            ignoring: !_keyboardOpen(context),
            child: _keyboardBarrier(),
          ),
        ),
      ),
      Positioned.fill(
        child: Builder(
          builder: (context) {
            final keyboard = live
                ? math.max(
                    0.0,
                    MediaQuery.viewInsetsOf(context).bottom - safeBottom,
                  )
                : 0.0;
            return CustomSingleChildLayout(
              delegate: _StoryPollLayout(
                yOffset: poll.yOffset ?? 0,
                above: safeTop,
                below: safeBottom,
                top: _pollTop,
                bottom: bottom,
                keyboard: keyboard,
              ),
              child: IgnorePointer(
                ignoring: !live,
                child: PersonalizationStoryPoll(
                  key: ValueKey<String>('poll-${slide.id}'),
                  poll: poll,
                  storyId: story.id,
                  slideId: slide.id,
                  transport: transport,
                  shopId: pollShopId,
                  texts: StoryPollTexts(
                    reanswer: config.pollReanswerText,
                    error: config.pollErrorText,
                    submit: config.pollSubmitText,
                  ),
                  live: live,
                  onHold: onPollHold,
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  /// Тап мимо карточки при открытой клавиатуре только прячет её: ни касания по третям,
  /// ни удержания, ни свайпов.
  Widget _keyboardBarrier() => Listener(
    onPointerDown: (event) => StoryPollPointers.claim(event.pointer),
    onPointerUp: (event) => StoryPollPointers.release(event.pointer),
    onPointerCancel: (event) => StoryPollPointers.release(event.pointer),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      onVerticalDragStart: (_) {},
      onHorizontalDragStart: (_) {},
    ),
  );

  /// Шапка и нижняя строка слайда с опросом при открытой клавиатуре не нажимаются: тап
  /// по ним достаётся подложке и только прячет клавиатуру.
  Widget _keyboardShield(Widget child) {
    if (_pollOf(slide) == null) return child;
    return Builder(
      builder: (context) =>
          IgnorePointer(ignoring: _keyboardOpen(context), child: child),
    );
  }
}

/// Карточка опроса на слайде: по центру, шириной [PersonalizationStoryPoll.widthFor],
/// верх — [yOffset]% высоты всего слайда, потом сдвиг, чтобы карточка целиком была между
/// [top] и местом нижних кнопок [bottom]; не влезает — ниже высотой, прокрутка внутри.
/// Клавиатура перекрывает слайд снизу на [keyboard] — карточка поднимается над ней на 16.
///
/// Раскладка — в области SafeArea: [above] и [below] — отступы её от краёв слайда.
class _StoryPollLayout extends SingleChildLayoutDelegate {
  const _StoryPollLayout({
    required this.yOffset,
    required this.above,
    required this.below,
    required this.top,
    required this.bottom,
    required this.keyboard,
  });

  final double yOffset;
  final double above;
  final double below;
  final double top;
  final double bottom;
  final double keyboard;

  static const double _aboveKeyboard = 16;

  /// Ниже этого низ карточки не опускается.
  double _limit(Size size) {
    var limit = size.height - bottom;
    if (keyboard > 0) {
      limit = math.min(limit, size.height - keyboard - _aboveKeyboard);
    }
    return math.max(top, limit);
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final width = PersonalizationStoryPoll.widthFor(size.width);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0, _limit(size) - top),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final slide = above + size.height + below;
    final wanted = slide * yOffset.clamp(0, 100) / 100 - above;
    final y = math.max(top, math.min(wanted, _limit(size) - childSize.height));
    return Offset((size.width - childSize.width) / 2, y);
  }

  @override
  bool shouldRelayout(_StoryPollLayout oldDelegate) =>
      oldDelegate.yOffset != yOffset ||
      oldDelegate.above != above ||
      oldDelegate.below != below ||
      oldDelegate.top != top ||
      oldDelegate.bottom != bottom ||
      oldDelegate.keyboard != keyboard;
}

/// Касание слайда по третям; касания карточки опроса и подложки клавиатуры
/// ([StoryPollPointers]) — не его.
class _SlideTap extends TapGestureRecognizer {
  _SlideTap();

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      !StoryPollPointers.claimed(event.pointer) &&
      super.isPointerAllowed(event);
}

/// Удержание слайда; касания карточки опроса — не его.
class _SlideHold extends LongPressGestureRecognizer {
  _SlideHold({super.duration});

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      !StoryPollPointers.claimed(event.pointer) &&
      super.isPointerAllowed(event);
}
