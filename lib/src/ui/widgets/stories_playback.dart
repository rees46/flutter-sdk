import 'dart:async';

import '../../stories/stories_response.dart';

/// Почему стоит текущий слайд. Часы слайда идут, только когда причин нет.
enum StoriesPauseReason {
  /// Палец держат на слайде (удержание от 200 мс).
  hold,

  /// Тянут: свайп вниз, листание сторис пальцем или программное перелистывание.
  drag,

  /// Раскрыта шторка товаров.
  sheet,

  /// Приложение свёрнуто или потеряло фокус, погас экран.
  background,

  /// Просмотр закрыт другим экраном.
  covered,

  /// Пауза от хоста (`PersonalizationStoriesController.pause`).
  host,

  /// Открыто системное окно «Поделиться».
  share,

  /// Опрос слайда: карточку держат пальцем, в фокусе её поле или идёт отправка ответа.
  /// Снимается и при заходе на другой слайд — не залипает.
  poll,

  /// Медиа слайда ещё грузится.
  loading,

  /// Медиа не загрузилось — на слайде кнопка «Повторить».
  error,
}

/// Что сделать просмотру после шага.
enum StoriesStep {
  /// Ничего не поменялось (например, шаг заблокирован шторкой).
  none,

  /// Новый заход на слайд текущей сторис — другой.
  slide,

  /// Тот же слайд с начала: прогресс с нуля, видео — к началу. Это не новый заход:
  /// медиа не перезагружается, `view` и просмотренное не повторяются.
  restart,

  /// Перелистнуть страницу на сторис [StoriesPlayback.turnTarget]; заход на неё
  /// случится, когда страница осядет ([StoriesPlayback.settle]).
  turn,

  /// Закрыть просмотр.
  close,
}

/// Сторис новой ленты за жизнь её объектов в процессе — как в вебе: с какого слайда
/// открыть (`start_position` сервера, дальше — где остановились) и ушли ли с неё вперёд
/// (тогда она просмотрена, как при `viewed` сервера). Новая лента — новые объекты сторис
/// и снова то, что считает сервер.
abstract final class StoriesServerProgress {
  static final Expando<int> _positions = Expando<int>('storiesPosition');
  static final Expando<bool> _left = Expando<bool>('storiesLeftForward');

  /// С какого слайда открыть [story]: где остановились, иначе `start_position`.
  static int startOf(Story story) {
    if (story.slides.isEmpty) return 0;
    return (_positions[story] ?? story.startPosition).clamp(
      0,
      story.slides.length - 1,
    );
  }

  /// Сторис просмотрена: так говорит сервер или с неё ушли вперёд.
  static bool viewedOf(Story story) => story.viewed || (_left[story] ?? false);

  /// Показан слайд [slide] сторис [story].
  static void showed(Story story, int slide) => _positions[story] = slide;

  /// С [story] ушли вперёд: просмотрена; [finished] — досмотрели до конца, в следующий
  /// раз — с начала.
  static void leftForward(Story story, {bool finished = false}) {
    _left[story] = true;
    if (finished) _positions[story] = 0;
  }
}

/// Слайд новой ленты, который не показывается, как в вебе: не фото и не видео, и без
/// элемента товара (`product`) — его пропускают по ходу листания, без `view`.
bool storySlideSkipped(StorySlide slide) =>
    slide.type == StorySlideType.product &&
    !slide.elements.any((element) => element is StoryProductElement);

