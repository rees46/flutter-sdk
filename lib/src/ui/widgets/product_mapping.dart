import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../products/products_list_response.dart';
import '../../recommendation/recommendation_response.dart';
import '../../search/search_response.dart';
import '../components/personalization_product.dart';

/// Товар ответа API → данные карточки кита. Один маппер на все виджеты с данными:
/// поиск, рекомендации, каталог. Форма товара в API везде одна, разные только модели
/// SDK, поэтому у каждой своя точка входа, а правила — общие, в [_card].
///
/// Не экспортируется: это внутренность виджетов с данными.
PersonalizationProduct productFromSearch(
  SearchProduct product, {
  String? actionText,
}) => _card(
  id: product.id,
  name: product.name,
  brand: product.brand,
  price: product.price,
  priceFormatted: product.priceFormatted,
  currency: product.currency,
  oldPrice: product.oldPrice,
  oldPriceFormatted: product.oldPriceFormatted,
  discount: product.discount,
  discountFormatted: product.discountFormatted,
  picture: product.picture,
  imageUrl: product.imageUrl,
  url: product.url,
  deeplinkAndroid: product.deeplinkAndroid,
  deeplinkIos: product.deeplinkIos,
  actionText: actionText,
);

/// Товар блока рекомендаций → карточка, см. [productFromSearch].
PersonalizationProduct productFromRecommendation(
  RecommendedProduct product, {
  String? actionText,
}) => _card(
  id: product.id,
  name: product.name,
  brand: product.brand,
  price: product.price,
  priceFormatted: product.priceFormatted,
  currency: product.currency,
  oldPrice: product.oldPrice,
  oldPriceFormatted: product.oldPriceFormatted,
  discount: product.discount,
  discountFormatted: product.discountFormatted,
  picture: product.resizedImageUrl,
  imageUrl: product.imageUrl,
  url: product.url,
  deeplinkAndroid: product.deeplinkAndroid,
  deeplinkIos: product.deeplinkIos,
  actionText: actionText,
);

/// Товар каталога (категория, коллекция, список товаров, карточка товара) →
/// карточка, см. [productFromSearch].
PersonalizationProduct productFromCatalog(
  Product product, {
  String? actionText,
}) => _card(
  id: product.id,
  name: product.name,
  brand: product.brand,
  price: product.price,
  priceFormatted: product.priceFormatted,
  currency: product.currency,
  oldPrice: product.oldPrice,
  oldPriceFormatted: product.oldPriceFormatted,
  discount: product.discount,
  discountFormatted: product.discountFormatted,
  picture: product.picture,
  imageUrl: product.imageUrl,
  url: product.url,
  deeplinkAndroid: product.deeplinkAndroid,
  deeplinkIos: product.deeplinkIos,
  actionText: actionText,
);

/// Общие правила. Строки берутся уже отформатированными сервером:
/// - цена — `price_formatted`, иначе «цена валюта»;
/// - старая цена — `oldprice_formatted`, и только когда `oldprice` больше цены;
/// - скидка — только при старой цене: `discount_formatted`, иначе «discount%», со знаком «-»;
/// - картинка — `picture` (уменьшенная копия), иначе `image_url`;
/// - диплинк — для платформы запуска; рейтинга в API нет.
PersonalizationProduct _card({
  required String id,
  required String name,
  required String brand,
  required double price,
  required String? priceFormatted,
  required String currency,
  required double? oldPrice,
  required String? oldPriceFormatted,
  required int? discount,
  required String? discountFormatted,
  required String? picture,
  required String imageUrl,
  required String url,
  required String? deeplinkAndroid,
  required String? deeplinkIos,
  required String? actionText,
}) {
  final hasOldPrice =
      (oldPrice ?? 0) > price && (oldPriceFormatted ?? '').isNotEmpty;
  String? discountText;
  if (hasOldPrice) {
    if ((discountFormatted ?? '').isNotEmpty) {
      discountText = discountFormatted;
    } else if ((discount ?? 0) > 0) {
      discountText = '$discount%';
    }
  }
  final priceText = priceFormatted ?? '';
  final image = (picture ?? '').isNotEmpty ? picture! : imageUrl;
  return PersonalizationProduct(
    id: id,
    name: name,
    price: priceText.isNotEmpty ? priceText : '$price $currency'.trim(),
    image: image.isEmpty ? null : NetworkImage(image),
    brand: brand.isEmpty ? null : brand,
    oldPrice: hasOldPrice ? oldPriceFormatted : null,
    discount: discountText == null
        ? null
        : (discountText.startsWith('-') ? discountText : '-$discountText'),
    actionText: actionText,
    url: url.isEmpty ? null : url,
    deeplink: _deeplink(android: deeplinkAndroid, ios: deeplinkIos),
  );
}

/// Диплинк своей платформы: на остальных платформах приложения нет — `null`.
String? _deeplink({required String? android, required String? ios}) {
  final link = switch (defaultTargetPlatform) {
    TargetPlatform.android => android,
    TargetPlatform.iOS => ios,
    _ => null,
  };
  return (link ?? '').isEmpty ? null : link;
}
