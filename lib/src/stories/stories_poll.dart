part of 'stories_response.dart';

/// Вид опроса элемента `poll` (`poll_type`).
enum StoryPollType {
  miniPoll('mini_poll'),
  nps('nps'),
  csat('csat'),
  ces('ces');

  const StoryPollType(this.wire);

  /// Значение `poll_type` и сегмент пути `/api/v3/polls/{kind}/reviews` у шкал.
  final String wire;

  /// NPS, CSAT или CES — шкала оценок.
  bool get isScale => this != StoryPollType.miniPoll;

  static StoryPollType? _parse(Object? value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}

/// Вид мини-опроса (`poll.kind`).
enum StoryMiniPollKind {
  singleChoice('single_choice'),
  multipleChoice('multiple_choice'),
  text('text');

  const StoryMiniPollKind(this.wire);

  final String wire;

  static StoryMiniPollKind? _parse(Object? value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

/// Вариант ответа мини-опроса.
class StoryPollOption {
  const StoryPollOption({required this.id, required this.label});

  final int id;
  final String label;
}

/// Полоса шкалы `from..to` и текст благодарности за оценку из неё.
class StoryPollBand {
  const StoryPollBand({required this.from, required this.to, this.success});

  final double from;
  final double to;

  /// Текст под отвеченной шкалой; `null` — не задан.
  final String? success;
}

/// Ответ посетителя: варианты, текст или оценка.
class StoryPollAnswer {
  const StoryPollAnswer({this.id, this.optionIds, this.text, this.rate});

  final int? id;
  final List<int>? optionIds;
  final String? text;

  /// Оценка шкалы. Дробная тоже ответ, но ни одну ячейку не подсвечивает.
  final num? rate;

  /// Ответ есть: непустые варианты, непустой текст или оценка.
  bool get isAnswered =>
      (optionIds?.isNotEmpty ?? false) ||
      (text?.isNotEmpty ?? false) ||
      rate != null;

  /// Ответ из JSON (`answer` ленты или `payload.answer` отправки); не объект — `null`.
  static StoryPollAnswer? tryParse(Object? json) {
    if (json is! Map) return null;
    final ids = json['option_ids'];
    final text = json['text'];
    return StoryPollAnswer(
      id: toIntOrNull(json['id']),
      optionIds: ids is List ? <int>[for (final id in ids) ?_whole(id)] : null,
      text: text is String ? text : null,
      rate: _number(json['rate']),
    );
  }
}

/// Итоги мини-опроса (`results`, только при `show_results`).
class StoryPollResults {
  const StoryPollResults({this.total = 0, this.options});

  final int total;

  /// Проценты вариантов; `null` — `options` не массив, процентов у вариантов нет.
  final List<({int id, double percent})>? options;

  /// Процент варианта [id] целым: округлён и зажат в 0…100, нет в итогах — 0. Без
  /// процентов вариантов ([options] `null`) — `null`.
  int? percentOf(int id) {
    final options = this.options;
    if (options == null) return null;
    for (final option in options) {
      if (option.id != id) continue;
      final percent = option.percent;
      return percent.isNaN ? 0 : percent.clamp(0, 100).round();
    }
    return 0;
  }

  /// Итоги из JSON; не объект — `null`.
  static StoryPollResults? tryParse(Object? json) {
    if (json is! Map) return null;
    final options = json['options'];
    return StoryPollResults(
      total: toIntOrNull(json['total']) ?? 0,
      options: options is List
          ? <({int id, double percent})>[
              for (final option in _maps(options))
                if (_whole(option['id']) case final id?)
                  (id: id, percent: toDoubleOrNull(option['percent']) ?? 0),
            ]
          : null,
    );
  }
}

/// Тексты карточки от сервера (`labels`): `null` — не прислан, берётся текст хоста.
class StoryPollLabels {
  const StoryPollLabels({this.reanswer, this.error, this.submit});

  /// Ссылка «Ответить заново».
  final String? reanswer;

  /// Отправка не удалась.
  final String? error;

  /// Кнопка отправки, когда у опроса нет `submit_label`.
  final String? submit;
}

/// `poll`: опрос на слайде — мини-опрос (выбор одного, нескольких, текст) или шкала
/// NPS / CSAT / CES. Приходит только в ленте API v3.
///
/// Разбор терпимый: числа строками, `null` в необязательных полях. Неизвестный
/// `poll_type` или `kind` и битый элемент — `null` при разборе (элемент пропускается).
class StoryPollElement extends StoryElement {
  const StoryPollElement({
    required this.pollType,
    this.kind,
    required this.code,
    this.yOffset,
    this.allowReanswer = false,
    this.question = '',
    this.placeholder = '',
    this.maxLength,
    this.submitLabel = '',
    this.thanksText = '',
    this.showResults = false,
    this.options = const [],
    this.channel = '',
    this.name = '',
    this.rateMin,
    this.rateMax,
    this.bands = const [],
    this.answer,
    this.results,
    this.labels = const StoryPollLabels(),
  });

  final StoryPollType pollType;

  /// Вид мини-опроса; у шкал `null`.
  final StoryMiniPollKind? kind;

  /// Код опроса: мини-опроса — в пути запроса, шкалы — `category` (NPS) или `campaign`.
  final String code;

  /// Верх карточки в процентах высоты, 0…100; `null` (не задан или не число) — 0.
  final double? yOffset;

  /// Можно ответить заново: у отвеченного — ссылка «Ответить заново».
  final bool allowReanswer;
  final String question;

  // Мини-опрос.
  final String placeholder;

  /// Предел длины текстового ответа; `null` — без предела.
  final int? maxLength;
  final String submitLabel;
  final String thanksText;
  final bool showResults;
  final List<StoryPollOption> options;

  // Шкала.
  /// Канал отзыва; пусто — `stories`.
  final String channel;
  final String name;

  /// Границы шкалы; не целые — `null`, берутся умолчания вида.
  final int? rateMin;
  final int? rateMax;
  final List<StoryPollBand> bands;

  /// Ответ посетителя из ленты; `null` — не отвечал.
  final StoryPollAnswer? answer;
  final StoryPollResults? results;
  final StoryPollLabels labels;

  /// Элемент из JSON; вид, который кит не рисует, и битый элемент — `null` и запись в
  /// отладочный лог.
  static StoryPollElement? tryParse(Map<String, dynamic> json) {
    try {
      return _parse(json);
    } catch (error) {
      debugPrint('PersonalizationStories: poll element skipped — $error');
      return null;
    }
  }

  static StoryPollElement? _parse(Map<String, dynamic> json) {
    final type = StoryPollType._parse(json['poll_type']);
    final poll = json['poll'];
    if (type == null || poll is! Map) {
      debugPrint(
        type == null
            ? 'PersonalizationStories: poll "${json['poll_type']}" is not supported'
            : 'PersonalizationStories: poll "${type.wire}" without "poll"',
      );
      return null;
    }
    final kind = StoryMiniPollKind._parse(poll['kind']);
    if (type == StoryPollType.miniPoll && kind == null) {
      debugPrint(
        'PersonalizationStories: mini poll "${poll['kind']}" is not supported',
      );
      return null;
    }
    final labels = json['labels'];
    String? label(String key) =>
        labels is Map ? toNonEmptyStringOrNull(labels[key]) : null;
    final maxLength = toIntOrNull(poll['max_length']);
    final yOffset = toDoubleOrNull(json['y_offset']);
    return StoryPollElement(
      pollType: type,
      kind: type == StoryPollType.miniPoll ? kind : null,
      code: poll['code']?.toString() ?? '',
      yOffset: yOffset != null && yOffset.isFinite ? yOffset : null,
      allowReanswer: _flag(json['allow_reanswer']),
      question: _text(poll['question']),
      placeholder: _text(poll['placeholder']),
      maxLength: maxLength != null && maxLength > 0 ? maxLength : null,
      submitLabel: _text(poll['submit_label']),
      thanksText: _text(poll['thanks_text']),
      showResults: _flag(poll['show_results']),
      options: <StoryPollOption>[
        for (final option in _maps(poll['options']))
          if (_whole(option['id']) case final id?)
            StoryPollOption(id: id, label: _text(option['label'])),
      ],
      channel: _text(poll['channel']),
      name: _text(poll['name']),
      rateMin: _whole(poll['rate_min']),
      rateMax: _whole(poll['rate_max']),
      bands: <StoryPollBand>[
        for (final band in _maps(poll['bands']))
          if ((toDoubleOrNull(band['from']), toDoubleOrNull(band['to'])) case (
            final from?,
            final to?,
          ))
            StoryPollBand(
              from: from,
              to: to,
              success: toNonEmptyStringOrNull(band['success']),
            ),
      ],
      answer: StoryPollAnswer.tryParse(json['answer']),
      results: StoryPollResults.tryParse(json['results']),
      labels: StoryPollLabels(
        reanswer: label('reanswer'),
        error: label('error'),
        submit: label('submit'),
      ),
    );
  }
}

/// Флаг опроса: истина — только `true`, `1` или `"true"`, остальное — ложь.
bool _flag(Object? value) => value == true || value == 1 || value == 'true';

/// Число, в том числе строкой; не число и не конечное — `null`.
num? _number(Object? value) {
  final number = value is String ? num.tryParse(value.trim()) : value;
  return number is num && number.isFinite ? number : null;
}

/// Целое число, в том числе строкой (`"7"`, `7.0`); дробное и не число — `null`.
int? _whole(Object? value) {
  if (value is int) return value;
  final number = toDoubleOrNull(value);
  if (number == null || !number.isFinite || number != number.roundToDouble()) {
    return null;
  }
  return number.toInt();
}
