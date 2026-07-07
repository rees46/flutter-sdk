import '../json_number.dart';

/// Response from [PersonalizationSdk.searchFull].
///
/// Excluded Android-only response fields: brands (`List<Brand>`), clarification,
/// collections, html, priceMedian, priceRanges, requestsCount, searchQuery.
/// Excluded iOS-only response fields: filters, industrialFilters, redirect, queries.
class SearchFullResponse {
  final List<SearchProduct> products;
  final List<SearchCategory> categories;
  final int productsTotal;
  final SearchPriceRange? priceRange;
  final List<SearchLocation>? locations;

  const SearchFullResponse({
    required this.products,
    required this.categories,
    required this.productsTotal,
    this.priceRange,
    this.locations,
  });

  factory SearchFullResponse.fromJson(Map<String, dynamic> json) {
    return SearchFullResponse(
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => SearchProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => SearchCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      productsTotal: toIntOrNull(json['products_total']) ?? 0,
      priceRange: json['price_range'] == null
          ? null
          : SearchPriceRange.fromJson(
              json['price_range'] as Map<String, dynamic>,
            ),
      locations: (json['locations'] as List<dynamic>?)
          ?.map((e) => SearchLocation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Search product — intersection of Android [com.personalization.api.responses.product.Product]
/// and iOS [Product] (from SearchResponse).
///
/// Excluded Android-only fields: _id, imageUrlHandle, urlHandle, picture, categoryIds,
/// locationIds, categories (product-level category model differs from search-level).
/// Excluded iOS-only fields: barcode, model, deeplinkIos, oldPrice / oldPriceFull
/// (and their formatted variants), discount, isNew, params.
class SearchProduct {
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

  /// Resized image URLs keyed by size string (e.g. "120", "520").
  /// JSON key: "image_url_resized" on both platforms.
  final Map<String, String> resizedImages;

  const SearchProduct({
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
  });

  factory SearchProduct.fromJson(Map<String, dynamic> json) {
    return SearchProduct(
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
    );
  }
}

/// Response from [PersonalizationSdk.searchInstant].
///
/// Subset of [SearchFullResponse] — no [priceRange] (not present in Android
/// `SearchInstantResponse`). Shares the same [SearchProduct], [SearchCategory],
/// and [SearchLocation] models.
///
/// Excluded Android-only fields: clarification, collections, html, requestsCount,
/// searchQuery, bookAuthor, queries.
/// Excluded iOS-only fields: filters, industrialFilters, redirect, queries, brands.
class SearchInstantResponse {
  final List<SearchProduct> products;
  final List<SearchCategory> categories;
  final int productsTotal;
  final List<SearchLocation>? locations;

  const SearchInstantResponse({
    required this.products,
    required this.categories,
    required this.productsTotal,
    this.locations,
  });

  factory SearchInstantResponse.fromJson(Map<String, dynamic> json) {
    return SearchInstantResponse(
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => SearchProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => SearchCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      productsTotal: toIntOrNull(json['products_total']) ?? 0,
      locations: (json['locations'] as List<dynamic>?)
          ?.map((e) => SearchLocation.fromJson(e as Map<String, dynamic>))
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

/// Top-level search category — intersection of Android and iOS search category models.
///
/// Note: [parentId] is decoded from JSON key "parent" (same on both platforms).
/// Android field name: `parent`; iOS field name: `parentId` — both use JSON key "parent".
///
/// Excluded Android-only fields: urlHandle.
/// Excluded iOS-only fields: alias.
class SearchCategory {
  final String id;
  final String name;
  final String? url;
  final String? parentId;
  final int? count;

  const SearchCategory({
    required this.id,
    required this.name,
    this.url,
    this.parentId,
    this.count,
  });

  factory SearchCategory.fromJson(Map<String, dynamic> json) {
    return SearchCategory(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String?,
      parentId: json['parent'] as String?,
      count: toIntOrNull(json['count']),
    );
  }
}

class SearchPriceRange {
  final double min;
  final double max;

  const SearchPriceRange({required this.min, required this.max});

  factory SearchPriceRange.fromJson(Map<String, dynamic> json) {
    return SearchPriceRange(
      min: toDoubleOrNull(json['min']) ?? 0.0,
      max: toDoubleOrNull(json['max']) ?? 0.0,
    );
  }
}

/// Response from [PersonalizationSdk.searchBlank].
///
/// Contains trending/popular products and search suggestions configured for the shop.
///
/// Excluded Android-only fields: html.
/// Excluded iOS-only fields: lastQueries, lastProducts.
class SearchBlankResponse {
  final List<SearchProduct> products;
  final List<SearchSuggest> suggests;

  const SearchBlankResponse({required this.products, required this.suggests});

  factory SearchBlankResponse.fromJson(Map<String, dynamic> json) {
    return SearchBlankResponse(
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => SearchProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      suggests: (json['suggests'] as List<dynamic>? ?? [])
          .map((e) => SearchSuggest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A search suggestion entry returned by [PersonalizationSdk.searchBlank].
///
/// Excluded iOS-only fields: deeplinkIos.
class SearchSuggest {
  final String name;
  final String url;

  const SearchSuggest({required this.name, required this.url});

  factory SearchSuggest.fromJson(Map<String, dynamic> json) {
    return SearchSuggest(
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

/// Search location — present in both Android and iOS search responses.
class SearchLocation {
  final String id;
  final String name;
  final String? type;

  const SearchLocation({required this.id, required this.name, this.type});

  factory SearchLocation.fromJson(Map<String, dynamic> json) {
    return SearchLocation(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String?,
    );
  }
}
