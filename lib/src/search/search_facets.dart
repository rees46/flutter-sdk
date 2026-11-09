/// Facet parsers shared by the search, category and products list responses.
///
/// Every catalog-like endpoint answers with the same facets as full search, so the
/// responses parse them the same way. Not exported from the package barrel.
library;

import '../json_number.dart';
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
