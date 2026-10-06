import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../stories/stories_response.dart';
import '../components/personalization_product.dart';
import '../components/personalization_story_price.dart';
import '../components/personalization_story_text_block.dart';
import 'stories_image.dart';

/// Как получить картинку по адресу из данных сторис. Не задан — свой загрузчик SDK: качает
/// как [NetworkImage], GIF анимирует только на фоне слайда и по нему же меряет длину
/// слайда, а обложки, превью, постеры и картинки товаров показывает первым кадром. Хост
/// подставляет свой провайдер, например с кэшем, — тогда GIF им и рисуется: SDK его не
/// анимирует, не останавливает и не меряет, слайд длится время из админки.
typedef PersonalizationStoryImageProvider = ImageProvider Function(String url);

/// Картинка по адресу — провайдер хоста или [StoryImage] (GIF — первым кадром); пустой
/// адрес — `null`.
ImageProvider? storyImage(
  String url,
  PersonalizationStoryImageProvider? custom,
) {
  if (url.isEmpty) return null;
  return custom?.call(url) ?? StoryImage(url);
}

/// Цвет из `#RRGGBB`, `#RGB` или `#AARRGGBB`; не разобрать — `null`.
Color? parseStoryColor(String value, {double opacity = 1}) {
  var hex = value.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final argb = int.tryParse(hex, radix: 16);
  if (argb == null) return null;
  final color = Color(argb);
  return color.withValues(alpha: color.a * opacity.clamp(0, 1));
}

/// Что слайд показывает фоном.
enum StoryMedia {
  /// Ничего: фон Background/Card темы приложения.
  none,

  /// Фото.
  image,

  /// Видео; постер — `preview`.
  video,
}

/// Медиа слайда решает непустой `background`, а не тип слайда: товарный слайд с фото —
/// тоже медиа-слайд, а `image` без адреса — нет.
StoryMedia storyMediaOf(StorySlide slide) {
  if (slide.background.trim().isEmpty) return StoryMedia.none;
  return slide.type == StorySlideType.video
      ? StoryMedia.video
      : StoryMedia.image;
}

/// Цвет полей вокруг вписанного медиа: `background_color` слайда, без него чёрный. Это
/// единственное место, где цвет админки идёт в дело: слайд без медиа всегда на
/// Background/Card.
Color storyLetterbox(StorySlide slide) =>
    parseStoryColor(slide.backgroundColor) ?? const Color(0xFF000000);

/// Текстовые блоки, которые рисуются: пустые и из одних пробелов пропускаются.
List<StoryTextBlockElement> storyTextBlocks(StorySlide slide) =>
    <StoryTextBlockElement>[
      for (final element in slide.elements)
        if (element is StoryTextBlockElement && element.text.trim().isNotEmpty)
          element,
    ];

/// Кнопки слайда с подписью — по порядку.
List<StoryButtonElement> storyButtons(StorySlide slide) => <StoryButtonElement>[
  for (final element in slide.elements)
    if (element is StoryButtonElement && element.title.trim().isNotEmpty)
      element,
];

/// Элемент товара товарного слайда (с самим товаром); нет — `null`.
StoryProductElement? storyProductElement(StorySlide slide) {
  for (final element in slide.elements) {
    if (element is StoryProductElement && element.item != null) return element;
  }
  return null;
}

/// Элемент «Используемые товары» с непустым списком; нет — `null`.
StoryProductsElement? storyProducts(StorySlide slide) {
  for (final element in slide.elements) {
    if (element is StoryProductsElement && element.products.isNotEmpty) {
      return element;
    }
  }
  return null;
}

/// Плотность затемнения сверху и снизу. Оно есть на каждом слайде: 50% — только у
/// медиа без товара и без непустых текстов (голое фото или видео), иначе 30%.
double storyScrimOpacity(StorySlide slide) =>
    storyMediaOf(slide) != StoryMedia.none &&
        storyProductElement(slide) == null &&
        storyTextBlocks(slide).isEmpty
    ? 0.5
    : 0.3;

/// Трекается ли id: только целые положительные числа. Динамические слайды (`39_0`) API
/// трекинга не принимает — они пропускаются молча на всех платформах.
bool storyTrackableId(String id) {
  final trimmed = id.trim();
  if (!RegExp(r'^\d+$').hasMatch(trimmed)) return false;
  final number = int.tryParse(trimmed);
  return number != null && number > 0;
}

/// Процент без лишних нулей: `10` → «10%», `12.5` → «12.5%».
String storyPercent(double value) {
  final text = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
  return '$text%';
}

