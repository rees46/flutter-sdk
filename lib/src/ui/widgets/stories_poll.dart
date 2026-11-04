import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../stories/stories_response.dart';
import 'stories_polls_api.dart';

/// Тексты карточки опроса: умолчания < тексты хоста < `labels` элемента.
@immutable
class StoryPollTexts {
  const StoryPollTexts({
    this.reanswer = defaultReanswer,
    this.error = defaultError,
    this.submit = defaultSubmit,
  });

  static const String defaultReanswer = 'Answer again';
  static const String defaultError =
      'Failed to send the answer. Please try again';
  static const String defaultSubmit = 'Send';

  /// Ссылка «Ответить заново» у отвеченного опроса с `allow_reanswer`.
  final String reanswer;

  /// Отправка не удалась.
  final String error;

  /// Кнопка отправки, когда у опроса нет `submit_label`.
  final String submit;

  /// Тексты для [poll]: непустые `labels` сервера, иначе непустые тексты хоста, иначе
  /// умолчания.
  StoryPollTexts forPoll(StoryPollElement poll) {
    String pick(String? label, String host, String fallback) =>
        label ?? (host.isNotEmpty ? host : fallback);
    return StoryPollTexts(
      reanswer: pick(poll.labels.reanswer, reanswer, defaultReanswer),
      error: pick(poll.labels.error, error, defaultError),
      submit: pick(poll.labels.submit, submit, defaultSubmit),
    );
  }
}

/// Тексты итогов опроса с выбором: шапка «Результаты», «Спасибо! Голос учтён» и число
/// голосов. Язык — устройства, как у текстов попапов v3: русский для `ru`, остальные —
/// английский.
@immutable
class StoryPollResultTexts {
  const StoryPollResultTexts._({
    required this.results,
    required this.thanks,
    required this.counted,
    required bool russian,
  }) : _russian = russian;

  static const StoryPollResultTexts ru = StoryPollResultTexts._(
    results: 'Результаты',
    thanks: 'Спасибо!',
    counted: 'Голос учтён',
    russian: true,
  );

  static const StoryPollResultTexts en = StoryPollResultTexts._(
    results: 'Results',
    thanks: 'Thank you!',
    counted: 'Vote counted',
    russian: false,
  );

  /// По коду языка [language]: `ru` — русский, остальные — английский.
  static StoryPollResultTexts of(String language) => language == 'ru' ? ru : en;

  /// Шапка итогов; на карточке — прописными.
  final String results;

  /// Благодарность, когда у опроса нет своего `thanks_text`.
  final String thanks;

  /// Продолжение благодарности.
  final String counted;
  final bool _russian;

  /// Число голосов [count] с разрядами (у русского — неразрывный пробел) и склонением:
  /// «1 голос», «1 248 голосов», «1 vote», «1,248 votes».
  String votes(int count) {
    final number = _grouped(count, _russian ? '\u00A0' : ',');
    if (!_russian) return '$number ${count == 1 ? 'vote' : 'votes'}';
    final tens = count.abs() % 100;
    final ones = count.abs() % 10;
    final noun = ones == 1 && tens != 11
        ? 'голос'
        : ones >= 2 && ones <= 4 && (tens < 12 || tens > 14)
        ? 'голоса'
        : 'голосов';
    return '$number $noun';
  }

  static String _grouped(int value, String separator) {
    final digits = value.abs().toString();
    final out = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(separator);
      out.write(digits[i]);
    }
    return out.toString();
  }
}

/// Оценки шкалы: `rate_min..rate_max`, по умолчанию NPS 0..10, CSAT 1..5, CES 1..7; не
/// больше 21 значения.
List<int> storyPollScaleRange(StoryPollElement poll) {
  final (min, max) = switch (poll.pollType) {
    StoryPollType.nps => (0, 10),
    StoryPollType.csat => (1, 5),
    _ => (1, 7),
  };
  final from = poll.rateMin ?? min;
  final to = poll.rateMax ?? max;
  return <int>[
    for (var value = from; value <= to && value - from <= 20; value++) value,
  ];
}

