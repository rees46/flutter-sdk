/// Wire format of the [PersonalizationSdk.getCategory] filters. Not exported from the
/// package barrel.
library;

import 'dart:convert';

/// Whether a category listing applies a price range and a sort (`price_min`,
/// `price_max`, `sort_by`, `sort_dir`) on this platform.
///
/// The bridges pass them to the native SDKs (Android 2.47.0, iOS 3.37.0 and later
/// take them). The kit's category screen hides its price section and sort button
/// while this is `false`.
const bool categoryPriceAndSortApplied = true;

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
