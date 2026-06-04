/// Test credentials for integration tests.
///
/// shopId / productId / searchQuery taken from native SDK test suites.
/// recommendationBlockCode must be filled in manually (not stored in source).
/// Do NOT commit real production credentials to version control.
class TestConfig {
  static const shopId = '357382bf66ac0ce2f1722677c59511';
  static const apiDomain = 'api.rees46.ru';

  /// A recommender block code that exists in your test shop.
  /// Not found in any native SDK source — fill in from the REES46 dashboard.
  static const recommendationBlockCode = 'your_block_code';

  /// A search query that returns at least one result in your test shop.
  static const searchQuery = 'пудра-бронзер';

  /// A product ID that exists in your test shop.
  static const productId = '486';
}
