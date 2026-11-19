/// The catalog models of the namespaces — `products`, `collections`,
/// `recommendations` and `search` — as the contract has them: `Product`,
/// `ProductsListResponse`, `CategoryResponse`, `CollectionResponse`,
/// `RecommendationResponse`, `SearchBlankResponse`, `SearchInstantResponse`,
/// `SearchFullResponse` and the models in them.
///
/// Several have the names of the released classes the deprecated methods return,
/// which `package:rees46_sdk/rees46_sdk.dart` keeps exporting until those methods go.
/// To name both in one file, import this one with a prefix:
///
/// ```dart
/// import 'package:rees46_sdk/rees46_sdk.dart';
/// import 'package:rees46_sdk/models.dart' as rees46;
///
/// final rees46.Product? product = await sdk.products.getInfo('37');
/// ```
library;

export 'src/models/catalog.dart';
