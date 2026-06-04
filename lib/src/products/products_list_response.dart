import '../recommendation/recommendation_response.dart' show ProductCategory;

export '../recommendation/recommendation_response.dart' show ProductCategory;

/// Response from [PersonalizationSdk.getProductsList].
///
/// Excluded Android-only fields: brands (`List<Brand>`), categories
/// (`List<Category>`), filters (`List<Filter>`), priceRanges, priceMedian.
/// Excluded iOS-only fields: brands (`[String]`), filters (`[String: Filter]`).
class ProductsListResponse {
  final List<Product> products;
  final int productsTotal;
  final PriceRange? priceRange;

  const ProductsListResponse({
    required this.products,
    required this.productsTotal,
    this.priceRange,
  });

  factory ProductsListResponse.fromJson(Map<String, dynamic> json) {
    return ProductsListResponse(
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
      productsTotal: json['products_total'] as int? ?? 0,
      priceRange: json['price_range'] == null
          ? null
          : PriceRange.fromJson(json['price_range'] as Map<String, dynamic>),
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
/// Excluded Android-only fields: _id, imageUrlHandle, urlHandle, picture,
/// categoryIds, locationIds.
/// Excluded iOS-only fields: model, barcode, deeplinkIos, resizedImageUrl,
/// oldPrice / oldPriceFull (and formatted variants), discount, isNew, params.
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
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      url: json['url'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      priceFull: (json['price_full'] as num?)?.toDouble() ?? 0.0,
      priceFormatted: json['price_formatted'] as String?,
      priceFullFormatted: json['price_full_formatted'] as String?,
      currency: json['currency'] as String? ?? '',
      salesRate: json['sales_rate'] as int? ?? 0,
      relativeSalesRate:
          (json['relative_sales_rate'] as num?)?.toDouble() ?? 0.0,
      resizedImages: _parseResizedImages(json['image_url_resized']),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => ProductCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
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
      min: (json['min'] as num?)?.toDouble() ?? 0.0,
      max: (json['max'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
