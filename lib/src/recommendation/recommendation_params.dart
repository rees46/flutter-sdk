import 'dart:convert';

/// Parameters for [PersonalizationSdk.getRecommendation].
///
/// Only fields supported by **both** Android and iOS native SDKs are included.
/// Android-only params not exposed here: `limit`, `brands`, `excludeBrands`,
/// `categories`, `discount`, `fullCart`, `fullWish`, `orderId`, `orderPrice`,
/// `searchQuery`. iOS does not expose these through its `recommend()` method.
class RecommendationParams {
  /// ID of the current product shown to the user.
  final String? itemId;

  /// ID of the current category shown to the user.
  final String? categoryId;

  /// Comma-separated location IDs to filter recommendations.
  final String? locations;

  /// Image resize size. Available values: 120, 140, 160, 180, 200, 220, 310, 520.
  final int? imageSize;

  /// Whether to include location objects in product data. Defaults to false.
  final bool withLocations;

  const RecommendationParams({
    this.itemId,
    this.categoryId,
    this.locations,
    this.imageSize,
    this.withLocations = false,
  });

  String toJson() => jsonEncode({
    if (itemId != null) 'item_id': itemId,
    if (categoryId != null) 'category_id': categoryId,
    if (locations != null) 'locations': locations,
    if (imageSize != null) 'image_size': imageSize,
    'with_locations': withLocations,
  });
}
