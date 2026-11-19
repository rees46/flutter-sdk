// The catalog models of the contract (products.md, search.md, recommendations.md,
// collections.md): what the namespaces `products`, `collections`,
// `recommendations` and `search` answer with. A field the answer does not have is
// `null`, not `""` or `0`.
//
// Several share their names with the released classes the deprecated methods
// return (`Product`, `SearchFullResponse`, …), which keep their 1.6.4 shape until
// those methods go. So these are exported from `package:rees46_sdk/models.dart`,
// not from the package's main library.

import '../products/products_list_response.dart' show PriceRange;
import 'catalog_models.dart';

export '../products/product_counters_response.dart';
export '../products/products_list_response.dart' show PriceRange;
export 'catalog_models.dart' show PriceInterval, ProductParam, SearchRedirect;

/// A product, in every answer: a card, a listing, a category, a collection, a
/// recommendation block, a search. `id`, `name`, `url`, `price` and `currency` are
/// always there.
class Product {
  const Product({
    required this.id,
    this.groupId,
    required this.name,
    this.brand,
    this.model,
    this.description,
    this.barcode,
    required this.url,
    this.deeplinkAndroid,
    this.deeplinkIos,
    this.imageUrl,
    this.picture,
    this.resizedImages,
    required this.price,
    this.priceFormatted,
    this.priceFull,
    this.priceFullFormatted,
    this.oldPrice,
    this.oldPriceFormatted,
    this.oldPriceFull,
    this.oldPriceFullFormatted,
    required this.currency,
    this.discountPercent,
    this.discountFormatted,
    this.salesRate,
    this.relativeSalesRate,
    this.rating,
    this.isNew = false,
    this.stockQuantity,
    this.categoryIds,
    this.categories,
    this.params,
    this.locationIds,
  });

  final String id;

  /// The group of variants (`group_id`).
  final String? groupId;
  final String name;
  final String? brand;
  final String? model;
  final String? description;
  final String? barcode;
  final String url;
  final String? deeplinkAndroid;
  final String? deeplinkIos;

  /// The original image (`image_url`).
  final String? imageUrl;

  /// The image of the size the request asked for (`picture`).
  final String? picture;

  /// Size (`"120"` … `"520"`, `"original"`) → image (`image_url_resized`).
  final Map<String, String>? resizedImages;
  final double price;
  final String? priceFormatted;

  /// The price with kopecks (`price_full`).
  final double? priceFull;
  final String? priceFullFormatted;

  /// The price before the discount (`oldprice`); `null` without one.
  final double? oldPrice;
  final String? oldPriceFormatted;
  final double? oldPriceFull;
  final String? oldPriceFullFormatted;
  final String currency;

  /// The discount in percent (`discount_percent`, else a numeric `discount`).
  final int? discountPercent;
  final String? discountFormatted;
  final int? salesRate;
  final double? relativeSalesRate;

  /// The rating; the API sends it only when it is not 0.
  final int? rating;

  /// Whether the product is new (`is_new`): the API sends it only when `true`.
  final bool isNew;
  final int? stockQuantity;
  final List<String>? categoryIds;
  final List<ProductCategory>? categories;
  final List<ProductParam>? params;

  /// The locations where the product is (`location_ids`), with `withLocations`.
  final List<String>? locationIds;
}

/// A category of a product, and a category in the facets of a listing or a
/// search.
class ProductCategory {
  const ProductCategory({
    required this.id,
    this.name,
    this.url,
    this.parentId,
    this.level,
    this.count,
    this.alias,
  });

  final String id;
  final String? name;
  final String? url;

  /// `parent_id`; `parent` in the facets.
  final String? parentId;

  /// Only for a product's categories.
  final int? level;

  /// Only in the facets: how many products the category has there.
  final int? count;

  /// Only in the facets.
  final String? alias;
}

/// A location of the shop.
class Location {
  const Location({required this.id, required this.name, this.type});

  final String id;
  final String name;
  final String? type;
}

/// A brand in the facets and how many products it has there.
class Brand {
  const Brand({required this.name, required this.count});

  final String name;
  final int count;
}

/// A facet: one parameter of the products in the filters.
class SearchFilter {
  const SearchFilter({
    this.count,
    this.priority,
    this.values,
    this.min,
    this.max,
  });

  /// How many products have the parameter.
  final int? count;

  /// The order of the facets.
  final int? priority;

  /// Value → how many products have it (a facet of values).
  final Map<String, int>? values;

  /// The bounds of a numeric facet (`ranges.min`, `ranges.max`).
  final double? min;
  final double? max;
}

/// The fashion facets of a search.
class IndustrialFilters {
  const IndustrialFilters({this.colors, this.fashionSizes});

  final List<ColorFilter>? colors;
  final List<SizeFilter>? fashionSizes;
}

