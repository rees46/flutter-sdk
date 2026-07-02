/// Test data for the integration tests.
///
/// These values must exist in the shop the example app initializes with
/// (see `_shopId` in example/lib/main.dart → `c1140c…`, the technodom.kz demo
/// shop). They are demo-shop identifiers, not credentials.
class TestConfig {
  /// The shop the example app initializes with (kept here for reference; the
  /// app hardcodes it, the tests drive the app).
  static const shopId = 'c1140c8254976de297c3caf971701a';
  static const apiDomain = 'api.rees46.ru';

  /// A recommender block code that exists in the test shop (the "Популярные"
  /// / popular block for `c1140c…`, returns ~20 products).
  static const recommendationBlockCode = 'e6249bb15043644bf25b135006149962';

  /// A search query that returns results in the test shop (Logitech products
  /// exist, e.g. item 868).
  static const searchQuery = 'Logitech';

  /// A product ID that exists in the test shop (Logitech H150 headset).
  static const productId = '868';
}
