/// Разбор значений документа попапа v3: числа, флаги и строки приходят как попало —
/// числом, строкой, `null`. Правила — как у компилятора дизайна на сервере
/// (`Context#num`, `presence`), чтобы приложение и сайт рисовали одно и то же.
library;

import '../json_number.dart';

final RegExp _leadingNumber = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?');

/// Число [value] или [fallback]: число, строка с числом в начале (`"12"`, `" 7 "`,
/// `"12px"` → 12, как `parseFloat`). Пусто, `null`, булево и прочее — [fallback].
double cssNum(Object? value, double fallback) {
  if (value is num) return value.isFinite ? value.toDouble() : fallback;
  if (value is String) {
    final match = _leadingNumber.firstMatch(value.trim());
    if (match == null) return fallback;
    return double.tryParse(match.group(0)!) ?? fallback;
  }
  return fallback;
}

/// Флаг: `true`/`"true"`/`1` и `false`/`"false"`/`0`; иначе `null`.
bool? cssBool(Object? value) => toBoolOrNull(value);

/// Строка с содержимым (не пустая и не из одних пробелов) — как `presence` в Ruby;
/// число — строкой. Иначе `null`.
String? cssPresent(Object? value) {
  final text = value is String
      ? value
      : value is num
      ? (value == value.roundToDouble() ? '${value.toInt()}' : '$value')
      : null;
  if (text == null || text.trim().isEmpty) return null;
  return text;
}

/// Строка как есть (`to_s`): строка, число строкой, иначе пустая.
String cssString(Object? value) =>
    value is String ? value : (cssPresent(value) ?? '');

/// Одно из [allowed] или `null`.
String? cssEnum(Object? value, List<String> allowed) =>
    value is String && allowed.contains(value) ? value : null;