const List<Color> _npsColors = <Color>[
  Color(0xFFFCA5A5),
  Color(0xFFFCA5A5),
  Color(0xFFFCA5A5),
  Color(0xFFFDBA74),
  Color(0xFFFDBA74),
  Color(0xFFFDBA74),
  Color(0xFFFCD34D),
];

/// Цвет ячейки [value] шкалы [min]..[max]: NPS 0..10 — 0–6 красные и оранжевые, 7–8
/// жёлтые, 9–10 зелёные; остальные — по третям диапазона.
Color storyPollScaleColor(StoryPollType kind, int value, int min, int max) {
  if (kind == StoryPollType.nps && min == 0 && max == 10) {
    if (value <= 6) return _npsColors[math.max(0, value)];
    return value <= 8 ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC);
  }
  final position = max > min ? (value - min) / (max - min) : 1;
  if (position < 0.34) return const Color(0xFFFCA5A5);
  return position < 0.68 ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC);
}

/// Текст `success` полосы шкалы, где `from ≤ rate ≤ to`; нет такой — `null`.
String? storyPollBandText(StoryPollElement poll, num? rate) {
  if (rate == null) return null;
  for (final band in poll.bands) {
    if (rate >= band.from && rate <= band.to) return band.success;
  }
  return null;
}

/// Ответ опроса и итоги, как их показать.
typedef StoryPollState = ({StoryPollAnswer? answer, StoryPollResults? results});

/// Ответы опросов за сессию: в памяти процесса, одно на все виджеты, `show` и
/// `handleLink`. Ключ — магазин, вид опроса и код. Важнее ответа из ленты: лента
/// сторис не перезагружается после ответа. На диск не пишется.
class StoryPollStore {
  /// Хранилище процесса. Тесты подменяют его.
  static StoryPollStore instance = StoryPollStore();

  final Map<String, StoryPollState> _states = <String, StoryPollState>{};

  static String _key(String shopId, StoryPollElement poll) =>
      '$shopId\n${poll.pollType.wire}\n${poll.code}';

  /// Сохранённый ответ опроса [poll] магазина [shopId]; нет — `null`.
  StoryPollState? read(String shopId, StoryPollElement poll) =>
      _states[_key(shopId, poll)];

  void write(String shopId, StoryPollElement poll, StoryPollState state) =>
      _states[_key(shopId, poll)] = state;
}

/// Касания, начатые на карточке опроса или на подложке под открытой клавиатурой: слайд
/// их не берёт — ни касание по третям, ни удержание. Карточка отмечает касание раньше,
/// чем его увидит слайд: глубокие получатели касаний идут первыми.
abstract final class StoryPollPointers {
  static final Set<int> _claimed = <int>{};

  static void claim(int pointer) => _claimed.add(pointer);

  static void release(int pointer) => _claimed.remove(pointer);

  static bool claimed(int pointer) => _claimed.contains(pointer);
}

