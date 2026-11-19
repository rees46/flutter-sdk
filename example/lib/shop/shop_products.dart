import 'package:flutter/widgets.dart';
import 'package:rees46_sdk/rees46_sdk.dart'
    hide Product, ProductCategory, ProductsListResponse;
import 'package:rees46_sdk/models.dart';

/// Card data of a catalog product (the namespaces' `Product`). The kit's data widgets
/// map their products by the same rules, but keep that mapper to themselves, so a
/// host showing its own lists maps them like this:
/// - price: `priceFormatted`, else "price currency";
/// - old price: `oldPriceFormatted`, only when `oldPrice` is above the price;
/// - discount badge: only next to a shown old price and for a positive
///   `discountPercent`, `discountFormatted` when there is one, else `"N%"`, with
///   exactly one "-" in front;
/// - image: `picture` (the resized copy), else `imageUrl`.
/// The API has no rating, so the card has none either.
PersonalizationProduct shopCard(Product product, {String? actionText}) {
  final hasOldPrice =
      (product.oldPrice ?? 0) > product.price &&
      (product.oldPriceFormatted ?? '').isNotEmpty;
  final percent = product.discountPercent ?? 0;
  String? discount;
  if (hasOldPrice && percent > 0) {
    final formatted = (product.discountFormatted ?? '').trim();
    final text = formatted.isNotEmpty ? formatted : '$percent%';
    discount = '-${text.replaceFirst(RegExp(r'^-+'), '')}';
  }
  final price = product.priceFormatted ?? '';
  final picture = product.picture ?? '';
  final image = picture.isNotEmpty ? picture : (product.imageUrl ?? '');
  final brand = product.brand ?? '';
  return PersonalizationProduct(
    id: product.id,
    name: product.name,
    price: price.isNotEmpty
        ? price
        : '${product.price} ${product.currency}'.trim(),
    image: image.isEmpty ? null : NetworkImage(image),
    brand: brand.isEmpty ? null : brand,
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
  final listed = _topLevel(response.categories ?? const []);
  if (listed.isNotEmpty) return listed;
  return _topLevel([
    for (final product in response.products) ...?product.categories,
  ]);
}

/// Parentless categories with an id and a name, each once.
List<ProductCategory> _topLevel(Iterable<ProductCategory> categories) {
  final seen = <String>{};
  return [
    for (final category in categories)
      if ((category.parentId ?? '').isEmpty &&
          category.id.isNotEmpty &&
          (category.name ?? '').isNotEmpty &&
          seen.add(category.id))
        category,
  ];
}
