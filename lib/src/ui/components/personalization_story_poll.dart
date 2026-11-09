import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart'
    show
        InputDecoration,
        Material,
        MaterialType,
        TextField,
        TextSelectionTheme,
        TextSelectionThemeData;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../stories/stories_response.dart';
import '../personalization_radius.dart';
import '../personalization_spacing.dart';
import '../personalization_theme.dart';
import '../personalization_typography.dart';
import '../widgets/stories_poll.dart';
import '../widgets/stories_polls_api.dart';

/// Значения карточки опроса: матовая светлая карточка, текст по левому краю, варианты
/// с буквами, шкала — дорожкой. Карточка светлая и в тёмной теме: текст — тёмные токены
/// кита (`textDark*`), акцент — цвет выбора опроса. Дизайнер меняет их здесь разом; где
/// в ките есть токен с тем же значением, взят токен.
abstract final class _Poll {
  // Цвета.
  /// Акцент: выбор, основная кнопка, точка шапки итогов.
  static const Color accent = Color(0xFF22C55E);

  /// Заливка выбранного варианта до отправки — акцент 20 %.
  static const Color accentFill = Color(0x3322C55E);

  /// Полоска итога моего ответа — акцент 25 %.
  static const Color accentBar = Color(0x4022C55E);

  /// Подложка карточки поверх размытия — белый 80 %.
  static const Color card = Color(0xCCFFFFFF);

  /// Граница карточки — белый 50 %.
  static const Color cardBorder = Color(0x80FFFFFF);

  /// Подложка вариантов, дорожки шкалы и неактивной кнопки — чёрный 6 %.
  static const Color well = Color(0x0F000000);

  /// Полоска итога варианта — чёрный 8 %.
  static const Color bar = Color(0x14000000);

  /// Квадрат буквы и поле ввода — белый 85 %.
  static const Color light = Color(0xD9FFFFFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFDC2626);

  // Размеры.
  static const double maxWidth = 420;
  static const double edge = PersonalizationSpacing.lg;
  static const double radius = PersonalizationRadius.xl6;
  static const double padding = PersonalizationSpacing.xl2;
  static const double blur = 20;
  static const double cardBorderWidth = 1;
  static const double dot = 6;
  static const double dotGap = PersonalizationSpacing.md;

  /// От шапки итогов до вопроса.
  static const double headerGap = PersonalizationSpacing.lg;

  /// От вопроса до содержимого, от содержимого до подвала, кнопки и текста полосы.
  static const double gap = PersonalizationSpacing.xl;

  /// Ссылка «Ответить заново» и ошибка под содержимым.
  static const double noteGap = PersonalizationSpacing.lg;
  static const double rowHeight = 56;
  static const double rowRadius = PersonalizationRadius.xl5;
  static const double rowPadding = PersonalizationSpacing.lg;
  static const double rowsGap = PersonalizationSpacing.md;
  static const double letter = 32;
  static const double letterRadius = PersonalizationRadius.lg;
  static const double letterGap = PersonalizationSpacing.lg;
  static const double selectedBorder = 1.5;
  static const double track = 52;
  static const double trackPadding = PersonalizationSpacing.sm;
  static const double field = 52;
  static const double fieldRadius = PersonalizationRadius.xl4;
  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(
    horizontal: PersonalizationSpacing.xl,
    vertical: 14,
  );

  /// Поле растёт до стольких строк, дальше прокрутка внутри.
  static const int fieldLines = 4;

  /// От поля (или счётчика) до кнопки.
  static const double fieldGap = PersonalizationSpacing.lg;
  static const double counterGap = PersonalizationSpacing.sm;
  static const double button = 52;
  static const double buttonRadius = PersonalizationRadius.xl4;
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: PersonalizationSpacing.xl,
    vertical: 14,
  );
  static const double checkStroke = 2.5;
  static const double dimmed = 0.55;
  static const double sendingOpacity = 0.85;
  static const double linkPadding = PersonalizationSpacing.sm;
  static const Duration fillDuration = Duration(milliseconds: 600);
  static const Curve fillCurve = Cubic(0.2, 0.8, 0.2, 1);

  // Шрифт — кегли кита.
  static const TextStyle header = PersonalizationTypography.xsEmphasized;

  /// Разрядка шапки итогов — 0,08 em.
  static const double headerTracking = 0.08;
  static const TextStyle question = PersonalizationTypography.lgEmphasized;

  /// Межстрочный вопроса.
  static const double questionLine = 24;
  static const TextStyle body = PersonalizationTypography.baseDefault;
  static const TextStyle bodyStrong = PersonalizationTypography.baseEmphasized;
  static const TextStyle small = PersonalizationTypography.smDefault;
  static const TextStyle smallStrong = PersonalizationTypography.smEmphasized;
  static const TextStyle note = PersonalizationTypography.xsDefault;
}

