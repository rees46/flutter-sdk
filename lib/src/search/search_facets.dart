/// Facet parsers shared by the search, category and products list responses.
///
/// Every catalog-like endpoint answers with the same facets as full search, so the
/// responses parse them the same way. Not exported from the package barrel.
library;

import '../json_number.dart';
import '../models/catalog_models.dart';
import 'search_response.dart' show SearchFilter;

/// Brands arrive as `[{name, count}]` (Android, raw API) or `[name]` (iOS); both
/// become names.
List<String> parseBrandNames(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => e is Map ? e['name']?.toString() : e?.toString())
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .toList();
}

/// Product counts of `[{<key>: value, count}]` entries by value: brands (`name`) and
/// the colours (`color`) and sizes (`size`) of `industrial_filters`. Entries without a
/// count are left out — iOS sends the brands of a full search as bare names.
Map<String, int> parseFacetCounts(dynamic raw, String key) {
  if (raw is! List) return const {};
  final counts = <String, int>{};
  for (final entry in raw) {
    if (entry is! Map) continue;
    final value = entry[key]?.toString();
    final count = toIntOrNull(entry['count']);
    if (value != null && value.isNotEmpty && count != null) {
      counts[value] = count;
    }
  }
  return counts;
}

/// Shop facets (`filters`) keyed by name: value → product count.
Map<String, SearchFilter> parseFacetFilters(dynamic raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.value is Map)
        entry.key.toString(): SearchFilter.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        ),
  };
}

/// A product's parameters (`params`): an array `[{key, values}]`, or in the product
/// card (`products/get`) an object of the parameter's name → `{value: [...]}`.
List<ProductParam> parseProductParams(dynamic raw) {
  List<String> values(dynamic v) => v is List
      ? v.where((e) => e != null).map((e) => e.toString()).toList()
      : v == null
      ? const []
      : [v.toString()];
  if (raw is List) {
    return raw
        .whereType<Map>()
        .where((e) => e['key'] != null)
        .map(
          (e) => ProductParam(
            key: e['key'].toString(),
            values: values(e['values']),
          ),
        )
        .toList();
  }
  if (raw is Map) {
    return [
      for (final entry in raw.entries)
        ProductParam(
          key: entry.key.toString(),
          values: values(
            entry.value is Map ? entry.value['value'] : entry.value,
          ),
        ),
    ];
  }
  return const [];
}

/// The price histogram (`price_ranges`) of a listing or a search.
List<PriceInterval> parsePriceIntervals(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (e) => PriceInterval(
          from: toDoubleOrNull(e['from']) ?? 0,
          to: toDoubleOrNull(e['to']),
          count: toIntOrNull(e['count']),
        ),
      )
      .toList();
}