class ColorFilter {
  const ColorFilter({required this.color, required this.count});

  final String color;
  final int count;
}

class SizeFilter {
  const SizeFilter({required this.size, required this.count});

  final String size;
  final int count;
}

/// A page of the catalog's listing with its facets ([ProductsApi.getList]).
class ProductsListResponse {
  const ProductsListResponse({
    this.productsTotal,
    required this.products,
    this.categories,
    this.brands,
    this.locations,
    this.filters,
    this.industrialFilters,
    this.priceRange,
    this.priceRanges,
    this.priceMedian,
  });

  final int? productsTotal;
  final List<Product> products;
  final List<ProductCategory>? categories;
  final List<Brand>? brands;
  final List<Location>? locations;

  /// Parameter name → facet.
  final Map<String, SearchFilter>? filters;

  /// Only a search sends them.
  final IndustrialFilters? industrialFilters;
  final PriceRange? priceRange;
  final List<PriceInterval>? priceRanges;
  final double? priceMedian;
}

/// A category's listing ([ProductsApi.getCategory]).
class CategoryResponse {
  const CategoryResponse({
    this.productsTotal,
    required this.products,
    this.categories,
    this.brands,
    this.filters,
    this.priceRange,
    this.priceRanges,
    this.priceMedian,
  });

  final int? productsTotal;
  final List<Product> products;
  final List<ProductCategory>? categories;
  final List<Brand>? brands;
  final Map<String, SearchFilter>? filters;
  final PriceRange? priceRange;
  final List<PriceInterval>? priceRanges;
  final double? priceMedian;
}

/// A collection's products ([CollectionsApi.get]).
class CollectionResponse {
  const CollectionResponse({required this.products});

  final List<Product> products;
}

/// A recommendation block ([RecommendationsApi.get]).
class RecommendationResponse {
  const RecommendationResponse({
    this.id,
    this.title,
    this.link,
    required this.products,
    required this.itemIds,
  });

  /// The block's id.
  final int? id;
  final String? title;

  /// The link of the title, when the block has one.
  final String? link;

  /// The products; a block on pause has none.
  final List<Product> products;

  /// The ids of the products.
  final List<String> itemIds;
}

/// A suggested or earlier query; [url] opens the full search of it.
class Query {
  const Query({required this.name, this.url, this.score});

  final String name;
  final String? url;

  /// Only in the queries of an instant search.
  final double? score;
}

/// A popular category, brand or link.
class PopularItem {
  const PopularItem({required this.name, required this.url});

  final String name;
  final String url;
}

/// What an empty search field shows ([SearchApi.blank]).
class SearchBlankResponse {
  const SearchBlankResponse({
    required this.products,
    this.lastProducts = false,
    this.lastQueries,
    this.suggests,
    this.popularCategories,
    this.popularBrands,
    this.popularLinks,
  });

  final List<Product> products;

  /// `true`: [products] are the ones the customer viewed lately; `false`: popular
  /// ones.
  final bool lastProducts;
  final List<Query>? lastQueries;
  final List<Query>? suggests;
  final List<PopularItem>? popularCategories;
  final List<PopularItem>? popularBrands;
  final List<PopularItem>? popularLinks;
}

/// An instant search ([SearchApi.instant]).
class SearchInstantResponse {
  const SearchInstantResponse({
    this.searchQuery,
    this.searchQueryOriginal,
    this.clarification,
    this.productsTotal,
    required this.products,
    this.categories,
    this.queries,
    this.locations,
    this.redirect,
  });

  /// The query after the layout and typos were fixed.
  final String? searchQuery;
  final String? searchQueryOriginal;

  /// Whether the clarifying search worked.
  final bool? clarification;
  final int? productsTotal;
  final List<Product> products;
  final List<ProductCategory>? categories;

  /// Suggested queries.
  final List<Query>? queries;
  final List<Location>? locations;

  /// The page the shop opens for this query instead of the results.
  final SearchRedirect? redirect;
}

/// A full search ([SearchApi.full]).
class SearchFullResponse {
  const SearchFullResponse({
    this.searchQuery,
    this.searchQueryOriginal,
    this.clarification,
    this.productsTotal,
    required this.products,
    this.categories,
    this.brands,
    this.locations,
    this.filters,
    this.industrialFilters,
    this.priceRange,
    this.priceRanges,
    this.priceMedian,
  });

  final String? searchQuery;
  final String? searchQueryOriginal;
  final bool? clarification;
  final int? productsTotal;
  final List<Product> products;
  final List<ProductCategory>? categories;
  final List<Brand>? brands;
  final List<Location>? locations;
  final Map<String, SearchFilter>? filters;
  final IndustrialFilters? industrialFilters;
  final PriceRange? priceRange;
  final List<PriceInterval>? priceRanges;
  final double? priceMedian;
}