/// Карточка опроса на слайде сторис V2: мини-опрос (выбор одного, выбор нескольких,
/// текст) или шкала NPS / CSAT / CES. Логика — [StoryPollController].
///
/// - Касание, начатое на карточке, слайду не достаётся: она забирает свайпы, а касание
///   по третям и удержание слайда пропускают её касания ([StoryPollPointers]).
/// - Пока карточку держат пальцем, в фокусе поле или идёт отправка — [onHold]`(true)`;
///   только у живого слайда ([live]). Не живая — не нажимается.
/// - Поле ввода — [TextField] в прозрачном `Material`; нужны `MaterialLocalizations`
///   хоста (как у `PersonalizationInputField`). Свернули приложение — клавиатура уходит;
///   система убрала клавиатуру («назад» на Android) — поле отпускает фокус.
/// - Карточка матовая: размывает слайд под собой.
/// - Тексты итогов выбора — по языку устройства ([StoryPollResultTexts]).
/// - RTL: поля, полоски итогов и шкала зеркалятся.
class PersonalizationStoryPoll extends StatefulWidget {
  const PersonalizationStoryPoll({
    super.key,
    required this.poll,
    required this.storyId,
    required this.slideId,
    required this.transport,
    this.shopId = '',
    this.texts = const StoryPollTexts(),
    this.live = true,
    this.onHold,
  });

  final StoryPollElement poll;
  final String storyId;
  final String slideId;
  final StoryPollsTransport transport;

  /// Магазин — ключ хранилища ответов сессии.
  final String shopId;

  /// Тексты хоста; `labels` опроса важнее.
  final StoryPollTexts texts;
  final bool live;
  final ValueChanged<bool>? onHold;

  /// Ширина карточки на слайде шириной [width]: по 12 от краёв, не шире 420.
  static double widthFor(double width) =>
      (width - 2 * _Poll.edge).clamp(0, _Poll.maxWidth).toDouble();

  @override
  State<PersonalizationStoryPoll> createState() =>
      _PersonalizationStoryPollState();
}

