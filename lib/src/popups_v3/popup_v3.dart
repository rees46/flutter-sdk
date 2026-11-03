import 'popup_v3_values.dart';

/// Макет попапа v3 в приложении.
enum PopupV3Layout {
  /// Полоса сверху или снизу; приложение под ней доступно.
  banner('banner'),

  /// Окно по центру; одно на экране.
  modal('modal'),

  /// Весь экран; занимает тот же слот, что и окно.
  fullscreen('fullscreen');

  const PopupV3Layout(this.wire);

  final String wire;

  static PopupV3Layout? parse(Object? value) {
    for (final layout in values) {
      if (layout.wire == value) return layout;
    }
    return null;
  }
}

/// Где стоит попап: баннер — сверху или снизу, окно и полный экран — по центру.
enum PopupV3Placement { top, bottom, center }

/// Когда показывать попап.
enum PopupV3Trigger {
  /// Запуск приложения: проверяется на каждой загрузке списка и на каждом открытом
  /// экране из `target_screens`; сколько раз показать, решает частота.
  appStart('app_start'),

  /// Открытие экрана из `target_screens`.
  screenOpen('screen_open'),

  /// Столько-то секунд на экране из `target_screens`.
  timeOnScreen('time_on_screen'),

  /// Своё событие SDK (`tracking.custom`) с именем `trigger_event`.
  trackEvent('track_event'),

  /// Только вручную — `popups.show(id)`.
  manual('manual');

  const PopupV3Trigger(this.wire);

  final String wire;

  static PopupV3Trigger? parse(Object? value) {
    for (final trigger in values) {
      if (trigger.wire == value) return trigger;
    }
    return null;
  }
}

/// Как часто показывать попап; считается на устройстве.
enum PopupV3Frequency {
  onceSession('once_session'),
  onceLife('once_life'),
  onceDay('once_day'),
  onceWeek('once_week'),
  onceMonth('once_month'),
  everyPage('every_page');

  const PopupV3Frequency(this.wire);

  final String wire;

  /// Неизвестная частота и `null` — раз за сессию, как у веба.
  static PopupV3Frequency parse(Object? value) {
    for (final frequency in values) {
      if (frequency.wire == value) return frequency;
    }
    return onceSession;
  }
}

final RegExp _promoToken = RegExp(r'\{\{\s*promo_code\s*\}\}');

/// Попап v3 из `GET /api/v3/storefront/popups` (канал mobile).
class PopupV3 {
  const PopupV3({
    required this.id,
    required this.layout,
    required this.placement,
    required this.trigger,
    this.triggerDelay = Duration.zero,
    this.triggerEvent,
    this.frequency = PopupV3Frequency.onceSession,
    this.cooldownMinutes = 0,
    this.promoCodeListId,
    this.targetScreens = const <String>[],
    this.design = const <String, Object?>{},
  });

  final int id;
  final PopupV3Layout layout;
  final PopupV3Placement placement;
  final PopupV3Trigger trigger;

  /// Сколько сидеть на экране для `time_on_screen` (`trigger_value`, секунды).
  final Duration triggerDelay;

  /// Имя события для `track_event`.
  final String? triggerEvent;
  final PopupV3Frequency frequency;
  final double cooldownMinutes;

  /// Список промокодов: код запрашивается до показа.
  final String? promoCodeListId;

  /// Коды экранов; пусто — любой экран.
  final List<String> targetScreens;

  /// Опубликованный документ design как есть.
  final Map<String, Object?> design;

  /// Окно или полный экран — слот «одна модалка».
  bool get isModal => layout != PopupV3Layout.banner;

  /// Подходит ли экран [screen]: пустой список — любой, `null` (экран ещё не открыт)
  /// подходит только пустому списку.
  bool matchesScreen(String? screen) =>
      targetScreens.isEmpty ||
      (screen != null && targetScreens.contains(screen));

  /// Нужен ли персональный промокод до показа: задан список и в дизайне есть
  /// `{{promo_code}}` или элемент промокода не со статическим кодом.
  bool get needsPromoCode {
    if (promoCodeListId == null) return false;
    final elements = design['elements'];
    if (elements is List) {
      for (final element in elements) {
        if (element is Map &&
            element['type'] == 'promoCode' &&
            (element['style'] is! Map ||
                (element['style'] as Map)['promoSource'] != 'static')) {
          return true;
        }
      }
    }
    return _hasPromoToken(design);
  }

