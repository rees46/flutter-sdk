/// Typed response for [PersonalizationSdk.getRecommendation].
///
/// Contains only fields present in **both** Android and iOS native SDK models.
///
/// Fields available in the native Android SDK but excluded from this contract:
/// - `html` — rendered block HTML (`GetExtendedRecommendationResponse.html`).
/// - `id` — block ID (`GetExtendedRecommendationResponse.id`).
/// - `Product.imageUrlHandle`, `Product.urlHandle` — URL handle variants.
/// - `Product.categoryIds` — flat list of category IDs (use `categories` instead).
/// - `Product.locationIds` — flat list of location IDs (use `locations` on iOS).
///
/// Fields available in the native iOS SDK but excluded from this contract:
/// - `Product.barcode`, `Product.model`, `Product.deeplinkIos`.
/// - `Product.oldPrice`, `Product.oldPriceFull`, `Product.oldPriceFormatted`,
///   `Product.oldPriceFullFormatted` — original price before discount.
/// - `Product.discount`, `Product.rating`.
/// - `Product.fashionSizes`, `Product.fashionColors`, `Product.fashionOriginalSizes`.
/// - `Product.locations` — full location objects (Android only exposes IDs).
/// - `Product.paramsRaw` — raw extra params from the API response.
/// - `RecommenderResponse.locations` — top-level locations list.
///
/// To unlock platform-specific fields, extend the corresponding native SDK
/// model and re-generate the Flutter bridge.
class RecommendationResponse {
  final String title;
  final List<RecommendedProduct> products;

  const RecommendationResponse({required this.title, required this.products});

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['recommends'] as List<dynamic>? ?? [];
    return RecommendationResponse(
      title: json['title'] as String? ?? '',
      products: rawProducts
          .map((e) => RecommendedProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A single recommended product.
///
/// See [RecommendationResponse] for the full list of excluded platform-specific fields.
class RecommendedProduct {
  final String id;
  final String name;
  final String brand;
  final String description;

  /// Original image URL (`image_url` in API response).
  final String imageUrl;

  /// Resized/thumbnail image URL (`picture` in API response).
  final String resizedImageUrl;

  /// Map of pre-resized image URLs keyed by pixel size string
  /// e.g. `{"120": "...", "310": "..."}` (`image_url_resized` in API response).
  final Map<String, String> resizedImages;

  final String url;
  final List<ProductCategory> categories;

  final double price;
  final double priceFull;
  final String? priceFormatted;
  final String? priceFullFormatted;
  final String currency;
  final int salesRate;
  final double relativeSalesRate;

  const RecommendedProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.description,
    required this.imageUrl,
    required this.resizedImageUrl,
    required this.resizedImages,
    required this.url,
    required this.categories,
    required this.price,
    required this.priceFull,
    this.priceFormatted,
    this.priceFullFormatted,
    required this.currency,
    required this.salesRate,
    required this.relativeSalesRate,
  });

  factory RecommendedProduct.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'] as List<dynamic>? ?? [];
    final rawResized = json['image_url_resized'];
    return RecommendedProduct(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      resizedImageUrl: json['picture'] as String? ?? '',
      resizedImages: rawResized is Map
          ? rawResized.cast<String, String>()
          : const {},
      url: json['url'] as String? ?? '',
      categories: rawCategories
          .map((e) => ProductCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      priceFull: (json['price_full'] as num?)?.toDouble() ?? 0.0,
      priceFormatted: json['price_formatted'] as String?,
      priceFullFormatted: json['price_full_formatted'] as String?,
      currency: json['currency'] as String? ?? '',
      salesRate: json['sales_rate'] as int? ?? 0,
      relativeSalesRate:
          (json['relative_sales_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Category attached to a [RecommendedProduct].
///
/// Fields available in the native Android SDK but excluded:
/// - `level`, `nameWithParent`, `urlHandle`.
///
/// Fields available in the native iOS SDK but excluded:
/// - `alias`, `count`.
class ProductCategory {
  final String id;
  final String name;
  final String? parentId;
  final String? url;

  const ProductCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.url,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      parentId: json['parent_id'] as String?,
      url: json['url'] as String?,
    );
  }
}