class _PersonalizationStoryPollState extends State<PersonalizationStoryPoll>
    with WidgetsBindingObserver {
  late final StoryPollController _poll = StoryPollController(
    poll: widget.poll,
    storyId: widget.storyId,
    slideId: widget.slideId,
    transport: widget.transport,
    shopId: widget.shopId,
    texts: widget.texts,
    active: widget.live,
    onHold: (held) => widget.onHold?.call(held),
  );
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'story poll');

  /// Пальцы на карточке.
  final Set<int> _pointers = <int>{};
  bool _wasAnswered = false;

  /// Высота клавиатуры в прошлый раз.
  double _keyboard = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasAnswered = _poll.answered;
    _poll.addListener(_onPoll);
    _focus.addListener(_onFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Система убрала клавиатуру («назад» на Android) — поле отпускает фокус, слайд идёт
    // дальше, а не стоит с курсором без клавиатуры. С аппаратной клавиатурой отступ всё
    // время 0 — фокус остаётся.
    final keyboard = MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0;
    if (_keyboard > 0 && keyboard == 0 && _focus.hasFocus) _focus.unfocus();
    _keyboard = keyboard;
  }

  @override
  void didUpdateWidget(PersonalizationStoryPoll oldWidget) {
    super.didUpdateWidget(oldWidget);
    _poll.active = widget.live;
    if (!widget.live) _focus.unfocus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Свернули приложение — клавиатуру убрать.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _focus.unfocus();
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // Тексты итогов — по языку устройства.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pointers.forEach(StoryPollPointers.release);
    _poll
      ..removeListener(_onPoll)
      ..dispose();
    _focus.dispose();
    _input.dispose();
    super.dispose();
  }

  void _onPoll() {
    if (!_poll.showsField && _focus.hasFocus) _focus.unfocus();
    // «Ответить заново» у текста: пустое поле в фокусе, как в вебе.
    if (_wasAnswered && !_poll.answered && _poll.showsField) {
      _input.clear();
      _focus.requestFocus();
    }
    _wasAnswered = _poll.answered;
    setState(() {});
  }

  void _onFocus() => _poll.focused = _focus.hasFocus;

  void _down(PointerDownEvent event) {
    StoryPollPointers.claim(event.pointer);
    _pointers.add(event.pointer);
    _poll.pressed = true;
  }

  void _up(PointerEvent event) {
    StoryPollPointers.release(event.pointer);
    _pointers.remove(event.pointer);
    _poll.pressed = _pointers.isNotEmpty;
  }

  /// Тексты итогов у отвеченного выбора; у остального — `null`.
  StoryPollResultTexts? get _summary {
    final choice = switch (widget.poll.kind) {
      StoryMiniPollKind.singleChoice ||
      StoryMiniPollKind.multipleChoice => true,
      _ => false,
    };
    if (!choice || !_poll.answered) return null;
    return StoryPollResultTexts.of(
      WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final poll = _poll;
    final texts = poll.texts;
    final element = widget.poll;
    final summary = _summary;
    final rows = <(Widget, double)>[
      if (summary != null) (_header(theme, summary.results), 0),
      if (element.question.isNotEmpty)
        (
          Text(
            element.question,
            style: _style(
              theme,
              _Poll.question,
              height: _Poll.questionLine / _Poll.question.fontSize!,
            ),
          ),
          _Poll.headerGap,
        ),
      ..._body(theme, summary),
      if (poll.answered && element.allowReanswer)
        (
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _Tap(
              onTap: poll.reanswer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _Poll.linkPadding,
                ),
                child: Text(
                  texts.reanswer,
                  style: _style(theme, _Poll.smallStrong).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: theme.colors.textDarkPrimary,
                  ),
                ),
              ),
            ),
          ),
          _Poll.noteGap,
        ),
      if (poll.failed)
        (
          Semantics(
            liveRegion: true,
            child: Text(
              texts.error,
              style: _style(theme, _Poll.note, color: _Poll.error),
            ),
          ),
          _Poll.noteGap,
        ),
    ];
    final radius = BorderRadius.circular(_Poll.radius);
    // Матовая: размытие слайда под карточкой и светлая подложка. Прозрачность отправки —
    // у подложки с содержимым: размытию нужен слайд, а не пустой слой.
    final card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _Poll.blur, sigmaY: _Poll.blur),
        child: Opacity(
          opacity: poll.sending ? _Poll.sendingOpacity : 1,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(
                color: _Poll.cardBorder,
                width: _Poll.cardBorderWidth,
              ),
              borderRadius: radius,
            ),
            child: ColoredBox(
              color: _Poll.card,
              // Не влезает между шапкой и кнопками — прокрутка внутри, без
              // перелистывания.
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(_Poll.padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final (index, (row, gap)) in rows.indexed) ...<Widget>[
                      if (index > 0) SizedBox(height: gap),
                      row,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      // Свайпы, начатые на карточке, — её: просмотр не листается и не закрывается.
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          VerticalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                VerticalDragGestureRecognizer
              >(
                VerticalDragGestureRecognizer.new,
                (recognizer) => recognizer.onStart = (_) {},
              ),
          HorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer
              >(
                HorizontalDragGestureRecognizer.new,
                (recognizer) => recognizer.onStart = (_) {},
              ),
        },
        child: Semantics(
          container: true,
          // TextField требует предка Material; прозрачный ничего не рисует.
          child: Material(type: MaterialType.transparency, child: card),
        ),
      ),
    );
  }
}

