import '../products/products_list_response.dart' show Product;
import '../json_number.dart';

export '../products/products_list_response.dart' show Product;

/// Response from [PersonalizationSdk.getCategory].
///
/// Exposes the common subset available on both platforms: the total product
/// count and the product list. Products are parsed with the shared [Product]
/// model (Android returns a richer product than iOS; the parser tolerates the
/// missing fields).
class CategoryResponse {
  final int productsTotal;
  final List<Product> products;

  const CategoryResponse({required this.productsTotal, required this.products});

  factory CategoryResponse.fromJson(Map<String, dynamic> json) {
    return CategoryResponse(
      productsTotal: toIntOrNull(json['products_total']) ?? 0,
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
