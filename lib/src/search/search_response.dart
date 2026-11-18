import '../json_number.dart';
import '../models/catalog_models.dart';
import '../recommendation/recommendation_response.dart' show ProductCategory;
import 'search_facets.dart';

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

  /// Product count per brand name, where the native side carries it (not iOS).
  final Map<String, int> brandCounts;

  /// Shop facets keyed by name: value → product count.
  final Map<String, SearchFilter> filters;
  final SearchIndustrialFilters? industrialFilters;

  /// The query after the fixes of the keyboard layout and typos (`search_query`).
  final String? searchQuery;
  final String? searchQueryOriginal;

  /// Whether the clarifying search worked (`clarification`).
  final bool? clarification;

  /// The price histogram (`price_ranges`).
  final List<PriceInterval> priceRanges;

  /// The median price (`price_median`).
  final double? priceMedian;

  const SearchFullResponse({
    required this.products,
    required this.categories,
    required this.productsTotal,
    this.priceRange,
    this.locations,
    this.brands = const [],
    this.brandCounts = const {},
    this.filters = const {},
    this.industrialFilters,
    this.searchQuery,
    this.searchQueryOriginal,
    this.clarification,
    this.priceRanges = const [],
    this.priceMedian,
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
      brands: parseBrandNames(json['brands']),
      brandCounts: parseFacetCounts(json['brands'], 'name'),
      filters: parseFacetFilters(json['filters']),
      industrialFilters: json['industrial_filters'] is Map
          ? SearchIndustrialFilters.fromJson(
              Map<String, dynamic>.from(json['industrial_filters'] as Map),
            )
          : null,
      searchQuery: toNonEmptyStringOrNull(json['search_query']),
      searchQueryOriginal: toNonEmptyStringOrNull(
        json['search_query_original'],
      ),
      clarification: toBoolOrNull(json['clarification']),
      priceRanges: parsePriceIntervals(json['price_ranges']),
      priceMedian: toDoubleOrNull(json['price_median']),
    );
  }
}

/// One facet of a full search: how many products carry it and the count per value.
class SearchFilter {
  final int count;
  final Map<String, int> values;

  /// The order of the facets (`priority`).
  final int? priority;

  /// The bounds of a numeric facet (`ranges.min`, `ranges.max`).
  final double? min;
  final double? max;

  const SearchFilter({
    required this.count,
    required this.values,
    this.priority,
    this.min,
    this.max,
  });

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
      priority: toIntOrNull(json['priority']),
      min: json['ranges'] is Map ? toDoubleOrNull(json['ranges']['min']) : null,
      max: json['ranges'] is Map ? toDoubleOrNull(json['ranges']['max']) : null,
    );
  }
}

/// Fashion facets of a full search: colours and sizes with product counts.
class SearchIndustrialFilters {
  final List<String> colors;
  final List<String> fashionSizes;

  /// Product count per colour and per size, where the answer carries one.
  final Map<String, int> colorCounts;
  final Map<String, int> fashionSizeCounts;

  const SearchIndustrialFilters({
    this.colors = const [],
    this.fashionSizes = const [],
    this.colorCounts = const {},
    this.fashionSizeCounts = const {},
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
      colorCounts: parseFacetCounts(json['colors'], 'color'),
      fashionSizeCounts: parseFacetCounts(json['fashion_sizes'], 'size'),
    );
  }
}

