import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../stories/stories_response.dart';
import 'stories_polls_api.dart';

/// Тексты карточки опроса, как в вебе: `labels` элемента > тексты хоста > умолчания —
/// английские константы веба, на любом языке устройства и приложения. Пустой текст хоста
/// — не задан.
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

  /// Кнопка отправки, когда у опроса нет `submit_label`, и кнопка комментария к оценке
  /// шкалы.
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

  @override
  bool operator ==(Object other) =>
      other is StoryPollTexts &&
      other.reanswer == reanswer &&
      other.error == error &&
      other.submit == submit;

  @override
  int get hashCode => Object.hash(reanswer, error, submit);
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

/// Цвет цифры шкалы — семантический тон кита.
enum StoryPollScaleTone { danger, warning, success }

/// Тон цифры [value] шкалы [min]..[max], как цвета веба: у NPS 0..10 — 0–6 Danger, 7–8
/// Warning, 9–10 зелёный; у остальных — по третям диапазона.
StoryPollScaleTone storyPollScaleTone(
  StoryPollType kind,
  int value,
  int min,
  int max,
) {
  if (kind == StoryPollType.nps && min == 0 && max == 10) {
    if (value <= 6) return StoryPollScaleTone.danger;
    return value <= 8 ? StoryPollScaleTone.warning : StoryPollScaleTone.success;
  }
  final position = max > min ? (value - min) / (max - min) : 1;
  if (position < 0.34) return StoryPollScaleTone.danger;
  return position < 0.68
      ? StoryPollScaleTone.warning
      : StoryPollScaleTone.success;
}

/// Длина комментария к оценке шкалы — ответа на вопрос полосы.
const int storyPollCommentMaxLength = 5000;

/// Полоса шкалы, где `from ≤ rate ≤ to`; нет такой — `null`.
StoryPollBand? storyPollBandOf(StoryPollElement poll, num? rate) {
  if (rate == null) return null;
  for (final band in poll.bands) {
    if (rate >= band.from && rate <= band.to) return band;
  }
  return null;
}

/// Текст `success` полосы оценки [rate]; нет — `null`.
String? storyPollBandText(StoryPollElement poll, num? rate) =>
    storyPollBandOf(poll, rate)?.success;

/// Вопрос полосы оценки [rate] без пробелов по краям; нет или пустой — `null`.
String? storyPollBandQuestion(StoryPollElement poll, num? rate) {
  final question = storyPollBandOf(poll, rate)?.question?.trim() ?? '';
  return question.isEmpty ? null : question;
}

/// Ответ опроса и итоги, как их показать.
typedef StoryPollState = ({StoryPollAnswer? answer, StoryPollResults? results});

/// Где опрос: магазин и устройство (`did`) — пространство ответов, кампания и слайд.
typedef StoryPollPlace = ({
  String shopId,
  String did,
  String storyId,
  String slideId,
});

/// Ответы опросов на устройстве — как `localStorage` веба:
/// - запись — `{answer, results, saved_at}` (мс эпохи) в SharedPreferences под ключом
///   `personalization.storiesPolls.<магазин>.stories_poll_<did>_<вид>_<код>_<сторис>_<слайд>`
///   ([keyOf]); без `did` ничего не читается и не пишется;
/// - живёт 90 дней ([ttl]): старше, без даты или нечитаемая — удаляется при чтении;
/// - что показать ([stateOf]): ответ, отправленный с этого же элемента ленты (так веб
///   меняет элемент ленты в кэше), > ответ свежей ленты > ответ, отправленный раньше в
///   этом процессе с того же места > сохранённое > ничего.
class StoryPollStore {
  StoryPollStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Хранилище процесса. Тесты подменяют его.
  static StoryPollStore instance = StoryPollStore();

  /// Сколько помнить ответ — столько же лента сервера помнит его сама.
  static const Duration ttl = Duration(days: 90);

  static const String _prefix = 'personalization.storiesPolls';

