import 'dart:convert';

/// Parameters for [PersonalizationSdk.getProductsList].
///
/// All fields are optional — only non-null/non-empty values are forwarded.
/// Both Android and iOS accept the same parameter set.
///
/// [filters]: key → list of allowed values, e.g. `{'color': ['red', 'blue']}`.
class ProductsListParams {
  final String? brands;
  final String? merchants;
  final String? categories;
  final String? locations;
  final int? limit;
  final int? page;
  final Map<String, List<String>>? filters;

  const ProductsListParams({
    this.brands,
    this.merchants,
    this.categories,
    this.locations,
    this.limit,
    this.page,
    this.filters,
  });

  String toJson() => jsonEncode({
    if (brands != null) 'brands': brands,
    if (merchants != null) 'merchants': merchants,
    if (categories != null) 'categories': categories,
    if (locations != null) 'locations': locations,
    if (limit != null) 'limit': limit,
    if (page != null) 'page': page,
    if (filters != null && filters!.isNotEmpty) 'filters': filters,
  });
}