  static bool _hasPromoToken(Object? value) {
    if (value is String) return _promoToken.hasMatch(value);
    if (value is Map) return value.values.any(_hasPromoToken);
    if (value is List) return value.any(_hasPromoToken);
    return false;
  }

  /// Попап из JSON или `null` с причиной в [onSkip]: нет id, неизвестный для mobile
  /// макет или триггер.
  static PopupV3? tryParse(
    Object? json, {
    void Function(Object? id, String reason)? onSkip,
  }) {
    if (json is! Map) {
      onSkip?.call(null, 'not an object');
      return null;
    }
    final rawId = json['id'];
    final id = rawId is int
        ? rawId
        : rawId is num
        ? rawId.toInt()
        : int.tryParse('${rawId ?? ''}'.trim());
    if (id == null) {
      onSkip?.call(rawId, 'no id');
      return null;
    }
    final layout = PopupV3Layout.parse(json['layout']);
    if (layout == null) {
      onSkip?.call(id, 'unknown layout ${json['layout']}');
      return null;
    }
    final trigger = PopupV3Trigger.parse(json['trigger_type']);
    if (trigger == null) {
      onSkip?.call(id, 'unknown trigger ${json['trigger_type']}');
      return null;
    }
    final screens = json['target_screens'];
    final design = json['design'];
    final seconds = cssNum(json['trigger_value'], 0);
    return PopupV3(
      id: id,
      layout: layout,
      placement: layout == PopupV3Layout.banner
          ? (json['placement'] == 'bottom'
                ? PopupV3Placement.bottom
                : PopupV3Placement.top)
          : PopupV3Placement.center,
      trigger: trigger,
      triggerDelay: Duration(
        milliseconds: (seconds < 0 ? 0 : seconds * 1000).round(),
      ),
      triggerEvent: cssPresent(json['trigger_event'])?.trim(),
      frequency: PopupV3Frequency.parse(json['frequency']),
      cooldownMinutes: cssNum(json['cooldown_minutes'], 0),
      promoCodeListId: cssPresent(json['promo_code_list_id'])?.trim(),
      targetScreens: screens is List
          ? <String>[
              for (final screen in screens)
                if (cssPresent(screen) case final name?) name.trim(),
            ]
          : const <String>[],
      design: design is Map
          ? Map<String, Object?>.from(design)
          : const <String, Object?>{},
    );
  }

  @override
  String toString() => 'PopupV3($id, ${layout.wire}, ${trigger.wire})';
}

/// Попап, исключённый сервером (`excluded` с `debug=1`).
typedef PopupV3Excluded = ({Object? id, String reason});

/// Список попапов: срок кеша, попапы канала mobile, исключённые сервером и
/// пропущенные приложением.
class PopupsV3List {
  const PopupsV3List({
    required this.ttl,
    required this.popups,
    this.excluded = const <PopupV3Excluded>[],
    this.skipped = const <Object?, String>{},
  });

  /// Срок кеша по умолчанию — и для пустого списка после ошибки 4xx.
  static const Duration defaultTtl = Duration(seconds: 300);

  static const PopupsV3List empty = PopupsV3List(
    ttl: defaultTtl,
    popups: <PopupV3>[],
  );

  final Duration ttl;
  final List<PopupV3> popups;
  final List<PopupV3Excluded> excluded;

  /// Пропущенные приложением: id → причина.
  final Map<Object?, String> skipped;

  /// `payload` ответа списка: `ttl` (числом или строкой; не больше нуля — 300),
  /// `popups`, `excluded`.
  static PopupsV3List parse(Map<String, Object?> payload) {
    final seconds = cssNum(payload['ttl'], 0);
    final skipped = <Object?, String>{};
    final popups = <PopupV3>[];
    final raw = payload['popups'];
    if (raw is List) {
      for (final item in raw) {
        final popup = PopupV3.tryParse(
          item,
          onSkip: (id, reason) => skipped[id] = reason,
        );
        if (popup != null) popups.add(popup);
      }
    }
    final excluded = payload['excluded'];
    return PopupsV3List(
      ttl: seconds > 0
          ? Duration(milliseconds: (seconds * 1000).round())
          : defaultTtl,
      popups: popups,
      excluded: excluded is List
          ? <PopupV3Excluded>[
              for (final item in excluded)
                if (item is Map)
                  (id: item['id'], reason: cssString(item['reason'])),
            ]
          : const <PopupV3Excluded>[],
      skipped: skipped,
    );
  }
}
