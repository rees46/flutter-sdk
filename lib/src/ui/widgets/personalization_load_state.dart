import 'package:flutter/foundation.dart';

/// Состояние загрузки данных виджета: запроса не было, грузится, есть данные, пусто или
/// ошибка. Внутреннее: не экспортируется из кита.
sealed class PersonalizationLoadState<T> {
  const PersonalizationLoadState();
}

/// Запроса ещё не было.
final class PersonalizationLoadIdle<T> extends PersonalizationLoadState<T> {
  const PersonalizationLoadIdle();
}

/// Запрос в полёте.
final class PersonalizationLoadLoading<T> extends PersonalizationLoadState<T> {
  const PersonalizationLoadLoading();
}

/// Данные пришли и в них есть что показать.
final class PersonalizationLoadContent<T> extends PersonalizationLoadState<T> {
  const PersonalizationLoadContent(this.data);

  final T data;
}

/// Ответ пришёл, но показать нечего.
final class PersonalizationLoadEmpty<T> extends PersonalizationLoadState<T> {
  const PersonalizationLoadEmpty();
}

/// Запрос не удался; [retry] контроллера повторяет его.
final class PersonalizationLoadError<T> extends PersonalizationLoadState<T> {
  const PersonalizationLoadError(this.error);

  final Object error;
}

/// Загрузка с повтором: ведёт [PersonalizationLoadState] и помнит последний запрос,
/// чтобы его повторить.
///
/// Пустота ответа — [isEmpty]; без него пусты пустые коллекции и словари, остальное —
/// данные. Ответ прошлого запроса, пришедший после нового (или после [reset] и
/// [dispose]), отбрасывается.
class PersonalizationLoadController<T>
    extends ValueNotifier<PersonalizationLoadState<T>> {
  PersonalizationLoadController({bool Function(T data)? isEmpty})
    : _isEmpty = isEmpty ?? _emptyCollection,
      super(PersonalizationLoadIdle<T>());

  final bool Function(T data) _isEmpty;
  Future<T> Function()? _load;
  int _seq = 0;
  bool _disposed = false;

  /// Грузит [load]: [PersonalizationLoadLoading], затем данные, пусто или ошибка.
  Future<void> load(Future<T> Function() load) {
    _load = load;
    return _run(load);
  }

  /// Повторяет последний запрос; если запроса не было — ничего не делает.
  Future<void> retry() {
    final load = _load;
    return load == null ? Future<void>.value() : _run(load);
  }

  /// Назад к [PersonalizationLoadIdle] без запроса; ответ запроса в полёте отбросится.
  void reset() {
    _seq++;
    _load = null;
    value = PersonalizationLoadIdle<T>();
  }

  Future<void> _run(Future<T> Function() load) async {
    final seq = ++_seq;
    value = PersonalizationLoadLoading<T>();
    try {
      final data = await load();
      if (_disposed || seq != _seq) return;
      value = _isEmpty(data)
          ? PersonalizationLoadEmpty<T>()
          : PersonalizationLoadContent<T>(data);
    } catch (error) {
      if (_disposed || seq != _seq) return;
      value = PersonalizationLoadError<T>(error);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static bool _emptyCollection(Object? data) => switch (data) {
    Iterable<Object?>() => data.isEmpty,
    Map<Object?, Object?>() => data.isEmpty,
    _ => false,
  };
}
