import '../json_number.dart';

/// Response from [PersonalizationSdk.searchFull].
///
/// Facets ([brands], [filters], [industrialFilters]) are filled when the native side
/// delivers them; an older native SDK leaves them empty.
///
/// Excluded Android-only response fields: clarification, collections, html,
/// priceMedian, priceRanges, requestsCount, searchQuery.
/// Excluded iOS-only response fields: redirect, queries.
class SearchFullResponse {
  final List<SearchProduct> products;
  final List<SearchCategory> categories;
  final int productsTotal;
  final SearchPriceRange? priceRange;
  final List<SearchLocation>? locations;

  /// Brand names found in the results (Android carries counts too, iOS only names).
  final List<String> brands;

  /// Shop facets keyed by name: value → product count.
  final Map<String, SearchFilter> filters;
  final SearchIndustrialFilters? industrialFilters;

  const SearchFullResponse({
    required this.products,
    required this.categories,
    required this.productsTotal,
    this.priceRange,
    this.locations,
    this.brands = const [],
    this.filters = const {},
    this.industrialFilters,
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
      brands: _parseBrands(json['brands']),
      filters: _parseFilters(json['filters']),
      industrialFilters: json['industrial_filters'] is Map
          ? SearchIndustrialFilters.fromJson(
              Map<String, dynamic>.from(json['industrial_filters'] as Map),
            )
          : null,
    );
  }
}

/// Brands arrive as `[{name, count}]` (Android) or `[name]` (iOS); both become names.
List<String> _parseBrands(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => e is Map ? e['name']?.toString() : e?.toString())
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .toList();
}

Map<String, SearchFilter> _parseFilters(dynamic raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.value is Map)
        entry.key.toString(): SearchFilter.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        ),
  };
}

/// One facet of a full search: how many products carry it and the count per value.
class SearchFilter {
  final int count;
  final Map<String, int> values;

  const SearchFilter({required this.count, required this.values});

  factory SearchFilter.fromJson(Map<String, dynamic> json) {
    final values = json['values'];
    return SearchFilter(
      count: toIntOrNull(json['count']) ?? 0,
      values: values is Map
          ? {
              for (final entry in values.entries)
                entry.key.toString(): toIntOrNull(entry.value) ?? 0,
            }
          : const {},
    );
  }
}

/// Fashion facets of a full search: colours and sizes with product counts.
class SearchIndustrialFilters {
  final List<String> colors;
  final List<String> fashionSizes;

  const SearchIndustrialFilters({
    this.colors = const [],
    this.fashionSizes = const [],
  });

  factory SearchIndustrialFilters.fromJson(Map<String, dynamic> json) {
    List<String> names(dynamic raw, String key) => raw is List
        ? raw
              .map((e) => e is Map ? e[key]?.toString() : null)
              .whereType<String>()
              .toList()
        : const [];
    return SearchIndustrialFilters(
      colors: names(json['colors'], 'color'),
      fashionSizes: names(json['fashion_sizes'], 'size'),
    );
  }
}

/// Search product — intersection of Android [com.personalization.api.responses.product.Product]
/// and iOS [Product] (from SearchResponse).
///
/// Excluded Android-only fields: _id, imageUrlHandle, urlHandle, categoryIds,
/// locationIds, categories (product-level category model differs from search-level).
/// Excluded iOS-only fields: barcode, model, deeplinkIos, oldPriceFull (and its
/// formatted variant), isNew, params.
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

  /// Resized copy of the main image (`picture`), the one to show in lists.
  final String? picture;

  /// Price before the discount (`oldprice`), 0 when there is none.
  final double oldPrice;
  final String? oldPriceFormatted;

  /// Discount in percent (`discount`), 0 when there is none.
  final int discount;
  final String? discountFormatted;

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
    this.picture,
    this.oldPrice = 0.0,
    this.oldPriceFormatted,
    this.discount = 0,
    this.discountFormatted,
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
      picture: json['picture'] as String?,
      oldPrice: toDoubleOrNull(json['oldprice']) ?? 0.0,
      oldPriceFormatted: json['oldprice_formatted'] as String?,
      discount: toIntOrNull(json['discount']) ?? 0,
      discountFormatted: json['discount_formatted'] as String?,
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
/// searchQuery, bookAuthor.
/// Excluded iOS-only fields: filters, industrialFilters, redirect, brands.
class SearchInstantResponse {
  final List<SearchProduct> products;
  final List<SearchCategory> categories;
  final int productsTotal;
  final List<SearchLocation>? locations;

  /// Phrases suggested for the typed text (`queries`).
  final List<SearchSuggest> queries;

  const SearchInstantResponse({
    required this.products,
    required this.categories,
    required this.productsTotal,
    this.locations,
    this.queries = const [],
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
      queries: _parseSuggests(json['queries']),
    );
  }
}

List<SearchSuggest> _parseSuggests(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => SearchSuggest.fromJson(Map<String, dynamic>.from(e)))
      .toList();
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
/// Excluded iOS-only fields: lastProducts.
class SearchBlankResponse {
  final List<SearchProduct> products;
  final List<SearchSuggest> suggests;

  /// The user's latest search phrases as the server remembers them.
  final List<SearchSuggest> lastQueries;
  final List<SearchSuggest> popularCategories;

  const SearchBlankResponse({
    required this.products,
    required this.suggests,
    this.lastQueries = const [],
    this.popularCategories = const [],
  });

  factory SearchBlankResponse.fromJson(Map<String, dynamic> json) {
    return SearchBlankResponse(
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => SearchProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      suggests: _parseSuggests(json['suggests']),
      lastQueries: _parseSuggests(json['last_queries']),
      popularCategories: _parseSuggests(json['popular_categories']),
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