/// Логика просмотра сторис без UI: какая сторис и какой слайд текущие, с какого слайда
/// открывать сторис, почему слайд стоит, открыта ли шторка, сколько прошло времени.
///
/// Правила (общие для всех платформ):
/// - слайд просмотрен в момент, когда он стал текущим на осевшей странице — не при
///   подглядывании соседней сторис наполовину свайпа ([settle]);
/// - сторис просмотрена, когда так считает сервер (`viewed`) или просмотрены все её
///   слайды ([isViewed]);
/// - сторис открывается: с первого непросмотренного слайда, если часть просмотрена; с
///   `start_position` сервера, если ничего; с начала, если просмотрена вся
///   ([startSlideOf]);
/// - назад на первом слайде первой сторис перезапускает слайд (только время — с нуля,
///   без нового захода), вперёд на последнем слайде последней — закрывает просмотр;
/// - пока раскрыта шторка товаров, слайды и сторис не листаются; любая смена слайда
///   шторку закрывает;
/// - время слайда копится только из реально прошедших промежутков и только пока ничто
///   его не держит — от масштаба анимаций системы оно не зависит.
///
/// Новая лента ([serverStart]), как в вебе: сторис открывается со слайда
/// [StoriesServerProgress.startOf], просмотренной становится, когда с неё ушли вперёд
/// (досмотрели последний слайд или перелистнули на следующую); просмотренное устройства не
/// решает. Слайды без медиа и без товара пропускаются ([storySlideSkipped]): листание
/// идёт мимо них в свою сторону, сторис открывается с ближайшего показываемого слайда
/// после стартового (после него нет — с первого показываемого).
///
/// Сторис без слайдов (у новой ленты — без показываемых) отбрасываются при создании.
class StoriesPlayback {
  /// [initialSlide] — слайд начальной сторис в обход правил стартового слайда (ссылка
  /// «Поделиться» открывает слайд ссылки); действует до первого захода на неё.
  StoriesPlayback({
    required List<Story> stories,
    int initialStory = 0,
    int? initialSlide,
    Map<String, Set<String>> seen = const <String, Set<String>>{},
    this.serverStart = false,
  }) : stories = List<Story>.unmodifiable(
         stories.where((story) => _playable(story, serverStart)),
       ),
       _seen = <String, Set<String>>{
         for (final entry in seen.entries) entry.key: <String>{...entry.value},
       } {
    // Начальный индекс дан по исходному списку: сторис без слайдов перед ним выпали.
    var kept = 0;
    for (var i = 0; i < stories.length && i < initialStory; i++) {
      if (_playable(stories[i], serverStart)) kept++;
    }
    _story = this.stories.isEmpty ? 0 : kept.clamp(0, this.stories.length - 1);
    _initialSlide = this.stories.isEmpty ? null : initialSlide;
  }

  /// Сторис есть что показать: у новой ленты — хоть один не пропускаемый слайд.
  static bool _playable(Story story, bool serverStart) => serverStart
      ? story.slides.any((slide) => !storySlideSkipped(slide))
      : story.slides.isNotEmpty;

  /// Слайд [index] сторис [story] показывается (у новой ленты — не пропускается).
  bool _shown(Story story, int index) =>
      !serverStart || !storySlideSkipped(story.slides[index]);

  /// Ближайший показываемый слайд [story] от [from] в сторону [step] (+1 / −1); нет —
  /// `null`.
  int? _nearest(Story story, int from, int step) {
    for (var i = from; i >= 0 && i < story.slides.length; i += step) {
      if (_shown(story, i)) return i;
    }
    return null;
  }

  /// Сторис со слайдами в порядке ленты.
  final List<Story> stories;

  /// Новая лента: стартовый слайд и просмотренность — [StoriesServerProgress].
  final bool serverStart;

  final Map<String, Set<String>> _seen;
  final Set<StoriesPauseReason> _reasons = <StoriesPauseReason>{};
  late int _story;
  int _slide = 0;
  int _generation = 0;
  bool _entered = false;
  bool _sheet = false;
  int? _turnTarget;

  /// Слайд начальной сторис в обход правил, пока на неё не зашли.
  int? _initialSlide;
  Duration _elapsed = Duration.zero;
  Duration _duration = Duration.zero;
  bool _byVideo = false;

  /// Самый длинный промежуток, который часы примут за раз: если кадры не шли (фон,
  /// зависание), слайд не проскакивает.
  static const Duration maxTick = Duration(seconds: 1);

  bool get isEmpty => stories.isEmpty;
  int get storyIndex => _story;
  int get slideIndex => _slide;
  Story get story => stories[_story];
  StorySlide get slide => story.slides[_slide];

  /// Номер захода на слайд: растёт при каждом заходе и при «Повторить». Загрузки
  /// прошлых заходов по нему отбрасываются.
  int get generation => _generation;

  /// Был ли заход хоть на один слайд (первая страница осела).
  bool get entered => _entered;
  bool get sheetOpen => _sheet;

  /// Часы идут: заход был, и ничто слайд не держит.
  bool get running => _entered && _reasons.isEmpty;
  Set<StoriesPauseReason> get reasons =>
      Set<StoriesPauseReason>.unmodifiable(_reasons);
  bool pausedBy(StoriesPauseReason reason) => _reasons.contains(reason);

  /// Куда листать после [StoriesStep.turn]; `null` — не листаем.
  int? get turnTarget => _turnTarget;

  /// Просмотренные слайды сторис [storyId].
  Set<String> seenOf(String storyId) =>
      Set<String>.unmodifiable(_seen[storyId] ?? const <String>{});

  /// Сколько прошло на текущем слайде.
  Duration get elapsed => _elapsed;

  /// Длительность текущего слайда: из админки, у видео — реальная длина ролика, у GIF —
  /// не меньше одного круга ([useGifLoop]).
  Duration get duration => _duration;

