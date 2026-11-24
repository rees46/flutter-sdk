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
import '../personalization_typography.dart';
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
/// - Медиа-слайд — непустые текстовые блоки, кнопки внизу, «Используемые товары», звук
///   у видео. Текстовый блок стоит, как карточка опроса: верх на `y_offset`% высоты
///   всего слайда, но целиком между шапкой и нижними кнопками; выше этого места — от
///   его верха.
/// - GIF фона живого слайда рисует [StoryGifPlayer]; у соседних страниц и до готовности
///   — первый кадр.
/// - Медиа не загрузилось — по центру кнопка кита [PersonalizationStoryViewer.retryText].
/// - У слайда есть ссылка «Поделиться» ([storySlideShareUrl]) и задан [onShare] — в шапке
///   кнопка слева от крестика.
/// - Опросы слайда ([storyPollsOf]) при заданном [pollsTransport] — каждый своей
///   карточкой [PersonalizationStoryPoll] на своём `y_offset`% высоты всего слайда, и на
///   товарном слайде тоже; не влезает — прокрутка в ней.
///   Открыта клавиатура — карточка над ней (+16), слайд не сжимается, тап мимо
///   карточки только прячет клавиатуру.
///
/// Новая лента ([v3]), как в вебе: медиа решает тип слайда; слайд без медиа — цвета
/// `background_color` (без него — Background/Card), токены — по его яркости; текстовый
/// блок без `font_size` — кеглем основного текста кита; шапка `header` (иконка, заголовок,
/// подзаголовок) под шапкой просмотра, нажатие — [onHeader]; кнопка звука — только у
/// видео со звуком ([hasAudio]).
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
    this.shareLabel = 'Share',
    this.onToggleMute,
    this.onSheet,
    this.onButton,
    this.onProduct,
    this.onPromoCopied,
    this.onRetry,
    this.pollsTransport,
    this.pollTexts = const StoryPollTexts(),
    this.pollShopId = '',
    this.pollDid = '',
    this.onPollHold,
    this.v3 = false,
    this.hasAudio = true,
    this.onHeader,
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

  /// Подпись «Поделиться» для скринридера.
  final String shareLabel;
  final VoidCallback? onToggleMute;
  final ValueChanged<bool>? onSheet;
  final ValueChanged<StoryButtonElement>? onButton;
  final ValueChanged<StoryProduct>? onProduct;
  final ValueChanged<String>? onPromoCopied;
  final VoidCallback? onRetry;

  /// Куда отправлять ответы опросов; `null` — опросы не рисуются.
  final StoryPollsTransport? pollsTransport;

  /// Тексты карточки опроса от хоста.
  final StoryPollTexts pollTexts;

  /// Магазин и устройство (`did`) — ключ сохранённых ответов опросов.
  final String pollShopId;
  final String pollDid;

  /// Карточка опроса [card] держит слайд (`true`) или отпускает: у слайда их может быть
  /// несколько, слайд стоит, пока держит хоть одна.
  final void Function(Object card, bool held)? onPollHold;

  /// Слайд новой ленты (API v3): правила веба, см. описание класса.
  final bool v3;

  /// У видео слайда есть звук: без него у новой ленты нет кнопки звука.
  final bool hasAudio;

  /// Нажата шапка `header` слайда новой ленты.
  final ValueChanged<StoryHeaderElement>? onHeader;

  /// Удержание дольше этого — пауза, а не касание.
  static const Duration holdDelay = Duration(milliseconds: 200);

  StorySlide get slide => story.slides[slideIndex];

  StoryMedia _media(StorySlide slide) => storyMediaOf(slide, byType: v3);

  /// Свой цвет слайда без медиа (новая лента); нет — `null`.
  Color? _slideColor(StorySlide slide) => v3 ? storySlideColor(slide) : null;

  @override
  Widget build(BuildContext context) {
    final slide = this.slide;
    final media = _media(slide) != StoryMedia.none;
    final body = Builder(builder: (context) => _body(context, slide, media));
    // Слайды с медиа — тёмные токены кита: текст и кнопки лежат на фото или видео. Свой
    // цвет слайда без медиа (уже на чёрном фоне просмотра) — токены кита, у которых
    // основной текст контрастнее с ним по WCAG.
    final color = media ? null : _slideColor(slide);
    if (media) {
      return PersonalizationBrightness(
        brightness: Brightness.dark,
        child: body,
      );
    }
    if (color == null) return body;
    return PersonalizationBrightness(
      brightness: PersonalizationBrightness.on(color),
      child: body,
    );
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
            color: media
                ? storyLetterbox(slide, newFeed: v3)
                : _slideColor(slide) ?? colors.backgroundCard,
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
    final url = _media(slide) == StoryMedia.video
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
    ).withValues(alpha: storyScrimOpacity(slide, byType: v3));
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
      shareLabel: shareLabel,
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

  /// Кнопка звука — только у видео, у новой ленты — только со звуком.
  Widget? _sound(StorySlide slide) {
    if (_media(slide) != StoryMedia.video || (v3 && !hasAudio)) return null;
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
    final bottom =
        (_hasRow(slide) ? 64 : 16) + buttons.length * _buttonSpace(context);
    final header = _storyHeader(context, slide);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Шапка `header` и текстовые блоки — в одной раскладке: блоки встают под шапку,
        // `y_offset` у них, как у опроса, — от всего слайда.
        Positioned.fill(
          child: CustomMultiChildLayout(
            delegate: _BodyLayout(<_SlideBlockLayout>[
              for (final text in texts)
                _blockLayout(context, text.yOffset, bottom: bottom),
            ]),
            children: <Widget>[
              for (final (index, text) in texts.indexed)
                LayoutId(id: index, child: _textBlock(context, text)),
              if (header != null)
                LayoutId(id: _BodyLayout.header, child: header),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: _hasRow(slide) ? 64 : 16,
          child: _primaryButtons(buttons),
        ),
        ..._poll(context, slide, bottom: bottom),
        ..._bottomRow(slide),
        _header(),
      ],
    );
  }

  /// Шапка `header` слайда новой ленты под строкой крестика: иконка 40 в круге, зазор
  /// 12, заголовок (SM полужирный) и подзаголовок (XS) кита; нажатие — [onHeader].
  /// Нечего показать или не новая лента — `null`.
  Widget? _storyHeader(BuildContext context, StorySlide slide) {
    final header = v3 ? storyHeaderOf(slide) : null;
    if (header == null) return null;
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    TextStyle style(TextStyle token, Color color) => token.copyWith(
      color: color,
      decoration: TextDecoration.none,
      fontFamily: theme.fontFamily.familyFor(token.fontWeight!),
      package: theme.fontFamily.package,
    );
    final icon = storyImage(header.icon, config.imageProvider);
    final title = header.title.trim();
    final subtitle = header.subtitle.trim();
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: live ? () => onHeader?.call(header) : null,
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              ClipOval(
                child: SizedBox.square(
                  dimension: _headerIcon,
                  child: Image(
                    image: icon,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        ColoredBox(color: colors.neutral50),
                  ),
                ),
              ),
              const SizedBox(width: _headerGap),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (title.isNotEmpty)
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style(
                        PersonalizationTypography.smEmphasized,
                        colors.textPrimary,
                      ),
                    ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style(
                        PersonalizationTypography.xsDefault,
                        colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textBlock(BuildContext context, StoryTextBlockElement element) {
    final block = storyTextBlock(element, newFeed: v3);
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
  /// низком экране ужимается), цена, кнопки слайда; без своих кнопок у старой ленты — одна
  /// [PersonalizationStoryViewer.productButtonText], ведёт к товару, у новой, как в вебе,
  /// — никакой. Товар открывают только кнопки: шапка и картинка не нажимаются, касание по
  /// ним листает, как по слайду.
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
    // Кнопка кита «к товару» вместо своих — только у старой ленты: в вебе её нет.
    final more = buttons.isEmpty && !v3;

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
          if (_storyHeader(context, slide) case final header?) ...<Widget>[
            header,
            const SizedBox(height: 16),
          ],
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
          else if (more)
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
          (more ? 1 : buttons.length) * _buttonSpace(context),
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[column, ...polls, ..._bottomRow(slide), _header()],
    );
  }

  // --- Опрос и место блоков ------------------------------------------------------------

  /// Иконка шапки `header` и зазор от неё до текста.
  static const double _headerIcon = 40;
  static const double _headerGap = 12;

  /// Высота нижней строки слайда: звук, «Используемые товары».
  static const double _rowHeight = 64;

  /// Верх места блоков слайда (опрос, текстовые блоки): под шапкой, с зазором 8.
  static const double _blockTop =
      16 + PersonalizationStoryNavigation.height + 8;

  /// Место под кнопкой Primary LG слайда: зазор 16 и кнопка — строка 32 и поля по 8.
  double _buttonSpace(BuildContext context) =>
      16 + MediaQuery.textScalerOf(context).scale(32) + 16;

  /// Раскладка блока слайда — карточки опроса ([poll]) или текстового блока — на
  /// [yOffset]% высоты всего слайда, между шапкой и местом нижних кнопок [bottom].
  /// [outer] — контекст над SafeArea, с системными отступами.
  _SlideBlockLayout _blockLayout(
    BuildContext outer,
    double yOffset, {
    required double bottom,
    double keyboard = 0,
    bool poll = false,
    double row = 0,
  }) => _SlideBlockLayout(
    yOffset: yOffset,
    // Отступы SafeArea слайда (снизу — системный и при клавиатуре).
    above: MediaQuery.paddingOf(outer).top,
    below: MediaQuery.viewPaddingOf(outer).bottom,
    top: _blockTop,
    bottom: bottom,
    keyboard: keyboard,
    poll: poll,
    row: row,
  );

  /// Опросы, которые рисуются: есть элементы и транспорт.
  List<StoryPollElement> _pollsOf(StorySlide slide) =>
      pollsTransport == null ? const <StoryPollElement>[] : storyPollsOf(slide);

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
    final polls = _pollsOf(slide);
    final transport = pollsTransport;
    if (polls.isEmpty || transport == null) return const <Widget>[];
    final safeBottom = MediaQuery.viewPaddingOf(outer).bottom;
    Widget card(int index, StoryPollElement poll) {
      final key = 'poll-${slide.id}-$index';
      return Positioned.fill(
        child: Builder(
          builder: (context) {
            final keyboard = live
                ? math.max(
                    0.0,
                    MediaQuery.viewInsetsOf(context).bottom - safeBottom,
                  )
                : 0.0;
            return CustomSingleChildLayout(
              delegate: _blockLayout(
                outer,
                poll.yOffset ?? 0,
                bottom: bottom,
                keyboard: keyboard,
                poll: true,
                // Нижняя строка (звук, «Используемые товары») видна — карточка над ней.
                row: _hasRow(slide) ? _rowHeight : 0,
              ),
              child: IgnorePointer(
                ignoring: !live,
                child: PersonalizationStoryPoll(
                  key: ValueKey<String>(key),
                  poll: poll,
                  storyId: story.id,
                  slideId: slide.id,
                  transport: transport,
                  shopId: pollShopId,
                  did: pollDid,
                  texts: pollTexts,
                  live: live,
                  onHold: (held) => onPollHold?.call(key, held),
                ),
              ),
            );
          },
        ),
      );
    }

    return <Widget>[
      Positioned.fill(
        child: Builder(
          builder: (context) => IgnorePointer(
            ignoring: !_keyboardOpen(context),
            child: _keyboardBarrier(),
          ),
        ),
      ),
      for (var i = 0; i < polls.length; i++) card(i, polls[i]),
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
    if (_pollsOf(slide).isEmpty) return child;
    return Builder(
      builder: (context) =>
          IgnorePointer(ignoring: _keyboardOpen(context), child: child),
    );
  }
}