/// Содержимое карточки по виду и состоянию: строки и зазор перед каждой.
extension on _PersonalizationStoryPollState {
  List<(Widget, double)> _body(
    PersonalizationTheme theme,
    StoryPollResultTexts? summary,
  ) {
    final poll = _poll;
    final element = widget.poll;
    if (element.pollType.isScale) {
      final band = poll.answered
          ? storyPollBandText(element, poll.answer?.rate)
          : null;
      return <(Widget, double)>[
        (_scale(theme), _Poll.gap),
        if (band != null && band.isNotEmpty)
          (Text(band, style: _style(theme, _Poll.small)), _Poll.gap),
      ];
    }
    switch (element.kind) {
      case StoryMiniPollKind.singleChoice || StoryMiniPollKind.multipleChoice
          when summary != null:
        return <(Widget, double)>[
          (_answeredOptions(theme), _Poll.gap),
          (_footer(theme, summary), _Poll.gap),
        ];
      case StoryMiniPollKind.singleChoice:
        return <(Widget, double)>[(_choiceOptions(theme), _Poll.gap)];
      case StoryMiniPollKind.multipleChoice:
        return <(Widget, double)>[
          (_choiceOptions(theme, multiple: true), _Poll.gap),
          (_submit(theme, poll.submitChoices), _Poll.gap),
        ];
      case StoryMiniPollKind.text when poll.answered:
        return <(Widget, double)>[(_done(theme), _Poll.gap)];
      case StoryMiniPollKind.text:
        final limit = element.maxLength;
        return <(Widget, double)>[
          (_field(theme), _Poll.gap),
          if (limit != null)
            (
              Text(
                '${poll.text.length}/$limit',
                textAlign: TextAlign.end,
                style: _style(
                  theme,
                  _Poll.note,
                  color: theme.colors.textDarkSecondary,
                  tabular: true,
                ),
              ),
              _Poll.counterGap,
            ),
          (_submit(theme, poll.submitText), _Poll.fieldGap),
        ];
      case null:
        return const <(Widget, double)>[];
    }
  }

