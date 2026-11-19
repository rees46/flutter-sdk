/// The catalog and stories models of the namespaces — `products`, `collections`,
/// `recommendations`, `search` and `stories` — as the contract has them:
/// `Product`, `ProductsListResponse`, `CategoryResponse`, `CollectionResponse`,
/// `RecommendationResponse`, `SearchBlankResponse`, `SearchInstantResponse`,
/// `SearchFullResponse`, `StoriesBlock` and the models in them.
///
/// Several have the names of the released classes the deprecated methods and the
/// UI kit use, which `package:rees46_sdk/rees46_sdk.dart` keeps exporting.
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
export 'src/models/stories.dart';