/// Блок на слайде — карточка опроса или текстовый блок: верх — [yOffset]% высоты всего
/// слайда (зажато 0…100, не число — 0), потом сдвиг, чтобы блок целиком был между [top]
/// и местом нижних кнопок [bottom]; выше этого места — от его верха.
///
/// Карточка опроса ([poll]) — как в вебе: по центру, шириной
/// [PersonalizationStoryPoll.widthFor], верх на [yOffset]% всего слайда (не выше верха
/// SafeArea), а не влезает — поднимается, чтобы низ был на 16 выше нижней строки [row]
/// (звук, «Используемые товары»), когда она видна, иначе на 16 выше низа SafeArea, но не
/// выше её верха; шапку и кнопки слайда она может накрыть. Выше слайда — ниже высотой,
/// прокрутка внутри. Клавиатура перекрывает слайд снизу на [keyboard] — карточка
/// поднимается над ней на 16.
/// Текстовый блок — во всю ширину с полями 16, своей высоты.
///
/// Раскладка — в области SafeArea: [above] и [below] — отступы её от краёв слайда.
class _SlideBlockLayout extends SingleChildLayoutDelegate {
  const _SlideBlockLayout({
    required this.yOffset,
    required this.above,
    required this.below,
    required this.top,
    required this.bottom,
    this.keyboard = 0,
    this.poll = false,
    this.row = 0,
  });

