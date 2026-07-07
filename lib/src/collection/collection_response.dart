import '../products/products_list_response.dart' show Product;

export '../products/products_list_response.dart' show Product;

/// Response from [PersonalizationSdk.getCollection].
///
/// A merchandised collection is just a product list; products are parsed with
/// the shared [Product] model.
class CollectionResponse {
  final List<Product> products;

  const CollectionResponse({required this.products});

  factory CollectionResponse.fromJson(Map<String, dynamic> json) {
    return CollectionResponse(
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
