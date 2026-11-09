import '../sdk_init_config.dart';

/// Что движок попапов v3 узнаёт от вызовов SDK.
abstract interface class PopupsV3Listener {
  /// SDK инициализирован (или переинициализирован) с [config].
  void onInitialized(SdkInitConfig config);

  /// Своё событие SDK (`tracking.custom`) — триггер `track_event`.
  void onTrackEvent(String event);

  /// Смена контекста клиента: профиль, подписка, сегмент (`type`), действие и данные.
  void onContextChanged(String type, String action, Object? data);

  /// Покупка.
  void onPurchase();
}

/// Связь обёртки SDK с движком попапов v3 без публичного API: обёртка сообщает о своих
/// вызовах по ключу — объекту `tracking` инстанса, движок подписывается на тот же ключ.
/// Пока движка нет, вызовы ничего не делают; конфиг init запоминается.
abstract final class PopupsV3Hooks {
  static final Expando<PopupsV3Listener> _listeners = Expando<PopupsV3Listener>(
    'popupsV3',
  );
  static final Expando<SdkInitConfig> _configs = Expando<SdkInitConfig>(
    'popupsV3Config',
  );

  static void listen(Object key, PopupsV3Listener? listener) =>
      _listeners[key] = listener;

  /// Конфиг последнего init инстанса [key].
  static SdkInitConfig? configOf(Object key) => _configs[key];

  static void initialized(Object key, SdkInitConfig config) {
    _configs[key] = config;
    _listeners[key]?.onInitialized(config);
  }

  static void trackEvent(Object key, String event) =>
      _listeners[key]?.onTrackEvent(event);

  static void contextChanged(
    Object key,
    String type,
    String action,
    Object? data,
  ) => _listeners[key]?.onContextChanged(type, action, data);

  static void purchase(Object key) => _listeners[key]?.onPurchase();
}