  final double yOffset;
  final double above;
  final double below;
  final double top;
  final double bottom;
  final double keyboard;
  final bool poll;

  /// Высота видимой нижней строки слайда; нет её — 0.
  final double row;

  /// Та же раскладка, но не выше [top] (под шапкой `header`).
  _SlideBlockLayout from(double top) => _SlideBlockLayout(
    yOffset: yOffset,
    above: above,
    below: below,
    top: top,
    bottom: bottom,
    keyboard: keyboard,
    poll: poll,
    row: row,
  );

  static const double _aboveKeyboard = 16;

  /// Зазор карточки опроса до нижней строки или низа SafeArea.
  static const double _pollMargin = 16;

  /// Поля текстового блока слева и справа.
  static const double _textEdge = 16;

  /// Выше этого верх блока не поднимается: у опроса — верх слайда.
  double get _top => poll ? 0 : top;

  /// Ниже этого низ блока не опускается.
  double _limit(Size size) {
    var limit = poll ? size.height - row - _pollMargin : size.height - bottom;
    if (keyboard > 0) {
      limit = math.min(limit, size.height - keyboard - _aboveKeyboard);
    }
    return math.max(_top, limit);
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    if (!poll) {
      return BoxConstraints.tightFor(
        width: math.max(0, size.width - 2 * _textEdge),
      );
    }
    final width = PersonalizationStoryPoll.widthFor(size.width);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0, _limit(size) - _top),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final slide = above + size.height + below;
    final percent = yOffset.isFinite ? yOffset.clamp(0, 100) : 0;
    final wanted = slide * percent / 100 - above;
    final y = math.max(_top, math.min(wanted, _limit(size) - childSize.height));
    return Offset((size.width - childSize.width) / 2, y);
  }

  @override
  bool shouldRelayout(_SlideBlockLayout oldDelegate) =>
      oldDelegate.yOffset != yOffset ||
      oldDelegate.above != above ||
      oldDelegate.below != below ||
      oldDelegate.top != top ||
      oldDelegate.bottom != bottom ||
      oldDelegate.keyboard != keyboard ||
      oldDelegate.poll != poll ||
      oldDelegate.row != row;
}

