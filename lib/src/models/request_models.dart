// The request models of the SDK contract. A field left null is not sent; a list goes
// as one string joined with commas, and an empty list is not sent. The native SDK
// checks them before any request and fails a wrong value with `invalidArgument`.

import 'values.dart';

/// What [ProductsApi.getList] asks for; without one, the first page of the whole
/// catalog.
class ProductsListRequest {
  const ProductsListRequest({
    this.categoryIds,
    this.brands,
    this.merchants,
    this.locations,
    this.priceMin,
    this.priceMax,
    this.filters,
    this.sortBy,
    this.sortDir,
    this.limit,
    this.page,
  });

  final List<String>? categoryIds;
  final List<String>? brands;

  /// For marketplaces; with [locations] they are looked for in those locations.
  final List<String>? merchants;

  /// Products in stock in these locations.
  final List<String>? locations;

  /// At least 0; the server drops the fraction.
  final double? priceMin;

  /// At least [priceMin]; the server drops the fraction.
  final double? priceMax;

  /// The shop's own facets: a product parameter → its values.
  final Map<String, List<String>>? filters;

  /// [SortBy.relevance] is only for a search: here it is `invalidArgument`.
  final SortBy? sortBy;
  final SortDirection? sortDir;

  /// From 1.
  final int? limit;

  /// From 1.
  final int? page;
}

/// What [ProductsApi.getCategory] asks for besides the category.
class CategoryRequest {
  const CategoryRequest({
    this.brands,
    this.locations,
    this.filters,
    this.priceMin,
    this.priceMax,
    this.sortBy,
    this.sortDir,
    this.limit,
    this.page,
  });

  final List<String>? brands;
  final List<String>? locations;

  /// The shop's own facets: a product parameter → its values.
  final Map<String, List<String>>? filters;
  final double? priceMin;
  final double? priceMax;

  /// [SortBy.relevance] is only for a search: here it is `invalidArgument`.
  final SortBy? sortBy;
  final SortDirection? sortDir;
  final int? limit;
  final int? page;
}

/// Where the customer is, for [RecommendationsApi.get].
class RecommendationRequest {
  const RecommendationRequest({
    this.itemId,
    this.categoryId,
    this.searchQuery,
    this.excludedItemIds,
    this.brands,
    this.locations,
    this.limit,
    this.extended = true,
    this.withLocations = false,
  });

  /// The product on screen.
  final String? itemId;

  /// The category on screen.
  final String? categoryId;

  /// The query of the search on screen.
  final String? searchQuery;
  final List<String>? excludedItemIds;
  final List<String>? brands;
  final List<String>? locations;

  /// From 1.
  final int? limit;

  /// Whole products; without it only their ids
  /// ([RecommendationResponse.itemIds]).
  final bool extended;

  /// The locations of each product; needs [extended].
  final bool withLocations;
}

/// The filters, order and page of [SearchApi.full].
class SearchFullRequest {
  const SearchFullRequest({
    this.categoryIds,
    this.brands,
    this.excludedBrands,
    this.merchants,
    this.excludedMerchants,
    this.locations,
    this.priceMin,
    this.priceMax,
    this.colors,
    this.fashionSizes,
    this.excludedItemIds,
    this.filters,
    this.sortBy,
    this.sortDir,
    this.disableClarification = false,
    this.categoryLimit,
    this.brandLimit,
    this.limit,
    this.page,
  });

  final List<String>? categoryIds;
  final List<String>? brands;
  final List<String>? excludedBrands;
  final List<String>? merchants;
  final List<String>? excludedMerchants;
  final List<String>? locations;
  final double? priceMin;
  final double? priceMax;
  final List<String>? colors;
  final List<String>? fashionSizes;
  final List<String>? excludedItemIds;

  /// The shop's own facets: a product parameter → its values.
  final Map<String, List<String>>? filters;
  final SortBy? sortBy;
  final SortDirection? sortDir;

  /// Turns the clarifying search off.
  final bool disableClarification;
  final int? categoryLimit;
  final int? brandLimit;
  final int? limit;
  final int? page;
}