/// Логика карточки опроса — как `createPoll` веб-SDK, без UI.
///
/// - Состояния: форма и отвеченное ([answered]). Отвеченное — когда есть запись хранилища
///   сессии ([StoryPollStore]) или у ответа ленты есть варианты, текст или оценка.
/// - Выбор одного и шкала отправляются нажатием ([choose], [rate]); выбор сразу
///   подсвечен, при ошибке откатывается к прежнему. Выбор нескольких и текст — кнопкой
///   ([submitChoices], [submitText]); варианты уходят в порядке опроса, текст — без
///   пробелов по краям.
/// - Пока идёт отправка ([sending]), всё выключено, повторы игнорируются. Ошибка —
///   [failed], всё снова доступно, автоповтора нет; в лог её пишет транспорт.
/// - [reanswer] при `allow_reanswer` возвращает форму с прежним ответом (у текста —
///   пустое поле).
/// - Слайд держит [onHold]: пока карточку держат пальцем ([pressed]), в фокусе поле
///   ([focused]) или идёт отправка — и только пока карточка [active] (живой слайд).
///
/// Ответ пишется в хранилище и после [dispose] — карточку уже убрали (сменили слайд,
/// закрыли просмотр); тогда ни состояние, ни [onHold] не трогаются.
class StoryPollController extends ChangeNotifier {
  StoryPollController({
    required this.poll,
    required this.storyId,
    required this.slideId,
    required this.transport,
    this.shopId = '',
    StoryPollTexts texts = const StoryPollTexts(),
    this.onHold,
    bool active = true,
    StoryPollStore? store,
  }) : texts = texts.forPoll(poll),
       _active = active,
       _store = store ?? StoryPollStore.instance {
    final saved = _store.read(shopId, poll);
    _answer = saved != null ? saved.answer : poll.answer;
    _results = saved != null ? saved.results : poll.results;
    // Запись хранилища — это успешная отправка: отвечено, даже если ответ ничего не
    // выделяет.
    _answered = saved != null || (_answer?.isAnswered ?? false);
    _resetForm();
  }

  final StoryPollElement poll;
  final String storyId;
  final String slideId;
  final StoryPollsTransport transport;

  /// Магазин — часть ключа хранилища.
  final String shopId;

  /// Тексты с учётом `labels` опроса.
  final StoryPollTexts texts;

  /// Держать слайд (`true`) или отпустить.
  final ValueChanged<bool>? onHold;
  final StoryPollStore _store;

  StoryPollAnswer? _answer;
  StoryPollResults? _results;
  bool _answered = false;
  bool _sending = false;
  bool _failed = false;
  Set<int> _selected = const <int>{};
  num? _rate;
  String _text = '';
  bool _pressed = false;
  bool _focused = false;
  bool _active;
  bool _held = false;
  bool _disposed = false;

  StoryPollAnswer? get answer => _answer;
  StoryPollResults? get results => _results;
  bool get answered => _answered;
  bool get sending => _sending;

  /// Последняя отправка не удалась.
  bool get failed => _failed;

  /// Подсвеченные варианты: выбор одного — нажатый, выбор нескольких — отмеченные.
  Set<int> get selected => Set<int>.unmodifiable(_selected);

  /// Подсвеченная оценка шкалы: нажатая в форме или отвеченная.
  num? get rateValue => _answered ? _answer?.rate : _rate;
  String get text => _text;

  /// На карточке поле ввода (форма текстового опроса).
  bool get showsField => !_answered && poll.kind == StoryMiniPollKind.text;

  /// Кнопка отправки доступна.
  bool get canSubmit =>
      !_sending &&
      switch (poll.kind) {
        StoryMiniPollKind.multipleChoice => _selected.isNotEmpty,
        StoryMiniPollKind.text => _text.trim().isNotEmpty,
        _ => false,
      };

  /// Слайд держится.
  bool get holding => _held;

  Set<int> get _previousIds => <int>{...?_answer?.optionIds};

  void _resetForm() {
    final previous = _previousIds;
    _selected = <int>{
      for (final option in poll.options)
        if (previous.contains(option.id)) option.id,
    };
    _rate = _answer?.rate;
    _text = '';
  }

  set pressed(bool value) {
    if (_pressed == value) return;
    _pressed = value;
    _syncHold();
  }

  set focused(bool value) {
    if (_focused == value) return;
    _focused = value;
    _syncHold();
  }

  /// Карточка на живом слайде: только тогда она держит слайд.
  set active(bool value) {
    if (_active == value) return;
    _active = value;
    _syncHold();
  }

