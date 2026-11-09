import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Кэш ответов SDK для виджетов с данными — в памяти процесса.
///
/// Ключ — магазин, вид запроса и его параметры ([keyOf]). Ответ живёт [ttl] (10 минут),
/// записей не больше [capacity] (32): сверх неё вытесняются самые старые. Ошибка не
/// кэшируется: следующий запрос уходит заново.
///
/// Одинаковые запросы, пока первый в полёте, склеиваются в один, но не навсегда: запрос
/// старше [joinWindow] (30 секунд) новых ожидающих не принимает — следующий уходит в сеть
/// новым поколением. Ответ старого поколения достаётся только его ожидающим и в кэш не
/// ложится, если есть поколение новее или после его старта был [clear]. Отписка
/// последнего ожидающего снимает запрос из полёта. `force` («Повторить») идёт мимо
/// готового ответа и мимо запроса в полёте.
///
/// Внутренний: не экспортируется из кита. Общий на процесс — [shared]; тесты и виджеты
/// со своим жизненным циклом создают свой.
class PersonalizationRequestCache {
  PersonalizationRequestCache({
    this.ttl = const Duration(minutes: 10),
    this.capacity = 32,
    this.joinWindow = const Duration(seconds: 30),
    Duration Function()? clock,
  }) : assert(capacity > 0),
       _now = clock ?? _monotonic();

  /// Кэш, общий для всех виджетов процесса.
  static final PersonalizationRequestCache shared =
      PersonalizationRequestCache();

  final Duration ttl;
  final int capacity;

  /// Сколько запрос в полёте принимает новых ожидающих.
  final Duration joinWindow;

  /// Монотонные часы: перевод системного времени не старит и не молодит ответы.
  final Duration Function() _now;

  static Duration Function() _monotonic() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  /// Порядок вставки — возраст записи: первая — самая старая.
  final LinkedHashMap<String, _Entry> _entries =
      LinkedHashMap<String, _Entry>();

  /// Запрос в полёте, к которому присоединяются, — по ключу.
  final Map<String, _Flight> _inFlight = <String, _Flight>{};

  /// Поколение последнего начатого запроса — по ключу: только его ответ ложится в кэш.
  final Map<String, int> _newest = <String, int>{};

  /// Счётчик поколений и поколение на момент последнего [clear].
  int _generation = 0;
  int _clearedAt = 0;

  /// Ключ запроса: магазин, вид запроса (`recommend`, `search` …) и параметры.
  /// Параметры сортируются по имени, пустые (`null`) пропускаются — порядок, в котором
  /// их собрал виджет, на ключ не влияет. Всё кодируется JSON, а не склеивается как есть:
  /// значение с `&` или `=` не совпадёт с другим набором параметров.
  static String keyOf(
    String? shopId,
    String kind, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) {
    final names = params.keys.where((name) => params[name] != null).toList()
      ..sort();
    return jsonEncode(<Object?>[
      shopId,
      kind,
      <Object?>[
        for (final name in names) <Object?>[name, params[name]],
      ],
    ], toEncodable: (value) => value.toString());
  }

  /// Подписывает на ответ по [key]: свежий из кэша, ответ запроса того же ключа, который
  /// уже в полёте, иначе — нового запроса [load]. Колбэки зовутся асинхронно и один раз;
  /// после [PersonalizationCacheSubscription.cancel] — ни разу.
  PersonalizationCacheSubscription fetch<T>(
    String key,
    Future<T> Function() load, {
    required void Function(T value) onValue,
    void Function(Object error)? onError,
    bool force = false,
  }) {
    final waiter = _Waiter((value) => onValue(value as T), onError);
    var entry = _entries[key];
    if (entry != null && _now() - entry.storedAt >= ttl) {
      _entries.remove(key);
      entry = null;
    }
    if (!force) {
      if (entry != null) {
        final value = entry.value;
        scheduleMicrotask(() => _deliver(waiter, value));
        return PersonalizationCacheSubscription._(() => waiter.done = true);
      }
      final flight = _inFlight[key];
      if (flight != null && _now() - flight.startedAt < joinWindow) {
        return _join(key, flight, waiter);
      }
    }
    final flight = _Flight(++_generation, _now());
    _inFlight[key] = flight;
    _newest[key] = flight.generation;
    final subscription = _join(key, flight, waiter);
    Future<T>.sync(load).then<void>(
      (value) {
        if (_finish(key, flight) && flight.generation > _clearedAt) {
          _store(key, value);
        }
        for (final waiter in flight.takeWaiters()) {
          _deliver(waiter, value);
        }
      },
      onError: (Object error) {
        _finish(key, flight);
        for (final waiter in flight.takeWaiters()) {
          _fail(waiter, error);
        }
      },
    );
    return subscription;
  }

