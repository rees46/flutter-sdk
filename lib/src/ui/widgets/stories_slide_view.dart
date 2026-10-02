import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

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
import 'personalization_story_viewer.dart';
import 'stories_support.dart';

/// Один слайд просмотра сторис: фон, затемнение, содержимое, касания.
///
/// - Фото и видео вписываются целиком (contain), поля — `background_color` слайда, без
///   него чёрные; такой слайд всегда в тёмных токенах кита. Слайд без медиа — на
///   Background/Card темы приложения, цвет админки не берётся.
/// - Затемнение сверху и снизу на каждом слайде: 50% у голого медиа, иначе 30%
///   ([storyScrimOpacity]), до прозрачного к 21% и от 86% высоты.
/// - Товарный слайд — карточка товара кита, все кнопки слайда (Primary LG друг под
///   другом), «Используемые товары» и звук у видео; текстовые блоки на нём не рисуются.
/// - Медиа-слайд — непустые текстовые блоки на `y_offset`% высоты, кнопки внизу,
///   «Используемые товары», звук у видео.
/// - Медиа не загрузилось — по центру кнопка кита [PersonalizationStoryViewer.retryText].
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
    this.muted = true,
    this.sheetOpen = false,
    this.failed = false,
    this.onTap,
    this.onHold,
    this.onClose,
    this.onToggleMute,
    this.onSheet,
    this.onButton,
    this.onProduct,
    this.onPromoCopied,
    this.onRetry,
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
  final bool muted;
  final bool sheetOpen;
  final bool failed;

  /// Касание по горизонтали [dx] при ширине [width].
  final void Function(double dx, double width)? onTap;
  final ValueChanged<bool>? onHold;
  final VoidCallback? onClose;
  final VoidCallback? onToggleMute;
  final ValueChanged<bool>? onSheet;
  final ValueChanged<StoryButtonElement>? onButton;
  final ValueChanged<StoryProduct>? onProduct;
  final ValueChanged<String>? onPromoCopied;
  final VoidCallback? onRetry;

  /// Удержание дольше этого — пауза, а не касание.
  static const Duration holdDelay = Duration(milliseconds: 200);

  StorySlide get slide => story.slides[slideIndex];

  @override
  Widget build(BuildContext context) {
    final slide = this.slide;
    final media = storyMediaOf(slide) != StoryMedia.none;
    final base = Theme.of(context);
    return Theme(
      data: media ? _mediaTheme(base) : base,
      child: Builder(builder: (context) => _body(context, slide, media)),
    );
  }

  /// Тема слайдов с медиа: тёмные токены кита. Тема хоста уже тёмная — берётся она,
  /// иначе тёмный набор кита с брендом, радиусами и шрифтом хоста.
  static ThemeData _mediaTheme(ThemeData base) {
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
    final light = colors.textPrimary.computeLuminance() > 0.5;
    final product = storyProductElement(slide);
    final content = SafeArea(
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
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (recognizer) =>
                  recognizer.onTapUp = (details) =>
                      onTap?.call(details.localPosition.dx, width),
            ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(duration: holdDelay),
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
    Widget header(double value) => PersonalizationStoryNavigation(
      count: story.slides.length,
      current: slideIndex,
      progress: value,
      onClose: onClose,
      closeLabel: config.closeLabel,
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
  Widget _header() =>
      Positioned(left: 16, top: 16, right: 16, child: _navigation());

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
      Positioned(left: 0, right: 0, bottom: 0, child: row),
    ];
  }

  bool _hasRow(StorySlide slide) =>
      storyProducts(slide) != null || _sound(slide) != null;

  Widget _mediaContent(BuildContext context, StorySlide slide) {
    final texts = storyTextBlocks(slide);
    final buttons = storyButtons(slide);
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
          position: config.promoToastPosition,
        );
        onPromoCopied?.call(code);
      },
      child: block,
    );
  }

  /// Товарный слайд: шапка (бренд SemiBold 20, название SemiBold 16, межстрочный 140%,
  /// шаг 8), белая карточка картинки (скругление 12, поля 16, квадрат по ширине — на
  /// низком экране ужимается), цена, кнопки слайда; без своих кнопок — одна
  /// [PersonalizationStoryViewer.productButtonText], ведёт к товару.
  Widget _productContent(
    BuildContext context,
    StorySlide slide,
    StoryProductElement element,
  ) {
    final product = element.item!;
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final price = storyPriceOf(product);
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
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GestureDetector(
                    onTap: live ? () => onProduct?.call(product) : null,
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
          ),
          PersonalizationStoryPrice(
            type: price.type,
            price: price.price,
            oldPrice: price.oldPrice,
            discount: price.discount,
            promoCode: price.promoCode,
            promoCaption: storyPromoCaption(element, config.promoCaption),
            copiedText: config.promoCopiedText,
            copiedToastPosition: config.promoToastPosition,
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
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[column, ..._bottomRow(slide), _header()],
    );
  }
}