  /// Выбор одного: вариант [id] сразу подсвечен и отправлен.
  void choose(int id) {
    if (_answered || _sending || _disposed) return;
    final previous = _selected;
    _selected = <int>{id};
    _send(
      () => transport.answerMiniPoll(
        poll.code,
        storyPollAnswerBody(
          optionIds: <int>[id],
          storyId: storyId,
          slideId: slideId,
        ),
      ),
      sent: StoryPollAnswer(optionIds: <int>[id]),
      rollback: () => _selected = previous,
    );
  }

  /// Выбор нескольких: отметить или снять вариант [id].
  void toggle(int id) {
    if (_answered || _sending || _disposed) return;
    _selected = <int>{..._selected};
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  /// Выбор нескольких: отправить отмеченное в порядке вариантов опроса.
  void submitChoices() {
    if (!canSubmit ||
        _answered ||
        poll.kind != StoryMiniPollKind.multipleChoice) {
      return;
    }
    final ids = <int>[
      for (final option in poll.options)
        if (_selected.contains(option.id)) option.id,
    ];
    _send(
      () => transport.answerMiniPoll(
        poll.code,
        storyPollAnswerBody(optionIds: ids, storyId: storyId, slideId: slideId),
      ),
      sent: StoryPollAnswer(optionIds: ids),
    );
  }

  /// Текст поля поменялся.
  set text(String value) {
    if (_text == value || _disposed) return;
    _text = value;
    notifyListeners();
  }

  /// Текстовый опрос: отправить текст без пробелов по краям.
  void submitText() {
    final value = _text.trim();
    if (!canSubmit || _answered || value.isEmpty) return;
    _send(
      () => transport.answerMiniPoll(
        poll.code,
        storyPollAnswerBody(text: value, storyId: storyId, slideId: slideId),
      ),
      sent: StoryPollAnswer(text: value),
    );
  }

  /// Шкала: оценка [value] сразу подсвечена и отправлена.
  void rate(int value) {
    if (_answered || _sending || _disposed || !poll.pollType.isScale) return;
    final previous = _rate;
    _rate = value;
    _send(
      () => transport.review(poll.pollType, storyPollReviewBody(poll, value)),
      sent: StoryPollAnswer(rate: value),
      scale: true,
      rollback: () => _rate = previous,
    );
  }

  /// «Ответить заново»: снова форма с прежним ответом.
  void reanswer() {
    if (!_answered || !poll.allowReanswer || _sending || _disposed) return;
    _answered = false;
    _failed = false;
    _resetForm();
    _changed();
  }

  Future<void> _send(
    Future<StoryPollReply> Function() request, {
    required StoryPollAnswer sent,
    bool scale = false,
    VoidCallback? rollback,
  }) async {
    _sending = true;
    _failed = false;
    _changed();
    try {
      final reply = await request();
      // У шкалы ответ — сама оценка, итогов нет.
      final StoryPollState state = scale
          ? (answer: sent, results: null)
          : (answer: reply.answer ?? sent, results: reply.results);
      _store.write(shopId, poll, state);
      if (_disposed) return;
      _answer = state.answer;
      _results = state.results;
      _answered = true;
      _sending = false;
      _changed();
    } catch (_) {
      // Лог ошибки — забота транспорта.
      if (_disposed) return;
      _sending = false;
      _failed = true;
      rollback?.call();
      _changed();
    }
  }

  void _changed() {
    _syncHold();
    notifyListeners();
  }

  void _syncHold() {
    final hold =
        !_disposed &&
        _active &&
        (_pressed || (_focused && showsField) || _sending);
    if (hold == _held) return;
    _held = hold;
    onHold?.call(hold);
  }

  /// Держала слайд — отпускает.
  @override
  void dispose() {
    _disposed = true;
    _syncHold();
    super.dispose();
  }
}

/// Опрос слайда — первый элемент `poll`; нет — `null`.
StoryPollElement? storyPollOf(StorySlide slide) {
  for (final element in slide.elements) {
    if (element is StoryPollElement) return element;
  }
  return null;
}