  final DateTime Function() _clock;
  final Expando<StoryPollState> _sent = Expando<StoryPollState>('storyPoll');

  /// Отправленное в этом процессе по месту опроса — и без `did`.
  final Map<String, StoryPollState> _process = <String, StoryPollState>{};

  static String _placeKey(StoryPollElement poll, StoryPollPlace place) =>
      '${place.shopId}\u0000${place.did}\u0000${poll.pollType.wire}\u0000'
      '${poll.code}\u0000${place.storyId}\u0000${place.slideId}';
  SharedPreferences? _preferences;
  Future<void>? _opening;

  /// Записи устройства читаются без ожидания: хранилище открыто ([load]).
  bool get ready => _preferences != null;

  /// Открыть хранилище устройства; ошибка — ответы живут только в памяти.
  Future<void> load() => _opening ??= _open();

  Future<void> _open() async {
    try {
      _preferences = await SharedPreferences.getInstance();
    } catch (error) {
      debugPrint(
        'PersonalizationStories: saved poll answers unavailable — $error',
      );
    }
  }

  /// Ключ записи опроса [poll] в месте [place]; без `did` — `null`.
  static String? keyOf(StoryPollElement poll, StoryPollPlace place) {
    if (place.did.isEmpty) return null;
    return '$_prefix.${place.shopId}.stories_poll_${place.did}_'
        '${poll.pollType.wire}_${poll.code}_${place.storyId}_${place.slideId}';
  }

  /// Что показать у опроса [poll] сейчас: отправленное с этого элемента, ответ свежей
  /// ленты, отправленное раньше в процессе с того же места, сохранённое на устройстве
  /// ([saved]); ничего — ответ и итоги ленты как есть.
  StoryPollState stateOf(StoryPollElement poll, StoryPollPlace place) {
    final sent = _sent[poll];
    if (sent != null) return sent;
    final feed = (answer: poll.answer, results: poll.results);
    if (poll.answer != null) return feed;
    return _process[_placeKey(poll, place)] ?? saved(poll, place) ?? feed;
  }

  /// Ответ [poll] отправлен в этом процессе — с этого элемента или с его места.
  bool sentOf(StoryPollElement poll, StoryPollPlace place) =>
      _sent[poll] != null || _process.containsKey(_placeKey(poll, place));

  /// Сохранённая запись опроса [poll]; нет, без `did`, хранилище не открыто, битая —
  /// `null`. Старше [ttl] или без даты — удаляется.
  StoryPollState? saved(StoryPollElement poll, StoryPollPlace place) {
    final key = keyOf(poll, place);
    final preferences = _preferences;
    if (key == null || preferences == null) return null;
    try {
      final raw = preferences.getString(key);
      if (raw == null) return null;
      final value = jsonDecode(raw);
      final savedAt = value is Map ? value['saved_at'] : null;
      if (value is! Map ||
          value['answer'] is! Map ||
          savedAt is! num ||
          _clock().millisecondsSinceEpoch - savedAt > ttl.inMilliseconds) {
        _drop(preferences, key);
        return null;
      }
      return (
        answer: StoryPollAnswer.tryParse(value['answer']),
        results: StoryPollResults.tryParse(value['results']),
      );
    } catch (error) {
      // Не прочитать — запись удаляется, как устаревшая.
      debugPrint('PersonalizationStories: saved poll answer dropped — $error');
      _drop(preferences, key);
      return null;
    }
  }

  static void _drop(SharedPreferences preferences, String key) {
    try {
      preferences.remove(key).ignore();
    } catch (_) {
      // Хранилище не удаляет — запись останется до следующего чтения.
    }
  }

