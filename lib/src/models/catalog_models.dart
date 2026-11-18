// Models of the SDK contract, as the native SDKs hand them over.

/// A parameter of a product (`params`): its name and values.
class ProductParam {
  const ProductParam({required this.key, required this.values});

  /// The parameter's name.
  final String key;

  /// Its values; numbers come as strings.
  final List<String> values;
}

/// One interval of the price histogram of a listing or a search (`price_ranges`).
class PriceInterval {
  const PriceInterval({required this.from, this.to, this.count});

  /// The lower bound; 0 for the first interval.
  final double from;

  /// The upper bound; none for the last interval.
  final double? to;

  /// How many products are in the interval.
  final int? count;
}

/// Where the shop sends a query instead of the results (`search_query_redirects`).
class SearchRedirect {
  const SearchRedirect({this.query, this.url, this.deeplink});

  final String? query;

  /// `redirect_link`.
  final String? url;

  final String? deeplink;
}
