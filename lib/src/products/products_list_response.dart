import '../recommendation/recommendation_response.dart' show ProductCategory;
import '../json_number.dart';
import '../search/search_facets.dart';
import '../search/search_response.dart' show SearchFilter;

export '../recommendation/recommendation_response.dart' show ProductCategory;

/// Response from [PersonalizationSdk.getProductsList].
///
/// Excluded Android-only fields: priceRanges, priceMedian.
class ProductsListResponse {
  final List<Product> products;
  final int productsTotal;
  final PriceRange? priceRange;

  /// Brand names found in the listing (Android carries counts too, iOS only names).
  final List<String> brands;

  /// Shop facets keyed by name: value → product count.
  final Map<String, SearchFilter> filters;

  /// Categories of the listing (`categories`); the top-level ones have no
  /// [ProductCategory.parentId].
  final List<ProductCategory> categories;

  const ProductsListResponse({
    required this.products,
    required this.productsTotal,
    this.priceRange,
    this.brands = const [],
    this.filters = const {},
    this.categories = const [],
  });

  factory ProductsListResponse.fromJson(Map<String, dynamic> json) {
    return ProductsListResponse(
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
      productsTotal: toIntOrNull(json['products_total']) ?? 0,
      priceRange: json['price_range'] == null
          ? null
          : PriceRange.fromJson(json['price_range'] as Map<String, dynamic>),
      brands: parseBrandNames(json['brands']),
      filters: parseFacetFilters(json['filters']),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => ProductCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// A product returned by [PersonalizationSdk.getProductsList].
///
/// Intersection of Android [com.personalization.api.responses.product.Product]
/// and iOS [ProductInfo].
///
/// Note: iOS maps product ID from JSON key "uniqid"; the bridge normalises
/// this to "id" so Dart always reads from "id".
///
/// Excluded Android-only fields: _id, imageUrlHandle, urlHandle, categoryIds,
/// locationIds.
/// Excluded iOS-only fields: model, barcode, oldPriceFull (and its formatted
/// variant), params.
///
/// The fields after [categories] are nullable: the API sends them for every product
/// listing, but a bridge fills only those its native model carries. Android hands
/// [PersonalizationSdk.getProductInfo] and [PersonalizationSdk.getProductsList] over
/// as raw JSON, so they carry all of them; the rest is noted per field.
class Product {
  final String id;
  final String name;
  final String brand;
  final String description;
  final String imageUrl;
  final String url;
  final double price;
  final double priceFull;
  final String? priceFormatted;
  final String? priceFullFormatted;
  final String currency;
  final int salesRate;
  final double relativeSalesRate;
  final Map<String, String> resizedImages;
  final List<ProductCategory> categories;

  /// Resized copy of the main image (`picture`), the one to show in lists.
  final String? picture;

  /// Price before the discount (`oldprice`). Not in iOS categories and collections.
  final double? oldPrice;
  final String? oldPriceFormatted;

  /// Discount (`discount`) and its display form (`discount_formatted`, e.g. `6%`).
  /// The display form is not on iOS; neither is in iOS categories and collections.
  final int? discount;
  final String? discountFormatted;

  /// Discount in percent as the shop computes it (`discount_percent`). Android
  /// product info and products list only for now.
  final int? discountPercent;

  /// Android app link to the product (`deeplink_android`). Android product info and
  /// products list only for now.
  final String? deeplinkAndroid;

  /// iOS app link to the product (`deeplink_ios`). Not in categories and collections
  /// for now.
  final String? deeplinkIos;

  /// The shop marks the product as new (`is_new`). Not in iOS categories and
  /// collections.
  final bool? isNew;

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.description,
    required this.imageUrl,
    required this.url,
    required this.price,
    required this.priceFull,
    this.priceFormatted,
    this.priceFullFormatted,
    required this.currency,
    required this.salesRate,
    required this.relativeSalesRate,
    required this.resizedImages,
    required this.categories,
    this.picture,
    this.oldPrice,
    this.oldPriceFormatted,
    this.discount,
    this.discountFormatted,
    this.discountPercent,
    this.deeplinkAndroid,
    this.deeplinkIos,
    this.isNew,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      url: json['url'] as String? ?? '',
      price: toDoubleOrNull(json['price']) ?? 0.0,
      priceFull: toDoubleOrNull(json['price_full']) ?? 0.0,
      priceFormatted: json['price_formatted'] as String?,
      priceFullFormatted: json['price_full_formatted'] as String?,
      currency: json['currency'] as String? ?? '',
      salesRate: toIntOrNull(json['sales_rate']) ?? 0,
      relativeSalesRate: toDoubleOrNull(json['relative_sales_rate']) ?? 0.0,
      resizedImages: _parseResizedImages(json['image_url_resized']),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => ProductCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      picture: toNonEmptyStringOrNull(json['picture']),
      oldPrice: toDoubleOrNull(json['oldprice']),
      oldPriceFormatted: toNonEmptyStringOrNull(json['oldprice_formatted']),
      // `false` in product info for a product without a discount.
      discount: toIntOrNull(json['discount']),
      discountFormatted: toNonEmptyStringOrNull(json['discount_formatted']),
      discountPercent: toIntOrNull(json['discount_percent']),
      deeplinkAndroid: toNonEmptyStringOrNull(json['deeplink_android']),
      deeplinkIos: toNonEmptyStringOrNull(json['deeplink_ios']),
      isNew: toBoolOrNull(json['is_new']),
    );
  }
}

Map<String, String> _parseResizedImages(dynamic raw) {
  if (raw is Map) {
    return Map<String, String>.fromEntries(
      raw.entries.map(
        (e) => MapEntry(e.key.toString(), e.value?.toString() ?? ''),
      ),
    );
  }
  return {};
}

/// Price range for a products list response.
class PriceRange {
  final double min;
  final double max;

  const PriceRange({required this.min, required this.max});

  factory PriceRange.fromJson(Map<String, dynamic> json) {
    return PriceRange(
      min: toDoubleOrNull(json['min']) ?? 0.0,
      max: toDoubleOrNull(json['max']) ?? 0.0,
    );
  }
}
