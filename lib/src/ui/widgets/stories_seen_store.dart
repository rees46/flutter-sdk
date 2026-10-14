import 'package:flutter/foundation.dart';

import '../../multi_instance/rees46.dart';
import '../../personalization_sdk.dart';

/// Просмотренные слайды сторис по магазину: id слайдов по id сторис.
///
/// Хранит их плагин на устройстве (SharedPreferences / UserDefaults) — между запусками
/// приложения. Здесь — копия на процесс: магазин читается с устройства один раз, дальше
/// все просмотры и ленты одного магазина видят одно состояние, а каждая отметка сразу
/// уходит и в хранилище. Хранилище недоступно (тесты, ошибка канала) — состояние живёт
/// только в памяти.
class StoriesSeenStore {
  /// Хранилище процесса. Тесты подменяют его.
  static StoriesSeenStore instance = StoriesSeenStore();

  final Map<String, Map<String, Set<String>>> _byShop =
      <String, Map<String, Set<String>>>{};
  final Map<String, Future<void>> _loads = <String, Future<void>>{};

  /// Ключ магазина: его shopId; у хэндла без него — единственный живой магазин.
  static String shopOf(PersonalizationSdk sdk) {
    final own = sdk.shopId;
    if (own != null && own.isNotEmpty) return own;
    final live = REES46.liveShopIds;
    return live.length == 1 ? live.single : '';
  }

  /// Просмотренное магазина [sdk] — после первого чтения с устройства.
  Future<Map<String, Set<String>>> load(PersonalizationSdk sdk) async {
    final shop = shopOf(sdk);
    await (_loads[shop] ??= _read(sdk, shop));
    return seen(sdk);
  }

  Future<void> _read(PersonalizationSdk sdk, String shop) async {
    final current = _byShop.putIfAbsent(shop, () => <String, Set<String>>{});
    // Разбор тоже под try: кривые данные хранилища не должны ронять ленту.
    try {
      final stored = await sdk.getStoriesSeen(shop);
      for (final entry in stored.entries) {
        (current[entry.key] ??= <String>{}).addAll(entry.value);
      }
    } catch (error) {
      debugPrint('PersonalizationStories: seen slides unavailable — $error');
    }
  }

  /// Что известно сейчас, без чтения с устройства.
  Map<String, Set<String>> seen(PersonalizationSdk sdk) =>
      <String, Set<String>>{
        for (final entry
            in (_byShop[shopOf(sdk)] ?? const <String, Set<String>>{}).entries)
          entry.key: Set<String>.unmodifiable(entry.value),
      };

  /// Слайд [slideId] сторис [storyId] просмотрен.
  void mark(PersonalizationSdk sdk, String storyId, String slideId) {
    final shop = shopOf(sdk);
    final slides = (_byShop.putIfAbsent(
      shop,
      () => <String, Set<String>>{},
    )[storyId] ??= <String>{});
    if (!slides.add(slideId)) return;
    sdk.setStorySlideSeen(shop, storyId, slideId).catchError((Object error) {
      debugPrint('PersonalizationStories: cannot store a seen slide — $error');
    });
  }
}
