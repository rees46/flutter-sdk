import 'dart:convert';

/// Parameters for [PersonalizationSdk.searchFull].
///
/// All fields are optional — only non-null/non-empty values are forwarded to the native SDK.
///
/// Cross-platform notes:
/// - [categories]: list of category ID strings. Android joins them with commas;
///   iOS converts them to integers internally.
/// - [page]: maps to Android `PAGE` param and iOS `offset` param.
///
/// Excluded Android-only params: `extended`, `exclude`, `excludedMerchants`,
/// `noClarification`, `filters` (complex SearchFilters object).
class SearchParams {
  final int? limit;
  final int? page;
  final int? categoryLimit;
  final int? brandLimit;
  final List<String>? categories;
  final String? sortBy;
  final String? sortDir;
  final String? locations;
  final List<String>? excludedBrands;
  final String? brands;
  final double? priceMin;
  final double? priceMax;
  final List<String>? colors;
  final List<String>? fashionSizes;

  const SearchParams({
    this.limit,
    this.page,
    this.categoryLimit,
    this.brandLimit,
    this.categories,
    this.sortBy,
    this.sortDir,
    this.locations,
    this.excludedBrands,
    this.brands,
    this.priceMin,
    this.priceMax,
    this.colors,
    this.fashionSizes,
  });

  String toJson() => jsonEncode({
    if (limit != null) 'limit': limit,
    if (page != null) 'page': page,
    if (categoryLimit != null) 'category_limit': categoryLimit,
    if (brandLimit != null) 'brand_limit': brandLimit,
    if (categories != null && categories!.isNotEmpty) 'categories': categories,
    if (sortBy != null) 'sort_by': sortBy,
    if (sortDir != null) 'sort_dir': sortDir,
    if (locations != null) 'locations': locations,
    if (excludedBrands != null && excludedBrands!.isNotEmpty)
      'excluded_brands': excludedBrands,
    if (brands != null) 'brands': brands,
    if (priceMin != null) 'price_min': priceMin,
    if (priceMax != null) 'price_max': priceMax,
    if (colors != null && colors!.isNotEmpty) 'colors': colors,
    if (fashionSizes != null && fashionSizes!.isNotEmpty)
      'fashion_sizes': fashionSizes,
  });
}

/// Parameters for [PersonalizationSdk.searchInstant].
///
/// Android passes these directly to `searchManager.searchInstant()`.
/// iOS passes them to `sdk.search()` with the remaining fields set to nil.
///
/// Excluded Android-only params: `excludedMerchants`.
class SearchInstantParams {
  final String? locations;
  final List<String>? excludedBrands;

  const SearchInstantParams({this.locations, this.excludedBrands});

  String toJson() => jsonEncode({
    if (locations != null) 'locations': locations,
    if (excludedBrands != null && excludedBrands!.isNotEmpty)
      'excluded_brands': excludedBrands,
  });
}
