import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../search/search_response.dart';

/// Категория, на которую можно перейти из поиска: из подсказок instant-поиска (есть id)
/// или из популярных категорий пустого запроса (только имя и ссылка).
@immutable
class PersonalizationSearchCategory {
  const PersonalizationSearchCategory({
    required this.id,
    required this.name,
    required this.url,
  });

  final String? id;
  final String name;
  final String? url;
}

/// Недавние запросы пользователя — локальная история виджета поиска, по магазину.
///
/// Сервер тоже помнит последние запросы (`last_queries` в `search/blank`), но не умеет
/// забывать по одному, а в макете у каждого тега крестик и есть «Clear». Поэтому история
/// живёт в SharedPreferences под ключом с id магазина.
class RecentSearches {
  RecentSearches({required String shopKey, required this.limit})
    : _key = 'personalization.ui.recentSearches.$shopKey';

  final String _key;
  final int limit;

  Future<List<String>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_key) ?? const <String>[];
  }

  /// Кладёт запрос в начало, убирая дубль, и режет по лимиту.
  Future<List<String>> add(String query) async {
    final trimmed = query.trim();
    final items = await load();
    if (trimmed.isEmpty) return items;
    final next = <String>[
      trimmed,
      ...items.where((item) => item.toLowerCase() != trimmed.toLowerCase()),
    ];
    return _save(next.take(limit).toList());
  }

  Future<List<String>> remove(String query) async =>
      _save((await load()).where((item) => item != query).toList());

  Future<List<String>> clear() => _save(const <String>[]);

  Future<List<String>> _save(List<String> items) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_key, items);
    return items;
  }
}

/// Имя родительской категории: в ответе родитель — это id, имя ищем среди пришедших.
String? parentName(SearchCategory category, List<SearchCategory> all) {
  final parentId = category.parentId;
  if (parentId == null || parentId.isEmpty) return null;
  for (final item in all) {
    if (item.id == parentId) return item.name;
  }
  return null;
}