  /// Слайд длится столько, сколько ролик: конец — по концу видео, а не по часам.
  bool get followsVideo => _byVideo;

  /// Доля прошедшего времени слайда, 0…1.
  double get progress => _duration <= Duration.zero
      ? 0
      : (_elapsed.inMicroseconds / _duration.inMicroseconds).clamp(0.0, 1.0);

  /// Сторис просмотрена: так говорит сервер или просмотрены все её слайды.
  static bool isViewed(Story story, Set<String> seen) =>
      story.viewed ||
      (story.slides.isNotEmpty &&
          story.slides.every((slide) => seen.contains(slide.id)));

  /// С какого слайда открыть [story]: просмотрена — с начала; просмотрена частично —
  /// с первого непросмотренного по порядку; не начата — с `start_position` сервера.
  static int startSlideOf(Story story, Set<String> seen) {
    final slides = story.slides;
    if (slides.isEmpty || isViewed(story, seen)) return 0;
    if (slides.any((slide) => seen.contains(slide.id))) {
      final unseen = slides.indexWhere((slide) => !seen.contains(slide.id));
      return unseen < 0 ? 0 : unseen;
    }
    return story.startPosition.clamp(0, slides.length - 1);
  }

  /// Стартовый слайд сторис [index] по текущему состоянию просмотренного; у начальной
  /// сторис до первого захода — заданный при создании, если он был.
  int startSlideFor(int index) {
    final story = stories[index];
    final initial = _initialSlide;
    final int start;
    if (initial != null && index == _story && !_entered) {
      start = initial.clamp(0, story.slides.length - 1);
    } else if (serverStart) {
      start = StoriesServerProgress.startOf(story);
    } else {
      return startSlideOf(story, _seen[story.id] ?? const <String>{});
    }
    return _nearest(story, start, 1) ?? _nearest(story, 0, 1) ?? start;
  }

  /// Страница осела на сторис [index] (листанием, программно или при открытии).
  /// `true` — начался заход на её стартовый слайд; та же сторис — `false`, только
  /// снимается пауза листания.
  bool settle(int index) {
    _reasons.remove(StoriesPauseReason.drag);
    _turnTarget = null;
    if (stories.isEmpty) return false;
    final target = index.clamp(0, stories.length - 1);
    if (_entered && target == _story) return false;
    // Перелистнули вперёд — с прежней ушли вперёд.
    if (serverStart && _entered && target > _story) {
      StoriesServerProgress.leftForward(story);
    }
    _story = target;
    _slide = startSlideFor(target);
    _initialSlide = null;
    _enter();
    return true;
  }

  /// Вперёд: следующий слайд, следующая сторис или закрыть.
  StoriesStep next() {
    if (!_entered || _sheet || _turnTarget != null) return StoriesStep.none;
    if (_nearest(story, _slide + 1, 1) case final following?) {
      _slide = following;
      _enter();
      return StoriesStep.slide;
    }
    if (serverStart) StoriesServerProgress.leftForward(story, finished: true);
    if (_story < stories.length - 1) {
      _turnTo(_story + 1);
      return StoriesStep.turn;
    }
    return StoriesStep.close;
  }

  /// Назад: предыдущий слайд, предыдущая сторис или перезапуск первого слайда.
  StoriesStep previous() {
    if (!_entered || _sheet || _turnTarget != null) return StoriesStep.none;
    if (_nearest(story, _slide - 1, -1) case final before?) {
      _slide = before;
      _enter();
      return StoriesStep.slide;
    }
    if (_story > 0) {
      _turnTo(_story - 1);
      return StoriesStep.turn;
    }
    _elapsed = Duration.zero;
    return StoriesStep.restart;
  }

  /// Перелистнуть на сторис [index] программно (по id из хоста). Та же — `none`.
  StoriesStep turnTo(int index) {
    if (stories.isEmpty) return StoriesStep.none;
    final target = index.clamp(0, stories.length - 1);
    if (_entered && target == _story) return StoriesStep.none;
    _sheet = false;
    _reasons.remove(StoriesPauseReason.sheet);
    _turnTo(target);
    return StoriesStep.turn;
  }

  void _turnTo(int index) {
    _turnTarget = index;
    _reasons.add(StoriesPauseReason.drag);
  }

  /// Поставить на паузу по [reason]. `true` — состояние «идёт» поменялось.
  bool pause(StoriesPauseReason reason) {
    final was = running;
    _reasons.add(reason);
    return was != running;
  }

  /// Снять паузу по [reason]. `true` — состояние «идёт» поменялось.
  bool resume(StoriesPauseReason reason) {
    final was = running;
    _reasons.remove(reason);
    return was != running;
  }