  Widget _list(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (final (index, child) in children.indexed) ...<Widget>[
        if (index > 0) const SizedBox(height: _Poll.rowsGap),
        child,
      ],
    ],
  );

  /// Форма выбора: у одного нажатие отправляет, нажатый вариант сразу подсвечен; у
  /// нескольких — переключает вариант.
  Widget _choiceOptions(PersonalizationTheme theme, {bool multiple = false}) =>
      _list(<Widget>[
        for (final (index, option) in widget.poll.options.indexed)
          _OptionRow(
            theme: theme,
            letter: _letter(index),
            label: option.label,
            selected: _poll.selected.contains(option.id),
            onTap: _poll.sending
                ? null
                : multiple
                ? () => _poll.toggle(option.id)
                : () => _poll.choose(option.id),
          ),
      ]);

  /// Отвеченный выбор: ответ подсвечен, с итогами — полоски и проценты.
  Widget _answeredOptions(PersonalizationTheme theme) {
    final selected = <int>{...?_poll.answer?.optionIds};
    final results = _poll.results;
    return _list(<Widget>[
      for (final (index, option) in widget.poll.options.indexed)
        _OptionRow(
          theme: theme,
          letter: _letter(index),
          label: option.label,
          selected: selected.contains(option.id),
          answered: true,
          percent: results?.percentOf(option.id),
        ),
    ]);
  }

  /// Шапка итогов: точка акцента и «РЕЗУЛЬТАТЫ».
  Widget _header(PersonalizationTheme theme, String text) => Row(
    children: <Widget>[
      const SizedBox.square(
        dimension: _Poll.dot,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _Poll.accent,
            shape: BoxShape.circle,
          ),
        ),
      ),
      const SizedBox(width: _Poll.dotGap),
      Flexible(
        child: Text(
          text.toUpperCase(),
          semanticsLabel: text,
          style: _style(
            theme,
            _Poll.header,
            color: theme.colors.textDarkSecondary,
            tracking: _Poll.headerTracking * _Poll.header.fontSize!,
          ),
        ),
      ),
    ],
  );

  /// Подвал итогов: благодарность опроса или «Спасибо! Голос учтён»; справа — число
  /// голосов, если оно есть.
  Widget _footer(PersonalizationTheme theme, StoryPollResultTexts texts) {
    final thanks = widget.poll.thanksText;
    final total = _poll.results?.total ?? 0;
    final strong = _style(theme, _Poll.smallStrong);
    final muted = _style(
      theme,
      _Poll.small,
      color: theme.colors.textDarkSecondary,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: thanks.isNotEmpty
              ? Text(thanks, style: strong)
              : Text.rich(
                  TextSpan(
                    children: <TextSpan>[
                      TextSpan(text: texts.thanks, style: strong),
                      TextSpan(text: ' ${texts.counted}', style: muted),
                    ],
                  ),
                ),
        ),
        if (total > 0) ...<Widget>[
          const SizedBox(width: _Poll.letterGap),
          Text(texts.votes(total), style: muted),
        ],
      ],
    );
  }

  Widget _submit(PersonalizationTheme theme, VoidCallback send) {
    final label = widget.poll.submitLabel.isNotEmpty
        ? widget.poll.submitLabel
        : _poll.texts.submit;
    final enabled = _poll.canSubmit;
    return Semantics(
      button: true,
      enabled: enabled,
      child: _Tap(
        onTap: enabled ? send : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: _Poll.button),
          alignment: Alignment.center,
          padding: _Poll.buttonPadding,
          decoration: BoxDecoration(
            color: enabled ? _Poll.accent : _Poll.well,
            borderRadius: BorderRadius.circular(_Poll.buttonRadius),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: _style(
              theme,
              _Poll.bodyStrong,
              color: enabled
                  ? _onFill(_Poll.accent, theme.colors.textDarkPrimary)
                  : theme.colors.textDarkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Поле, отвеченный текст и шкала.
extension on _PersonalizationStoryPollState {
  /// Поле ввода: растёт до [_Poll.fieldLines] строк; предел `max_length` обрезает
  /// ввод; пока идёт отправка, текст не меняется, а клавиатура остаётся.
  Widget _field(PersonalizationTheme theme) {
    final style = _style(theme, _Poll.body);
    final placeholder = widget.poll.placeholder;
    return Container(
      constraints: const BoxConstraints(minHeight: _Poll.field),
      padding: _Poll.fieldPadding,
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: _Poll.light,
        borderRadius: BorderRadius.circular(_Poll.fieldRadius),
      ),
      child: TextSelectionTheme(
        data: TextSelectionThemeData(
          cursorColor: theme.colors.textDarkPrimary,
          selectionColor: _Poll.accentBar,
          selectionHandleColor: _Poll.accent,
        ),
        child: TextField(
          controller: _input,
          focusNode: _focus,
          minLines: 1,
          maxLines: _Poll.fieldLines,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          keyboardAppearance: Brightness.light,
          cursorColor: theme.colors.textDarkPrimary,
          style: style,
          inputFormatters: <TextInputFormatter>[
            _PollInputFormatter(
              limit: widget.poll.maxLength,
              frozen: () => _poll.sending,
            ),
          ],
          onChanged: (value) => _poll.text = value,
          decoration: InputDecoration.collapsed(
            hintText: placeholder.isEmpty ? null : placeholder,
            hintStyle: style.copyWith(color: theme.colors.textDarkHint),
          ),
        ),
      ),
    );
  }

  /// Отвеченный текст: кружок с галочкой и благодарность, под ними сам ответ.
  Widget _done(PersonalizationTheme theme) {
    final thanks = widget.poll.thanksText;
    final text = _poll.answer?.text ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _Mark(theme: theme, circle: true),
            if (thanks.isNotEmpty) ...<Widget>[
              const SizedBox(width: _Poll.letterGap),
              Expanded(
                child: Text(thanks, style: _style(theme, _Poll.bodyStrong)),
              ),
            ],
          ],
        ),
        if (text.isNotEmpty) ...<Widget>[
          const SizedBox(height: _Poll.letterGap),
          Text(
            text,
            style: _style(
              theme,
              _Poll.body,
              color: theme.colors.textDarkSecondary,
            ),
          ),
        ],
      ],
    );
  }

  /// Шкала — дорожка, цифры поровну. В форме нажатие отправляет; выбранная — капсула
  /// цвета её полосы, у отвеченной остальные приглушены.
  Widget _scale(PersonalizationTheme theme) {
    final element = widget.poll;
    final values = storyPollScaleRange(element);
    if (values.isEmpty) return const SizedBox.shrink();
    final answered = _poll.answered;
    final highlighted = _poll.rateValue;
    return Container(
      constraints: const BoxConstraints(minHeight: _Poll.track),
      padding: const EdgeInsets.symmetric(horizontal: _Poll.trackPadding),
      decoration: const BoxDecoration(
        color: _Poll.well,
        borderRadius: BorderRadius.all(
          Radius.circular(PersonalizationRadius.rounded),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final value in values)
              Expanded(
                child: _ScaleCell(
                  theme: theme,
                  value: value,
                  // Без полос — акцент.
                  color: element.bands.isEmpty
                      ? _Poll.accent
                      : storyPollScaleColor(
                          element.pollType,
                          value,
                          values.first,
                          values.last,
                        ),
                  selected: value == highlighted,
                  dimmed: answered && value != highlighted,
                  onTap: answered || _poll.sending
                      ? null
                      : () => _poll.rate(value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Буква варианта по номеру: A…Z, дальше AA, AB…
String _letter(int index) {
  var letters = '';
  for (var rest = index + 1; rest > 0; rest = (rest - 1) ~/ 26) {
    letters = String.fromCharCode(65 + (rest - 1) % 26) + letters;
  }
  return letters;
}

/// Стиль текста карточки: кегль [token] кита, шрифт темы, свой цвет — по умолчанию
/// тёмный основной: карточка светлая в любой теме.
TextStyle _style(
  PersonalizationTheme theme,
  TextStyle token, {
  Color? color,
  double? height,
  double? tracking,
  bool tabular = false,
}) {
  final weight = token.fontWeight ?? FontWeight.w400;
  return TextStyle(
    fontSize: token.fontSize,
    height: height ?? token.height,
    fontWeight: weight,
    letterSpacing: tracking ?? token.letterSpacing ?? 0,
    color: color ?? theme.colors.textDarkPrimary,
    decoration: TextDecoration.none,
    fontFamily: theme.fontFamily.familyFor(weight),
    package: theme.fontFamily.package,
    fontFeatures: tabular
        ? const <FontFeature>[FontFeature.tabularFigures()]
        : null,
  );
}

/// Цвет текста и значков на заливке [fill] — текста основной кнопки, галочки, цифры
/// шкалы: белый или [dark] — что контрастнее.
Color _onFill(Color fill, Color dark) {
  final luminance = fill.computeLuminance() + 0.05;
  final white = 1.05 / luminance;
  final black = luminance / (dark.computeLuminance() + 0.05);
  return white > black ? _Poll.white : dark;
}

/// Нажимаемая область; `onTap == null` — не нажимается.
class _Tap extends StatelessWidget {
  const _Tap({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: child,
  );
}

/// Вариант выбора: квадрат с буквой, подпись до двух строк; выбранный — в рамке
/// акцента, с галочкой вместо буквы, до отправки ещё и залит акцентом. У отвеченного
/// ([answered]) с итогами — процент справа и полоска доли от начала строки (растёт от
/// нуля), у моего ответа — акцента.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.theme,
    required this.letter,
    required this.label,
    required this.selected,
    this.answered = false,
    this.percent,
    this.onTap,
  });

  final PersonalizationTheme theme;
  final String letter;
  final String label;
  final bool selected;

  /// Строка итогов: мой ответ без заливки, только рамка и полоска.
  final bool answered;
  final int? percent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final percent = this.percent;
    final radius = BorderRadius.circular(_Poll.rowRadius);
    final content = Padding(
      padding: const EdgeInsets.all(_Poll.rowPadding),
      child: Row(
        children: <Widget>[
          selected
              ? _Mark(theme: theme)
              : _LetterBox(theme: theme, letter: letter),
          const SizedBox(width: _Poll.letterGap),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _style(theme, _Poll.body),
            ),
          ),
          if (percent != null) ...<Widget>[
            const SizedBox(width: _Poll.letterGap),
            Text(
              '$percent%',
              style: _style(theme, _Poll.bodyStrong, tabular: true),
            ),
          ],
        ],
      ),
    );
    final row = Container(
      constraints: const BoxConstraints(minHeight: _Poll.rowHeight),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: selected && !answered ? _Poll.accentFill : _Poll.well,
        borderRadius: radius,
      ),
      foregroundDecoration: selected
          ? BoxDecoration(
              border: Border.all(
                color: _Poll.accent,
                width: _Poll.selectedBorder,
              ),
              borderRadius: radius,
            )
          : null,
      child: percent == null
          ? content
          : Stack(
              children: <Widget>[
                Positioned.fill(
                  child: _Fill(
                    value: percent / 100,
                    color: selected ? _Poll.accentBar : _Poll.bar,
                  ),
                ),
                content,
              ],
            ),
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: onTap == null ? row : _Tap(onTap: onTap, child: row),
    );
  }
}

