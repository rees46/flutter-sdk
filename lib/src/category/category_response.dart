import '../models/catalog_models.dart';
import '../products/products_list_response.dart'
    show PriceRange, Product, ProductCategory;
import '../json_number.dart';
import '../search/search_facets.dart';
import '../search/search_response.dart' show SearchFilter;

export '../products/products_list_response.dart' show Product;

/// Response from [PersonalizationSdk.getCategory].
///
/// The total product count and the product list, plus the facets the API sends
/// with a category as with full search. Products are parsed with the shared
/// [Product] model (Android returns a richer product than iOS; the parser tolerates
/// the missing fields).
class CategoryResponse {
  final int productsTotal;
  final List<Product> products;

  /// Brand names found in the category.
  final List<String> brands;

  /// Product count per brand name.
  final Map<String, int> brandCounts;

  /// Shop facets keyed by name: value → product count.
  final Map<String, SearchFilter> filters;
  final PriceRange? priceRange;

  /// The categories of the listing (`categories`).
  final List<ProductCategory> categories;

  /// The price histogram (`price_ranges`).
  final List<PriceInterval> priceRanges;

  /// The median price (`price_median`).
  final double? priceMedian;

  const CategoryResponse({
    required this.productsTotal,
    required this.products,
    this.brands = const [],
    this.brandCounts = const {},
    this.filters = const {},
    this.priceRange,
    this.categories = const [],
    this.priceRanges = const [],
    this.priceMedian,
  });

  factory CategoryResponse.fromJson(Map<String, dynamic> json) {
    return CategoryResponse(
      productsTotal: toIntOrNull(json['products_total']) ?? 0,
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
      brands: parseBrandNames(json['brands']),
      brandCounts: parseFacetCounts(json['brands'], 'name'),
      filters: parseFacetFilters(json['filters']),
      priceRange: json['price_range'] is Map
          ? PriceRange.fromJson(
              Map<String, dynamic>.from(json['price_range'] as Map),
            )
          : null,
      categories: (json['categories'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => ProductCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      priceRanges: parsePriceIntervals(json['price_ranges']),
      priceMedian: toDoubleOrNull(json['price_median']),
    );
  }
}
