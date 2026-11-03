import 'package:shared_preferences/shared_preferences.dart';

import 'popup_v3.dart';

/// Последний показ попапа на устройстве: время (мс эпохи) и сессия.
typedef PopupV3LastShow = ({int? at, String? sid});

/// Где движок хранит последние показы попапов магазина.
abstract interface class PopupsV3Storage {
  Future<PopupV3LastShow> read(int popupId);

  Future<void> write(int popupId, int at, String? sid);
}

/// Показы в SharedPreferences, по магазину: `…<shop>.<id>.last` и `…<shop>.<id>.sid`.
class PopupsV3PreferencesStorage implements PopupsV3Storage {
  PopupsV3PreferencesStorage(String shopId)
    : _prefix = 'personalization.popupsV3.$shopId';

  final String _prefix;

  @override
  Future<PopupV3LastShow> read(int popupId) async {
    final preferences = await SharedPreferences.getInstance();
    return (
      at: preferences.getInt('$_prefix.$popupId.last'),
      sid: preferences.getString('$_prefix.$popupId.sid'),
    );
  }

  @override
  Future<void> write(int popupId, int at, String? sid) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('$_prefix.$popupId.last', at);
    if (sid != null && sid.isNotEmpty) {
      await preferences.setString('$_prefix.$popupId.sid', sid);
    }
  }
}

/// Показы в памяти — тесты и офлайн-сценарии.
class PopupsV3MemoryStorage implements PopupsV3Storage {
  final Map<int, PopupV3LastShow> shows = <int, PopupV3LastShow>{};

  @override
  Future<PopupV3LastShow> read(int popupId) async =>
      shows[popupId] ?? (at: null, sid: null);

  @override
  Future<void> write(int popupId, int at, String? sid) async {
    final previous = shows[popupId];
    shows[popupId] = (
      at: at,
      sid: sid != null && sid.isNotEmpty ? sid : previous?.sid,
    );
  }
}

/// Частота и пауза показов — как у веба (`frequency.ts`):
/// - пауза `cooldown_minutes` проверяется до частоты;
/// - `once_session` сравнивает сессию последнего показа;
/// - `once_day`/`once_week`/`once_month` — 24 ч, 7 и 30 дней;
/// - `every_page` — один показ на «страницу», то есть на открытие экрана;
/// - в тестовом режиме показ ничего не записывает (кроме «уже на этой странице»).
class PopupsV3FrequencyRules {
  PopupsV3FrequencyRules(this.storage);

  final PopupsV3Storage storage;
  final Set<int> _shownOnPage = <int>{};

  static const Map<PopupV3Frequency, Duration> periods =
      <PopupV3Frequency, Duration>{
        PopupV3Frequency.onceDay: Duration(days: 1),
        PopupV3Frequency.onceWeek: Duration(days: 7),
        PopupV3Frequency.onceMonth: Duration(days: 30),
      };

  /// Открыт новый экран.
  void newPage() => _shownOnPage.clear();

  /// Можно ли показать [popup] сейчас ([now]) в сессии [sid]; нельзя — причина.
  Future<String?> check(
    PopupV3 popup, {
    required DateTime now,
    String? sid,
  }) async {
    if (_shownOnPage.contains(popup.id)) return 'already shown on this screen';
    final last = await storage.read(popup.id);
    final lastAt = last.at;
    final elapsed = lastAt == null
        ? null
        : Duration(milliseconds: now.millisecondsSinceEpoch - lastAt);
    final cooldown = popup.cooldownMinutes;
    if (cooldown > 0 &&
        elapsed != null &&
        elapsed < Duration(milliseconds: (cooldown * 60000).round())) {
      return 'cooldown ${_minutes(cooldown)} min';
    }
    switch (popup.frequency) {
      case PopupV3Frequency.everyPage:
        return null;
      case PopupV3Frequency.onceLife:
        return lastAt == null ? null : 'once_life: already shown';
      case PopupV3Frequency.onceDay:
      case PopupV3Frequency.onceWeek:
      case PopupV3Frequency.onceMonth:
        return elapsed == null || elapsed >= periods[popup.frequency]!
            ? null
            : '${popup.frequency.wire}: shown recently';
      case PopupV3Frequency.onceSession:
        return last.sid != null && last.sid == sid
            ? 'once_session: already shown in this session'
            : null;
    }
  }

  /// Запомнить показ [popup].
  Future<void> record(
    PopupV3 popup, {
    required DateTime now,
    String? sid,
    bool testMode = false,
  }) async {
    _shownOnPage.add(popup.id);
    if (testMode) return;
    await storage.write(popup.id, now.millisecondsSinceEpoch, sid);
  }

  static String _minutes(double value) => value == value.roundToDouble()
      ? '${value.toInt()}'
      : value.toStringAsFixed(1);
}