  /// Раскрыть шторку товаров: слайд на паузе, листание заблокировано.
  bool openSheet() {
    if (!_entered || _sheet) return false;
    _sheet = true;
    _reasons.add(StoriesPauseReason.sheet);
    return true;
  }

  /// Свернуть шторку товаров.
  bool closeSheet() {
    if (!_sheet) return false;
    _sheet = false;
    _reasons.remove(StoriesPauseReason.sheet);
    return true;
  }

  /// Медиа захода [generation] готово: часы могут идти.
  void mediaReady(int generation) {
    if (generation != _generation) return;
    _reasons
      ..remove(StoriesPauseReason.loading)
      ..remove(StoriesPauseReason.error);
  }

  /// Медиа захода [generation] не загрузилось (или не успело за отведённое время).
  void mediaFailed(int generation) {
    if (generation != _generation) return;
    _reasons
      ..remove(StoriesPauseReason.loading)
      ..add(StoriesPauseReason.error);
  }

  /// «Повторить»: тот же слайд заново грузит медиа. Новый номер захода отбрасывает
  /// прошлые загрузки; просмотренным слайд уже отмечен.
  int retry() {
    _generation++;
    _elapsed = Duration.zero;
    _duration = slide.duration;
    _byVideo = false;
    _reasons
      ..remove(StoriesPauseReason.error)
      ..add(StoriesPauseReason.loading);
    return _generation;
  }

  /// Реальная длина видео текущего слайда; неизвестная (0) оставляет время админки.
  void useVideoDuration(Duration duration) {
    if (duration <= Duration.zero) return;
    _duration = duration;
    _byVideo = true;
  }

  /// Длина одного круга GIF текущего слайда: слайд длится время из админки или круг — что
  /// дольше; короткий GIF крутится до конца слайда, длинный проходит ровно один круг.
  /// Неизвестная длина (`null`: битый GIF, картинка хоста) — время из админки.
  void useGifLoop(Duration? loop) {
    final server = slide.duration;
    _duration = loop != null && loop > server ? loop : server;
  }

  /// Позиция видео: время слайда идёт за воспроизведением.
  void syncVideoPosition(Duration position) {
    if (!_byVideo) return;
    _elapsed = position > _duration ? _duration : position;
  }

  /// Прошло [delta] реального времени. `true` — слайд кончился по часам (у видео
  /// с известной длиной конец даёт само видео).
  bool tick(Duration delta) {
    if (!running || delta <= Duration.zero) return false;
    _elapsed += delta > maxTick ? maxTick : delta;
    if (_elapsed < _duration) return false;
    _elapsed = _duration;
    return !_byVideo;
  }

  void _enter() {
    _entered = true;
    _generation++;
    _sheet = false;
    _elapsed = Duration.zero;
    _duration = slide.duration;
    _byVideo = false;
    _reasons
      ..remove(StoriesPauseReason.sheet)
      ..remove(StoriesPauseReason.error)
      ..remove(StoriesPauseReason.poll)
      ..add(StoriesPauseReason.loading);
    (_seen[story.id] ??= <String>{}).add(slide.id);
    if (serverStart) StoriesServerProgress.showed(story, _slide);
  }
}

/// Таймер просмотра, который замирает: пока приложение в фоне или просмотр закрыт другим
/// экраном, время не идёт, а после возврата досчитывается остаток ([freeze], [resume]).
///
/// Считает шагами по [step] — так он идёт и на подменённых часах тестов; на заморозке
/// теряется не больше шага.
class StoriesTimer {
  /// Через [duration] — [onFire]; [frozen] — создать замороженным.
  StoriesTimer(Duration duration, void Function() onFire, {bool frozen = false})
    : _left = duration,
      _onFire = onFire {
    if (!frozen) _run();
  }

  static const Duration step = Duration(milliseconds: 100);

  final void Function() _onFire;
  Duration _left;
  Timer? _timer;
  bool _done = false;

  /// Сколько осталось.
  Duration get remaining => _left;

  /// Таймер ещё не сработал и не отменён.
  bool get isActive => !_done;

  /// Остановить отсчёт, сохранив остаток.
  void freeze() {
    _timer?.cancel();
    _timer = null;
  }

  /// Продолжить отсчёт с остатка.
  void resume() {
    if (_done || _timer != null) return;
    _run();
  }

  void cancel() {
    _done = true;
    freeze();
  }

  void _run() {
    _timer = Timer.periodic(step, (_) {
      _left -= step;
      if (_left > Duration.zero) return;
      cancel();
      _onFire();
    });
  }
}