  /// Ответ [state] опроса [poll] отправлен: он заменяет ответ этого элемента ленты в
  /// процессе и пишется на устройство (без `did` — только в процессе). Не бросает:
  /// запись, которую не сохранить, остаётся только в процессе.
  void write(
    StoryPollElement poll,
    StoryPollPlace place,
    StoryPollState state,
  ) {
    _sent[poll] = state;
    _process[_placeKey(poll, place)] = state;
    final key = keyOf(poll, place);
    if (key == null) return;
    final String record;
    try {
      record = jsonEncode(<String, Object?>{
        'answer': (state.answer ?? const StoryPollAnswer()).toJson(),
        'results': state.results?.toJson(),
        'saved_at': _clock().millisecondsSinceEpoch,
      });
    } catch (error) {
      debugPrint('PersonalizationStories: poll answer not saved — $error');
      return;
    }
    unawaited(_save(key, record));
  }

  Future<void> _save(String key, String record) async {
    await load();
    try {
      await _preferences?.setString(key, record);
    } catch (error) {
      debugPrint('PersonalizationStories: poll answer not saved — $error');
    }
  }
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
/// - Состояния: форма и отвеченное ([answered]). Что показать сначала — [StoryPollStore]
///   ([StoryPollStore.stateOf]); отвечено, как `hasAnswer` веба, когда в ответе есть
///   варианты, непустой текст или оценка (после удачной отправки — сразу).
/// - Выбор одного и шкала отправляются нажатием ([choose], [rate]); выбор сразу
///   подсвечен, при ошибке откатывается к прежнему. Выбор нескольких и текст — кнопкой
///   ([submitChoices], [submitText]); варианты уходят в порядке опроса, текст — без
///   пробелов по краям.
/// - Шкала: у полосы оценки есть вопрос, а у ответа нет комментария — после оценки
///   вопрос и поле ([followUp]); [submitComment] шлёт ту же оценку с комментарием, потом
///   `success` полосы. Ушли со слайда без комментария — при следующем показе вопрос снова.
/// - Пока идёт отправка ([sending]), всё выключено, повторы игнорируются. Ошибка —
///   [failed], всё снова доступно, автоповтора нет; в лог её пишет транспорт.
/// - [reanswer] при `allow_reanswer` возвращает форму с прежним ответом (у текста —
///   пустое поле); новая оценка шкалы уходит без комментария.
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
    this.did = '',
    StoryPollTexts texts = const StoryPollTexts(),
    this.onHold,
    bool active = true,
    StoryPollStore? store,
  }) : hostTexts = texts,
       _active = active,
       _store = store ?? StoryPollStore.instance {
    _show(_store.stateOf(poll, _place));
    // Хранилище устройства ещё не открыто — сохранённое придёт позже, если до тех пор
    // карточку не трогали.
    if (!_store.ready && did.isNotEmpty && poll.answer == null) {
      _store.load().then((_) {
        if (_disposed || _touched || _store.sentOf(poll, _place)) return;
        final saved = _store.saved(poll, _place);
        if (saved == null) return;
        _show(saved);
        _changed();
      });
    }
  }

  final StoryPollElement poll;
  final String storyId;
  final String slideId;
  final StoryPollsTransport transport;

  /// Магазин — часть ключа сохранённых ответов.
  final String shopId;

  /// Устройство (`did`) — часть ключа сохранённых ответов; пусто — ответ живёт только в
  /// процессе.
  final String did;

  /// Тексты хоста.
  final StoryPollTexts hostTexts;

  /// Держать слайд (`true`) или отпустить.
  final ValueChanged<bool>? onHold;
  final StoryPollStore _store;

  StoryPollAnswer? _answer;
  StoryPollResults? _results;
  bool _answered = false;
  bool _sending = false;
  bool _failed = false;
  bool _touched = false;
  Set<int> _selected = const <int>{};
  num? _rate;
  String _text = '';
  bool _pressed = false;
  bool _focused = false;
  bool _active;
  bool _held = false;
  bool _disposed = false;

  StoryPollPlace get _place =>
      (shopId: shopId, did: did, storyId: storyId, slideId: slideId);

  /// Тексты с учётом `labels` опроса.
  StoryPollTexts get texts => hostTexts.forPoll(poll);

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

  /// Вопрос полосы отвеченной оценки, пока к ней нет комментария; иначе `null`.
  String? get followUp {
    if (!_answered || !poll.pollType.isScale) return null;
    final answer = _answer;
    if (answer == null || answer.rate == null) return null;
    if ((answer.comment ?? '').isNotEmpty) return null;
    return storyPollBandQuestion(poll, answer.rate);
  }

  /// На карточке поле ввода: форма текстового опроса или вопрос полосы шкалы.
  bool get showsField =>
      (!_answered && poll.kind == StoryMiniPollKind.text) || followUp != null;

  /// Предел длины поля: `max_length` текстового опроса, у комментария — 5000.
  int? get fieldLimit =>
      followUp != null ? storyPollCommentMaxLength : poll.maxLength;

  /// Кнопка отправки доступна.
  bool get canSubmit {
    if (_sending) return false;
    if (followUp != null) return _text.trim().isNotEmpty;
    return switch (poll.kind) {
      StoryMiniPollKind.multipleChoice => _selected.isNotEmpty,
      StoryMiniPollKind.text => _text.trim().isNotEmpty,
      _ => false,
    };
  }

  /// Слайд держится.
  bool get holding => _held;

  /// Отвечено — как `hasAnswer` веба: в ответе есть варианты, непустой текст или оценка.
  void _show(StoryPollState state) {
    _answer = state.answer;
    _results = state.results;
    _answered = _answer?.isAnswered ?? false;
    _resetForm();
  }

  void _resetForm() {
    final previous = <int>{...?_answer?.optionIds};
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
    _touched = true;
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
    _touched = true;
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

  /// Шкала: оценка [value] сразу подсвечена и отправлена — без комментария.
  void rate(int value) {
    if (_answered || _sending || _disposed || !poll.pollType.isScale) return;
    final previous = _rate;
    _rate = value;
    _send(
      () => transport.review(
        poll.pollType,
        storyPollReviewBody(poll, value, storyId: storyId, slideId: slideId),
      ),
      sent: StoryPollAnswer(rate: value),
      scale: true,
      rollback: () => _rate = previous,
    );
  }

  /// Вопрос полосы: та же оценка ещё раз — с комментарием из поля без пробелов по краям.
  void submitComment() {
    final rate = _answer?.rate;
    final value = _text.trim();
    if (followUp == null || rate == null || value.isEmpty || !canSubmit) {
      return;
    }
    _send(
      () => transport.review(
        poll.pollType,
        storyPollReviewBody(
          poll,
          rate,
          comment: value,
          storyId: storyId,
          slideId: slideId,
        ),
      ),
      sent: StoryPollAnswer(rate: rate, comment: value),
      scale: true,
    );
  }

  /// «Ответить заново»: снова форма с прежним ответом.
  void reanswer() {
    if (!_answered || !poll.allowReanswer || _sending || _disposed) return;
    _touched = true;
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
    _touched = true;
    _sending = true;
    _failed = false;
    _changed();
    final StoryPollReply reply;
    try {
      reply = await request();
    } catch (_) {
      // Лог ошибки — забота транспорта.
      if (_disposed) return;
      _sending = false;
      _failed = true;
      rollback?.call();
      _changed();
      return;
    }
    // Сервер ответ принял: сначала карточка, потом хранилище — сбой хранилища ответ не
    // откатывает.
    // У шкалы ответ — сама оценка (и комментарий), итогов нет.
    final StoryPollState state = scale
        ? (answer: sent, results: null)
        : (answer: reply.answer ?? sent, results: reply.results);
    if (!_disposed) {
      _answer = state.answer;
      _results = state.results;
      _answered = true;
      _sending = false;
      _text = '';
      _changed();
    }
    try {
      _store.write(poll, _place, state);
    } catch (error) {
      debugPrint('PersonalizationStories: poll answer not saved — $error');
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

/// Опросы слайда — все элементы `poll` по порядку, как их рисует веб.
List<StoryPollElement> storyPollsOf(StorySlide slide) =>
    slide.elements.whereType<StoryPollElement>().toList();
