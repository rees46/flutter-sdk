import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../stories/stories_response.dart';
import '../components/personalization_product.dart';
import '../components/personalization_story_price.dart';
import '../components/personalization_story_text_block.dart';

/// Как получить картинку по адресу из данных сторис. Не задан — [NetworkImage]; хост
/// подставляет свой провайдер, например с кэшем.
typedef PersonalizationStoryImageProvider = ImageProvider Function(String url);

/// Картинка по адресу; пустой адрес — `null`.
ImageProvider? storyImage(
  String url,
  PersonalizationStoryImageProvider? custom,
) {
  if (url.isEmpty) return null;
  return custom?.call(url) ?? NetworkImage(url);
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

/// Цена товара для [PersonalizationStoryPrice]: вид блока и его строки.
///
/// Есть промокод — вид promoCode, цена с промокодом (`price_with_promocode_formatted`,
/// без неё обычная); иначе скидка больше нуля — вид discount («N%»); иначе просто цена.
/// Старая цена — когда она выше текущей.
({
  PersonalizationStoryPriceType type,
  String price,
  String? oldPrice,
  String? discount,
  String? promoCode,
})
storyPriceOf(StoryProduct product) {
  final oldPrice = product.hasOldPrice ? product.oldPriceFormatted : null;
  final price = product.priceFormatted.isNotEmpty
      ? product.priceFormatted
      : _plainPrice(product);
  if (product.promocode.isNotEmpty) {
    return (
      type: PersonalizationStoryPriceType.promoCode,
      price: product.priceWithPromocodeFormatted.isNotEmpty
          ? product.priceWithPromocodeFormatted
          : price,
      oldPrice: oldPrice,
      discount: null,
      promoCode: product.promocode,
    );
  }
  if (product.discountPercent > 0) {
    return (
      type: PersonalizationStoryPriceType.discount,
      price: price,
      oldPrice: oldPrice,
      discount: '${product.discountPercent}%',
      promoCode: null,
    );
  }
  return (
    type: PersonalizationStoryPriceType.price,
    price: price,
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
        ? '-${product.discountPercent}%'
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

/// Текстовый блок сервера → [PersonalizationStoryTextBlock].
///
/// Шрифт `serif` / `monospaced` — системные семейства с запасными для iOS, где имён
/// `serif` и `monospace` нет; `sans-serif` и пусто — шрифт темы. Интерлиньяж 0 — свой
/// у шрифта.
PersonalizationStoryTextBlock storyTextBlock(StoryTextBlockElement element) {
  final (family, fallback) = switch (element.fontType) {
    'serif' => ('serif', const <String>['Georgia', 'Times New Roman']),
    'monospaced' => ('monospace', const <String>['Menlo', 'Courier']),
    _ => (null, null),
  };
  return PersonalizationStoryTextBlock(
    text: element.text,
    fontSize: element.fontSize,
    lineHeight: element.lineSpacing > 0 ? element.lineSpacing : null,
    color: parseStoryColor(element.textColor),
    background: element.backgroundOpacity > 0
        ? parseStoryColor(
            element.backgroundColor,
            opacity: element.backgroundOpacity,
          )
        : null,
    textAlign: switch (element.textAlign) {
      'center' => TextAlign.center,
      'right' => TextAlign.end,
      _ => TextAlign.start,
    },
    bold: element.bold,
    italic: element.italic,
    fontFamily: family,
    fontFamilyFallback: fallback,
  );
}