  /// Свежий ответ по [key] прямо сейчас, без запроса и без подписки; нет его или он
  /// устарел — `null`. Виджет, пересозданный лентой, рисует его в первом же кадре, а не
  /// пустым до асинхронного ответа [fetch].
  Object? peek(String key) {
    final entry = _entries[key];
    if (entry == null || _now() - entry.storedAt >= ttl) return null;
    return entry.value;
  }

  /// Сколько ответов лежит в кэше (вместе с устаревшими, ещё не вытесненными).
  int get length => _entries.length;

  /// Забывает все ответы и запросы в полёте. Те доходят до своих ожидающих, но в кэш
  /// уже не попадают.
  void clear() {
    _entries.clear();
    _inFlight.clear();
    _newest.clear();
    _clearedAt = _generation;
  }

  PersonalizationCacheSubscription _join(
    String key,
    _Flight flight,
    _Waiter waiter,
  ) {
    flight.waiters.add(waiter);
    return PersonalizationCacheSubscription._(() {
      if (waiter.done) return;
      waiter.done = true;
      flight.waiters.remove(waiter);
      if (flight.waiters.isEmpty && identical(_inFlight[key], flight)) {
        _inFlight.remove(key);
      }
    });
  }

  /// Запрос [flight] завершился: снимает его из полёта. `true` — он новейший по ключу,
  /// и его ответ можно класть в кэш.
  bool _finish(String key, _Flight flight) {
    if (identical(_inFlight[key], flight)) _inFlight.remove(key);
    if (_newest[key] != flight.generation) return false;
    _newest.remove(key);
    return true;
  }

  void _store(String key, Object? value) {
    // Обновлённая запись — снова самая новая.
    _entries.remove(key);
    _entries[key] = _Entry(value, _now());
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  static void _deliver(_Waiter waiter, Object? value) {
    if (waiter.done) return;
    waiter.done = true;
    _guard(() => waiter.onValue(value));
  }

  static void _fail(_Waiter waiter, Object error) {
    if (waiter.done) return;
    waiter.done = true;
    final onError = waiter.onError;
    if (onError != null) _guard(() => onError(error));
  }

  /// Колбэк одного ожидающего, бросивший исключение, не мешает остальным: исключение
  /// уходит в [FlutterError.reportError].
  static void _guard(void Function() callback) {
    try {
      callback();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'rees46_sdk',
          context: ErrorDescription('while delivering a cached SDK answer'),
        ),
      );
    }
  }
}

/// Подписка на ответ [PersonalizationRequestCache.fetch].
class PersonalizationCacheSubscription {
  PersonalizationCacheSubscription._(this._cancel);

  final void Function() _cancel;

  /// Отписаться: колбэки больше не вызываются. Отписка последнего ожидающего снимает
  /// запрос из полёта.
  void cancel() => _cancel();
}

class _Entry {
  const _Entry(this.value, this.storedAt);

  final Object? value;
  final Duration storedAt;
}

/// Один запрос в сеть и те, кто ждёт его ответа.
class _Flight {
  _Flight(this.generation, this.startedAt);

  final int generation;
  final Duration startedAt;
  final List<_Waiter> waiters = <_Waiter>[];

  /// Забирает ожидающих для раздачи ответа.
  List<_Waiter> takeWaiters() {
    final taken = List<_Waiter>.of(waiters);
    waiters.clear();
    return taken;
  }
}

class _Waiter {
  _Waiter(this.onValue, this.onError);

  final void Function(Object? value) onValue;
  final void Function(Object error)? onError;

  /// Ответ отдан или ожидающий отписался.
  bool done = false;
}