/// Квадрат буквы варианта.
class _LetterBox extends StatelessWidget {
  const _LetterBox({required this.theme, required this.letter});

  final PersonalizationTheme theme;
  final String letter;

  @override
  Widget build(BuildContext context) => Container(
    width: _Poll.letter,
    height: _Poll.letter,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _Poll.light,
      borderRadius: BorderRadius.circular(_Poll.letterRadius),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        letter,
        maxLines: 1,
        style: _style(
          theme,
          _Poll.smallStrong,
          color: theme.colors.textDarkSecondary,
        ),
      ),
    ),
  );
}

/// Галочка на акценте — белая или тёмная по контрасту: квадрат выбранного варианта
/// или кружок отвеченного текста ([circle]).
class _Mark extends StatelessWidget {
  const _Mark({required this.theme, this.circle = false});

  final PersonalizationTheme theme;
  final bool circle;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: _Poll.letter,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _Poll.accent,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(_Poll.letterRadius),
      ),
      child: CustomPaint(
        painter: _Check(_onFill(_Poll.accent, theme.colors.textDarkPrimary)),
      ),
    ),
  );
}

/// Галочка цвета [color] по центру квадрата.
class _Check extends CustomPainter {
  const _Check(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.31, size.height * 0.5)
        ..lineTo(size.width * 0.44, size.height * 0.63)
        ..lineTo(size.width * 0.69, size.height * 0.38),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _Poll.checkStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_Check oldDelegate) => oldDelegate.color != color;
}

