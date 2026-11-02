/// Wire format of the [PersonalizationSdk.getCategory] filters. Not exported from the
/// package barrel.
library;

import 'dart:convert';

/// Whether a category listing applies a price range and a sort (`price_min`,
/// `price_max`, `sort_by`, `sort_dir`) on this platform.
///
/// The API takes them, but the native SDKs this plugin is built against (Android
/// 2.45.0, iOS 3.35.0) have no such category parameters yet: Dart sends them, the
/// bridges drop them. The kit's category screen hides its price section and sort
/// button while this is `false`. Flip it together with the bridges once the plugin
/// pins native releases that take them.
const bool categoryPriceAndSortApplied = false;

/// The JSON object the bridges read, `null` when no filter is set. Keys are the API's;
/// empty values are left out.
String? categoryParamsJson({
  String? brands,
  String? locations,
  Map<String, List<String>>? filters,
  double? priceMin,
  double? priceMax,
  String? sortBy,
  String? sortDir,
}) {
  final facets = <String, List<String>>{
    for (final entry in (filters ?? const <String, List<String>>{}).entries)
      if (entry.value.isNotEmpty) entry.key: entry.value,
  };
  final params = <String, Object>{
    if ((brands ?? '').isNotEmpty) 'brands': brands!,
    if ((locations ?? '').isNotEmpty) 'locations': locations!,
    if (facets.isNotEmpty) 'filters': facets,
    'price_min': ?priceMin,
    'price_max': ?priceMax,
    if ((sortBy ?? '').isNotEmpty) 'sort_by': sortBy!,
    if ((sortDir ?? '').isNotEmpty) 'sort_dir': sortDir!,
  };
  return params.isEmpty ? null : jsonEncode(params);
}