/// Шапка `header` и текстовые блоки медиа-слайда: шапка — под строкой крестика
/// ([StorySlideView._blockTop]) во всю ширину с полями 16; блоки — по своим
/// [_SlideBlockLayout] (`y_offset` от всего слайда), но не выше низа шапки с зазором 8:
/// шапка их не накрывает.
class _BodyLayout extends MultiChildLayoutDelegate {
  _BodyLayout(this.blocks);

  /// Раскладки текстовых блоков; блок [i] — ребёнок с id `i`.
  final List<_SlideBlockLayout> blocks;

  /// Id шапки.
  static const Object header = 'header';

  static const double _edge = 16;
  static const double _gap = 8;

  @override
  void performLayout(Size size) {
    var top = StorySlideView._blockTop;
    if (hasChild(header)) {
      final height = layoutChild(
        header,
        BoxConstraints.tightFor(width: math.max(0, size.width - 2 * _edge)),
      ).height;
      positionChild(header, Offset(_edge, top));
      top += height + _gap;
    }
    for (var i = 0; i < blocks.length; i++) {
      if (!hasChild(i)) continue;
      final base = blocks[i];
      final block = top > base.top ? base.from(top) : base;
      final child = layoutChild(
        i,
        block.getConstraintsForChild(BoxConstraints.tight(size)),
      );
      positionChild(i, block.getPositionForChild(size, child));
    }
  }

  @override
  bool shouldRelayout(_BodyLayout oldDelegate) {
    if (oldDelegate.blocks.length != blocks.length) return true;
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].shouldRelayout(oldDelegate.blocks[i])) return true;
    }
    return false;
  }
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
