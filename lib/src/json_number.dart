/// Tolerant numeric coercion for REES46 API responses.
///
/// The API is not consistent about how it encodes numbers: some numeric fields
/// arrive as JSON numbers, others as strings — e.g. a product's `price` comes
/// back as `"14990.0"` (a string) while `price_full` is `14990.0` (a number).
/// A plain `value as num?` cast throws `'String' is not a subtype of type
/// 'num?'` on the string form, which previously made product/search/
/// recommendation/catalog responses fail to parse. These helpers accept `num`,
/// `String`, or `null`.
library;

/// Coerces [value] to a `double`, or returns `null` if it can't be parsed.
double? toDoubleOrNull(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// Coerces [value] to an `int`, or returns `null` if it can't be parsed.
///
/// Accepts integer strings as well as numeric strings like `"6631.0"`.
int? toIntOrNull(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) {
    final s = value.trim();
    return int.tryParse(s) ?? double.tryParse(s)?.toInt();
  }
  return null;
}
