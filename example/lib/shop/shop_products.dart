import 'package:flutter/widgets.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

/// Card data of a catalog product (`getCategory`, `getProductInfo`). The kit's data
/// widgets map their products by the same rules, but keep that mapper to themselves,
/// so a host showing its own lists maps them like this:
/// - price: `price_formatted`, else "price currency";
/// - old price: `oldprice_formatted`, only when `oldprice` is above the price;
/// - discount badge: only next to a shown old price and for a positive number —
///   `discount`, else `discount_percent`. The text is `discount_formatted` when the
///   number came from `discount` (that is what it is made of), else `"N%"`,
///   with exactly one "-" in front;
/// - image: `picture` (the resized copy), else `image_url`.
/// The API has no rating, so the card has none either.
PersonalizationProduct shopCard(Product product, {String? actionText}) {
  final hasOldPrice =
      (product.oldPrice ?? 0) > product.price &&
      (product.oldPriceFormatted ?? '').isNotEmpty;
  final fromDiscount = (product.discount ?? 0) > 0;
  final number = fromDiscount
      ? product.discount
      : ((product.discountPercent ?? 0) > 0 ? product.discountPercent : null);
  String? discount;
  if (hasOldPrice && number != null) {
    final formatted = fromDiscount
        ? (product.discountFormatted ?? '').trim()
        : '';
    final text = formatted.isNotEmpty ? formatted : '$number%';
    discount = '-${text.replaceFirst(RegExp(r'^-+'), '')}';
  }
  final price = product.priceFormatted ?? '';
  final picture = product.picture ?? '';
  final image = picture.isNotEmpty ? picture : product.imageUrl;
  return PersonalizationProduct(
    id: product.id,
    name: product.name,
    price: price.isNotEmpty
        ? price
        : '${product.price} ${product.currency}'.trim(),
    image: image.isEmpty ? null : NetworkImage(image),
    brand: product.brand.isEmpty ? null : product.brand,
    oldPrice: hasOldPrice ? product.oldPriceFormatted : null,
    discount: discount,
    actionText: actionText,
    url: product.url.isEmpty ? null : product.url,
  );
}

/// Top-level categories (those without a parent) of a products listing, in the
/// order they come. The listing's own `categories` first; where a bridge does not
/// pass them yet (iOS until its next native release) they are collected from the
/// products: every product lists its whole category path, the top of it included.
List<ProductCategory> shopTopCategories(ProductsListResponse response) {
  final listed = _topLevel(response.categories);
  if (listed.isNotEmpty) return listed;
  return _topLevel([
    for (final product in response.products) ...product.categories,
  ]);
}

/// Parentless categories with an id and a name, each once.
List<ProductCategory> _topLevel(Iterable<ProductCategory> categories) {
  final seen = <String>{};
  return [
    for (final category in categories)
      if ((category.parentId ?? '').isEmpty &&
          category.id.isNotEmpty &&
          category.name.isNotEmpty &&
          seen.add(category.id))
        category,
  ];
}