/// Полоска итога варианта: от нуля до [value] (0…1) за 0,6 с; без анимаций в системе —
/// сразу.
class _Fill extends StatelessWidget {
  const _Fill({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0, 1).toDouble()),
      duration: still ? Duration.zero : _Poll.fillDuration,
      curve: _Poll.fillCurve,
      builder: (context, width, _) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: width,
          heightFactor: 1,
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}

/// Цифра шкалы: выбранная — капсула цвета [color] на всю высоту дорожки, приглушённая
/// — у отвеченной шкалы.
class _ScaleCell extends StatelessWidget {
  const _ScaleCell({
    required this.theme,
    required this.value,
    required this.color,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final PersonalizationTheme theme;
  final int value;
  final Color color;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    selected: selected,
    child: _Tap(
      onTap: onTap,
      child: DecoratedBox(
        decoration: selected
            ? BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(
                  PersonalizationRadius.rounded,
                ),
              )
            : const BoxDecoration(),
        child: Center(
          child: Opacity(
            opacity: dimmed ? _Poll.dimmed : 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value',
                maxLines: 1,
                style: _style(
                  theme,
                  _Poll.bodyStrong,
                  color: selected
                      ? _onFill(color, theme.colors.textDarkPrimary)
                      : theme.colors.textDarkPrimary,
                  tabular: true,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Предел длины поля в кодовых единицах UTF-16, как `maxLength` веба; суррогатную пару
/// не режет, набор через IME обрезает, когда он закончен. [frozen] — текст не меняется.
class _PollInputFormatter extends TextInputFormatter {
  _PollInputFormatter({required this.limit, required this.frozen});

  final int? limit;
  final bool Function() frozen;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (frozen() && newValue.text != oldValue.text) return oldValue;
    final limit = this.limit;
    final text = newValue.text;
    if (limit == null || text.length <= limit || newValue.composing.isValid) {
      return newValue;
    }
    var end = limit;
    if (end > 0) {
      final last = text.codeUnitAt(end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) end--;
    }
    int clamp(int offset) => offset.clamp(0, end);
    return TextEditingValue(
      text: text.substring(0, end),
      selection: newValue.selection.copyWith(
        baseOffset: clamp(newValue.selection.baseOffset),
        extentOffset: clamp(newValue.selection.extentOffset),
      ),
    );
  }
}