/// Цена товара для [PersonalizationStoryPrice]: вид блока и его строки.
///
/// - Промокод — вид promoCode: крупно цена с промокодом
///   (`price_with_promocode_formatted`, без неё обычная); зачёркнута старая цена, если
///   она есть, иначе обычная цена, если она отличается от цены с промокодом.
/// - Иначе скидка больше нуля — вид discount с процентом `discount_percent` (дробный
///   остаётся дробным: «12.5%»).
/// - Иначе просто цена.
///
/// Старая цена показывается, только если она численно больше цены; числа читаются
/// десятичными, не целыми.
({
  PersonalizationStoryPriceType type,
  String price,
  String? oldPrice,
  String? discount,
  String? promoCode,
})
storyPriceOf(StoryProduct product) {
  final regular = product.priceFormatted.isNotEmpty
      ? product.priceFormatted
      : _plainPrice(product);
  final oldPrice = product.hasOldPrice ? product.oldPriceFormatted : null;
  if (product.promocode.isNotEmpty) {
    final promoPrice = product.priceWithPromocodeFormatted.isNotEmpty
        ? product.priceWithPromocodeFormatted
        : regular;
    // Числом сравниваем, когда сервер прислал цену с промокодом числом; иначе — текстом.
    final cheaper = product.priceWithPromocode > 0
        ? product.price > product.priceWithPromocode
        : promoPrice != regular;
    return (
      type: PersonalizationStoryPriceType.promoCode,
      price: promoPrice,
      oldPrice: oldPrice ?? (cheaper ? regular : null),
      discount: null,
      promoCode: product.promocode,
    );
  }
  if (product.discountPercent > 0) {
    return (
      type: PersonalizationStoryPriceType.discount,
      price: regular,
      oldPrice: oldPrice,
      discount: storyPercent(product.discountPercent),
      promoCode: null,
    );
  }
  return (
    type: PersonalizationStoryPriceType.price,
    price: regular,
    oldPrice: oldPrice,
    discount: null,
    promoCode: null,
  );
}

String _plainPrice(StoryProduct product) {
  final amount = product.price == product.price.roundToDouble()
      ? product.price.toStringAsFixed(0)
      : product.price.toString();
  return '$amount ${product.currency}'.trim();
}

/// Подпись над промокодом: `title` элемента товара из админки; пустой — текст хоста.
String storyPromoCaption(StoryProductElement? element, String fallback) {
  final title = element?.title.trim() ?? '';
  return title.isNotEmpty ? title : fallback;
}

/// Товар сторис → данные карточки кита для карусели товаров слайда.
PersonalizationProduct storyCardProduct(
  StoryProduct product,
  PersonalizationStoryImageProvider? image,
) {
  final hasOldPrice = product.hasOldPrice;
  return PersonalizationProduct(
    id: product.id,
    name: product.name,
    price: product.priceFormatted.isNotEmpty
        ? product.priceFormatted
        : _plainPrice(product),
    image: storyImage(product.image, image),
    brand: product.brand.isEmpty ? null : product.brand,
    oldPrice: hasOldPrice ? product.oldPriceFormatted : null,
    discount: hasOldPrice && product.discountPercent > 0
        ? '-${storyPercent(product.discountPercent)}'
        : null,
  );
}

/// Ссылка кнопки для текущей платформы: своя, иначе общая `link`.
String storyButtonLink(StoryButtonElement button) {
  final own = switch (defaultTargetPlatform) {
    TargetPlatform.android => button.linkAndroid,
    TargetPlatform.iOS => button.linkIos,
    _ => '',
  };
  return own.isNotEmpty ? own : button.link;
}

/// Ссылка товара для текущей платформы: диплинк, иначе `url`.
String storyProductLink(StoryProduct product) {
  final own = switch (defaultTargetPlatform) {
    TargetPlatform.android => product.deeplinkAndroid,
    TargetPlatform.iOS => product.deeplinkIos,
    _ => '',
  };
  return own.isNotEmpty ? own : product.url;
}

/// Куда ведёт кнопка товарного слайда: своя ссылка кнопки (платформенная, затем общая),
/// без неё — товар слайда (диплинк, затем `url`).
String storySlideButtonLink(StoryButtonElement button, StoryProduct? product) {
  final own = storyButtonLink(button);
  if (own.isNotEmpty || product == null) return own;
  return storyProductLink(product);
}

/// Выключка текстового блока: `left`/`start` — к началу строки, `center` — по центру,
/// `right`/`end` — к концу (для RTL зеркально).
TextAlign storyTextAlign(String value) => switch (value.trim().toLowerCase()) {
  'center' => TextAlign.center,
  'right' || 'end' => TextAlign.end,
  _ => TextAlign.start,
};

/// Текстовый блок сервера → [PersonalizationStoryTextBlock].
///
/// Шрифт `serif` / `monospaced` — системные семейства с запасными для iOS, где имён
/// `serif` и `monospace` нет; `sans-serif` и пусто — шрифт темы. Межстрочный не задан —
/// заготовка макета для этого кегля ([PersonalizationStoryTextBlock.presetLineHeight]).
PersonalizationStoryTextBlock storyTextBlock(StoryTextBlockElement element) {
  final (family, fallback) = switch (element.fontType) {
    'serif' => ('serif', const <String>['Georgia', 'Times New Roman']),
    'monospaced' => ('monospace', const <String>['Menlo', 'Courier']),
    _ => (null, null),
  };
  return PersonalizationStoryTextBlock(
    text: element.text,
    fontSize: element.fontSize,
    lineHeight: element.lineSpacing > 0
        ? element.lineSpacing
        : PersonalizationStoryTextBlock.presetLineHeight(element.fontSize),
    color: parseStoryColor(element.textColor),
    background: element.backgroundOpacity > 0
        ? parseStoryColor(
            element.backgroundColor,
            opacity: element.backgroundOpacity,
          )
        : null,
    textAlign: storyTextAlign(element.textAlign),
    bold: element.bold,
    italic: element.italic,
    fontFamily: family,
    fontFamilyFallback: fallback,
  );
}

/// Сторис, которые можно показать: со слайдами (C16) и без повторов id — сервер иногда
/// отдаёт одну сторис дважды; остаётся первая, иначе просмотренность по id склеивается.
List<Story> playableStories(Iterable<Story> stories) {
  final ids = <String>{};
  return <Story>[
    for (final story in stories)
      if (story.slides.isNotEmpty && ids.add(story.id)) story,
  ];
}
