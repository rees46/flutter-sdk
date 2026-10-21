import 'dart:collection';

/// Кэш ответов SDK для виджетов с данными — в памяти процесса.
///
/// Ключ — магазин, вид запроса и его параметры ([keyOf]). Ответ живёт [ttl] (10 минут),
/// записей не больше [capacity] (32): сверх неё вытесняются самые старые. Одинаковые
/// запросы, пока первый в полёте, склеиваются в один. Ошибка не кэшируется: следующий
/// запрос уходит заново.
///
/// Внутренний: не экспортируется из кита. Общий на процесс — [shared]; тесты и виджеты
/// со своим жизненным циклом создают свой.
class PersonalizationRequestCache {
  PersonalizationRequestCache({
    this.ttl = const Duration(minutes: 10),
    this.capacity = 32,
    DateTime Function()? clock,
  }) : assert(capacity > 0),
       _now = clock ?? DateTime.now;

  /// Кэш, общий для всех виджетов процесса.
  static final PersonalizationRequestCache shared =
      PersonalizationRequestCache();

  final Duration ttl;
  final int capacity;
  final DateTime Function() _now;

  /// Порядок вставки — возраст записи: первая — самая старая.
  final LinkedHashMap<String, _Entry> _entries =
      LinkedHashMap<String, _Entry>();
  final Map<String, Future<Object?>> _inFlight = <String, Future<Object?>>{};

  /// Ключ запроса: магазин, вид запроса (`recommend`, `search` …) и параметры.
  /// Параметры сортируются по имени, пустые (`null`) пропускаются — порядок, в котором
  /// их собрал виджет, на ключ не влияет.
  static String keyOf(
    String? shopId,
    String kind, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) {
    final names = params.keys.where((name) => params[name] != null).toList()
      ..sort();
    final query = names.map((name) => '$name=${params[name]}').join('&');
    return '${shopId ?? ''}|$kind|$query';
  }

  /// Ответ по [key]: свежий из кэша, ответ запроса того же ключа, который уже в полёте,
  /// иначе — новый запрос [load].
  Future<T> fetch<T>(String key, Future<T> Function() load) {
    final entry = _entries[key];
    if (entry != null) {
      if (_now().difference(entry.storedAt) < ttl) {
        return Future<T>.value(entry.value as T);
      }
      _entries.remove(key);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending.then((value) => value as T);

    final future = load();
    _inFlight[key] = future;
    future.then(
      (value) {
        if (!identical(_inFlight[key], future)) return;
        _inFlight.remove(key);
        _store(key, value);
      },
      onError: (Object _) {
        // Ошибку получает тот, кто ждёт [future]; здесь только снимаем запрос из полёта.
        if (identical(_inFlight[key], future)) _inFlight.remove(key);
      },
    );
    return future;
  }

  /// Сколько ответов лежит в кэше (вместе с устаревшими, ещё не вытесненными).
  int get length => _entries.length;

  /// Забывает все ответы. Запросы в полёте доходят до тех, кто их ждёт, но в кэш
  /// уже не попадают.
  void clear() {
    _entries.clear();
    _inFlight.clear();
  }

  void _store(String key, Object? value) {
    // Обновлённая запись — снова самая новая.
    _entries.remove(key);
    _entries[key] = _Entry(value, _now());
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }
}

class _Entry {
  const _Entry(this.value, this.storedAt);

  final Object? value;
  final DateTime storedAt;
}