/// Search product — intersection of Android [com.personalization.api.responses.product.Product]
/// and iOS [Product] (from SearchResponse).
///
/// Excluded Android-only fields: _id, imageUrlHandle, urlHandle, categoryIds,
/// locationIds, categories (product-level category model differs from search-level).
/// Excluded iOS-only fields: barcode, model, oldPriceFull (and its formatted
/// variant), params.
///
/// The fields after [discountFormatted] are nullable: a bridge fills them only where
/// its native model carries them, see each field.
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

  /// Discount in percent as the shop computes it (`discount_percent`). Full search
  /// on Android only for now: the native product models drop it.
  final int? discountPercent;

  /// Android app link to the product (`deeplink_android`). Full search only for now,
  /// on Android: iOS and the instant and blank search models drop it.
  final String? deeplinkAndroid;

  /// iOS app link to the product (`deeplink_ios`). Full search on Android, every
  /// search on iOS; the Android instant and blank search models drop it.
  final String? deeplinkIos;

  /// The shop marks the product as new (`is_new`).
  final bool? isNew;

  /// The product's categories (`categories`).
  final List<ProductCategory> categories;

  /// The group of variants of the product (`group_id`).
  final String? groupId;

  /// The product's model (`model`).
  final String? model;

  /// The product's barcode (`barcode`).
  final String? barcode;

  /// The old price with kopecks (`oldprice_full`) and its display form.
  final double? oldPriceFull;
  final String? oldPriceFullFormatted;

  /// The rating (`rating`); the API sends it only when it is not 0.
  final int? rating;

  /// How many are in stock (`stock_quantity`).
  final int? stockQuantity;

  /// The ids of the product's categories (`category_ids`).
  final List<String>? categoryIds;

  /// The product's parameters (`params`).
  final List<ProductParam> params;

  /// The locations where the product is (`location_ids`).
  final List<String>? locationIds;

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
    this.discountPercent,
    this.deeplinkAndroid,
    this.deeplinkIos,
    this.isNew,
    this.categories = const [],
    this.groupId,
    this.model,
    this.barcode,
    this.oldPriceFull,
    this.oldPriceFullFormatted,
    this.rating,
    this.stockQuantity,
    this.categoryIds,
    this.params = const [],
    this.locationIds,
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
      discountPercent: toIntOrNull(json['discount_percent']),
      deeplinkAndroid: toNonEmptyStringOrNull(json['deeplink_android']),
      deeplinkIos: toNonEmptyStringOrNull(json['deeplink_ios']),
      isNew: toBoolOrNull(json['is_new']),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => ProductCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      groupId: toNonEmptyStringOrNull(json['group_id']),
      model: toNonEmptyStringOrNull(json['model']),
      barcode: toNonEmptyStringOrNull(json['barcode']),
      oldPriceFull: toDoubleOrNull(json['oldprice_full']),
      oldPriceFullFormatted: toNonEmptyStringOrNull(
        json['oldprice_full_formatted'],
      ),
      rating: toIntOrNull(json['rating']),
      stockQuantity: toIntOrNull(json['stock_quantity']),
      categoryIds: toStringListOrNull(json['category_ids']),
      params: parseProductParams(json['params']),
      locationIds: toStringListOrNull(json['location_ids']),
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

  /// The query after the fixes of the keyboard layout and typos (`search_query`).
  final String? searchQuery;
  final String? searchQueryOriginal;

  /// Whether the clarifying search worked (`clarification`).
  final bool? clarification;

  /// Where the shop sends this query instead of the results.
  final SearchRedirect? redirect;

  const SearchInstantResponse({
    required this.products,
    required this.categories,
    required this.productsTotal,
    this.locations,
    this.queries = const [],
    this.searchQuery,
    this.searchQueryOriginal,
    this.clarification,
    this.redirect,
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
      searchQuery: toNonEmptyStringOrNull(json['search_query']),
      searchQueryOriginal: toNonEmptyStringOrNull(
        json['search_query_original'],
      ),
      clarification: toBoolOrNull(json['clarification']),
      redirect: json['search_query_redirects'] is Map
          ? SearchRedirect(
              query: toNonEmptyStringOrNull(
                json['search_query_redirects']['query'],
              ),
              url: toNonEmptyStringOrNull(
                json['search_query_redirects']['redirect_link'],
              ),
              deeplink: toNonEmptyStringOrNull(
                json['search_query_redirects']['deeplink'],
              ),
            )
          : null,
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

  /// The category's alias (`alias`).
  final String? alias;

  /// The category's depth (`level`), when the answer has it.
  final int? level;

  const SearchCategory({
    required this.id,
    required this.name,
    this.url,
    this.parentId,
    this.count,
    this.alias,
    this.level,
  });

  factory SearchCategory.fromJson(Map<String, dynamic> json) {
    return SearchCategory(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String?,
      parentId: json['parent'] as String?,
      count: toIntOrNull(json['count']),
      alias: toNonEmptyStringOrNull(json['alias']),
      level: toIntOrNull(json['level']),
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

  /// `true` — [products] are the ones the customer viewed lately; `false` — the
  /// popular ones (`last_products`).
  final bool lastProducts;

  /// Popular brands and links (`popular_brands`, `popular_links`).
  final List<SearchSuggest> popularBrands;
  final List<SearchSuggest> popularLinks;

  const SearchBlankResponse({
    required this.products,
    required this.suggests,
    this.lastQueries = const [],
    this.popularCategories = const [],
    this.lastProducts = false,
    this.popularBrands = const [],
    this.popularLinks = const [],
  });

  factory SearchBlankResponse.fromJson(Map<String, dynamic> json) {
    return SearchBlankResponse(
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => SearchProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      suggests: _parseSuggests(json['suggests']),
      lastQueries: _parseSuggests(json['last_queries']),
      popularCategories: _parseSuggests(json['popular_categories']),
      lastProducts: toBoolOrNull(json['last_products']) ?? false,
      popularBrands: _parseSuggests(json['popular_brands']),
      popularLinks: _parseSuggests(json['popular_links']),
    );
  }
}

/// A search suggestion entry returned by [PersonalizationSdk.searchBlank].
///
/// Excluded iOS-only fields: deeplinkIos.
class SearchSuggest {
  final String name;
  final String url;

  /// How well a suggested query matches (`score`), when the answer has it.
  final double? score;

  const SearchSuggest({required this.name, required this.url, this.score});

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
