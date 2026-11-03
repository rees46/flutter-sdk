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

/// Значения карточки опроса — из базовых стилей веб-SDK один в один (макета нет):
/// карточка светлая и в тёмной теме. Дизайнер меняет их здесь разом; где в ките есть
/// токен с тем же значением, взят токен.
abstract final class _Poll {
  // Цвета.
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF0B1410);
  static const Color muted = Color(0xFF8A9A90);
  static const Color doneText = Color(0xFF5B6B62);
  static const Color optionBorder = Color(0xFFE1E8E4);
  static const Color optionBackground = Color(0xFFF4F7F5);
  static const Color fill = Color(0xFFD9F99D);
  static const Color selectedBorder = Color(0xFF22C55E);
  static const Color selectedFill = Color(0xFF86EFAC);
  static const Color dark = Color(0xFF0F3D2A);
  static const Color submit = Color(0xFF22C55E);
  static const Color submitText = Color(0xFF06210F);
  static const Color error = Color(0xFFDC2626);
  static const BoxShadow shadow = BoxShadow(
    color: Color(0x59000000),
    offset: Offset(0, 12),
    blurRadius: 30,
    spreadRadius: -10,
  );

  // Размеры.
  static const double maxWidth = 420;
  static const double edge = PersonalizationSpacing.xl;
  static const double radius = PersonalizationRadius.xl5;
  static const double padding = 14;
  static const double gap = 10;
  static const double border = 1.5;
  static const double controlRadius = PersonalizationRadius.xl2;
  static const double optionsGap = PersonalizationSpacing.md;
  static const EdgeInsets optionPadding = EdgeInsets.symmetric(
    vertical: 10,
    horizontal: PersonalizationSpacing.lg,
  );
  static const double chipsGap = 6;
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    vertical: 7,
    horizontal: 11,
  );
  static const double submitPadding = 11;
  static const double fieldHeight = 72;
  static const double fieldPadding = 10;
  static const double counterGap = gap - 6;
  static const double scaleGap = 3;
  static const double scaleRadius = PersonalizationRadius.md;
  static const double scalePadding = PersonalizationSpacing.md;
  static const double outline = 2;
  static const double dimmed = 0.55;
  static const double sendingOpacity = 0.85;
  static const double doneIcon = 38;
  static const double doneGap = 6;
  static const EdgeInsets linkPadding = EdgeInsets.symmetric(
    vertical: PersonalizationSpacing.xs,
    horizontal: PersonalizationSpacing.sm,
  );
  static const Duration fillDuration = Duration(milliseconds: 600);
  static const Curve fillCurve = Cubic(0.2, 0.8, 0.2, 1);

  // Шрифт.
  static const double fontBase = 13;
  static const double fontQuestion = 15;
  // 12 — кегль XS кита.
  static double get fontSmall => PersonalizationTypography.xsDefault.fontSize!;
  static const double fontScale = 11.5;
  static const double fontCounter = 10.5;
  static const double fontDone = 18;
  static const double lineHeight = 1.3;
  static const double questionLineHeight = 1.25;
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

  /// Ширина карточки на слайде шириной [width]: по 16 от краёв, не шире 420.
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

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final poll = _poll;
    final texts = poll.texts;
    final element = widget.poll;
    final rows = <(Widget, double)>[
      if (element.question.isNotEmpty)
        (
          Text(
            element.question,
            textAlign: TextAlign.center,
            style: _style(
              theme,
              _Poll.fontQuestion,
              FontWeight.w700,
              height: _Poll.questionLineHeight,
            ),
          ),
          _Poll.gap,
        ),
      ..._body(theme),
      if (poll.answered && element.allowReanswer)
        (
          Center(
            child: _Tap(
              onTap: poll.reanswer,
              child: Padding(
                padding: _Poll.linkPadding,
                child: Text(
                  texts.reanswer,
                  style:
                      _style(
                        theme,
                        _Poll.fontSmall,
                        FontWeight.w600,
                        color: _Poll.dark,
                      ).copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: _Poll.dark,
                      ),
                ),
              ),
            ),
          ),
          _Poll.gap,
        ),
      if (poll.failed)
        (
          Semantics(
            liveRegion: true,
            child: Text(
              texts.error,
              textAlign: TextAlign.center,
              style: _style(
                theme,
                _Poll.fontSmall,
                FontWeight.w400,
                color: _Poll.error,
              ),
            ),
          ),
          _Poll.gap,
        ),
    ];
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: _Poll.card,
        borderRadius: BorderRadius.circular(_Poll.radius),
        boxShadow: const <BoxShadow>[_Poll.shadow],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_Poll.radius),
        // Не влезает между шапкой и кнопками — прокрутка внутри, без перелистывания.
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
          child: Opacity(
            opacity: poll.sending ? _Poll.sendingOpacity : 1,
            // TextField требует предка Material; прозрачный ничего не рисует.
            child: Material(type: MaterialType.transparency, child: card),
          ),
        ),
      ),
    );
  }
}

/// Содержимое карточки по виду и состоянию: строки и зазор перед каждой.
extension on _PersonalizationStoryPollState {
  List<(Widget, double)> _body(PersonalizationTheme theme) {
    final poll = _poll;
    final element = widget.poll;
    if (element.pollType.isScale) {
      final band = poll.answered
          ? storyPollBandText(element, poll.answer?.rate)
          : null;
      return <(Widget, double)>[
        (_scale(theme), _Poll.gap),
        if (band != null && band.isNotEmpty) (_thanks(theme, band), _Poll.gap),
      ];
    }
    final thanks = element.thanksText;
    switch (element.kind) {
      case StoryMiniPollKind.singleChoice || StoryMiniPollKind.multipleChoice
          when poll.answered:
        return <(Widget, double)>[
          (_answeredOptions(theme), _Poll.gap),
          if (thanks.isNotEmpty) (_thanks(theme, thanks), _Poll.gap),
        ];
      case StoryMiniPollKind.singleChoice:
        return <(Widget, double)>[(_choiceOptions(theme), _Poll.gap)];
      case StoryMiniPollKind.multipleChoice:
        return <(Widget, double)>[
          (_chips(theme), _Poll.gap),
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
                  _Poll.fontCounter,
                  FontWeight.w400,
                  color: _Poll.muted,
                  tabular: true,
                ),
              ),
              _Poll.counterGap,
            ),
          (_submit(theme, poll.submitText), _Poll.gap),
        ];
      case null:
        return const <(Widget, double)>[];
    }
  }

  Widget _list(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (final (index, child) in children.indexed) ...<Widget>[
        if (index > 0) const SizedBox(height: _Poll.optionsGap),
        child,
      ],
    ],
  );

  /// Выбор одного: нажатие отправляет, нажатый вариант сразу подсвечен.
  Widget _choiceOptions(PersonalizationTheme theme) => _list(<Widget>[
    for (final option in widget.poll.options)
      _OptionRow(
        theme: theme,
        label: option.label,
        selected: _poll.selected.contains(option.id),
        onTap: _poll.sending ? null : () => _poll.choose(option.id),
      ),
  ]);

  /// Отвеченный выбор: ответ подсвечен, с итогами — полоски и проценты.
  Widget _answeredOptions(PersonalizationTheme theme) {
    final selected = <int>{...?_poll.answer?.optionIds};
    final results = _poll.results;
    return _list(<Widget>[
      for (final option in widget.poll.options)
        _OptionRow(
          theme: theme,
          label: option.label,
          selected: selected.contains(option.id),
          percent: results?.percentOf(option.id),
        ),
    ]);
  }

  Widget _chips(PersonalizationTheme theme) => Wrap(
    alignment: WrapAlignment.center,
    spacing: _Poll.chipsGap,
    runSpacing: _Poll.chipsGap,
    children: <Widget>[
      for (final option in widget.poll.options)
        _Chip(
          theme: theme,
          label: option.label,
          pressed: _poll.selected.contains(option.id),
          onTap: _poll.sending ? null : () => _poll.toggle(option.id),
        ),
    ],
  );

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
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: enabled ? _Poll.submit : _Poll.optionBorder,
            borderRadius: BorderRadius.circular(_Poll.controlRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_Poll.submitPadding),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: _style(
                theme,
                _Poll.fontBase,
                FontWeight.w700,
                color: enabled ? _Poll.submitText : _Poll.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thanks(PersonalizationTheme theme, String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: _style(theme, _Poll.fontBase, FontWeight.w600),
  );
}

/// Поле, отвеченный текст и шкала.
extension on _PersonalizationStoryPollState {
  /// Многострочное поле: предел `max_length` обрезает ввод; пока идёт отправка, текст
  /// не меняется, а клавиатура остаётся.
  Widget _field(PersonalizationTheme theme) {
    final style = _style(theme, _Poll.fontBase, FontWeight.w500);
    final placeholder = widget.poll.placeholder;
    return Container(
      height: _Poll.fieldHeight,
      padding: const EdgeInsets.all(_Poll.fieldPadding),
      decoration: BoxDecoration(
        color: _Poll.optionBackground,
        border: Border.all(color: _Poll.optionBorder, width: _Poll.border),
        borderRadius: BorderRadius.circular(_Poll.controlRadius),
      ),
      child: TextSelectionTheme(
        data: const TextSelectionThemeData(
          cursorColor: _Poll.text,
          selectionColor: _Poll.selectedFill,
          selectionHandleColor: _Poll.selectedBorder,
        ),
        child: TextField(
          controller: _input,
          focusNode: _focus,
          expands: true,
          maxLines: null,
          textAlignVertical: TextAlignVertical.top,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          keyboardAppearance: Brightness.light,
          cursorColor: _Poll.text,
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
            hintStyle: style.copyWith(color: _Poll.muted),
          ),
        ),
      ),
    );
  }

  /// Отвеченный текст: ✓, благодарность и сам ответ.
  Widget _done(PersonalizationTheme theme) {
    final thanks = widget.poll.thanksText;
    final text = _poll.answer?.text ?? '';
    final rows = <Widget>[
      Container(
        width: _Poll.doneIcon,
        height: _Poll.doneIcon,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: _Poll.fill,
          shape: BoxShape.circle,
        ),
        child: Text(
          '✓',
          style: _style(
            theme,
            _Poll.fontDone,
            FontWeight.w800,
            color: _Poll.dark,
            height: 1,
          ),
        ),
      ),
      if (thanks.isNotEmpty) _thanks(theme, thanks),
      if (text.isNotEmpty)
        Text(
          text,
          textAlign: TextAlign.center,
          style: _style(
            theme,
            _Poll.fontScale,
            FontWeight.w400,
            color: _Poll.doneText,
          ),
        ),
    ];
    return Column(
      children: <Widget>[
        for (final (index, row) in rows.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: _Poll.doneGap),
          row,
        ],
      ],
    );
  }

  /// Шкала: ячейки поровну в ряд, цвет по оценке. В форме нажатие отправляет, у
  /// отвеченной ответ в обводке, остальные приглушены.
  Widget _scale(PersonalizationTheme theme) {
    final element = widget.poll;
    final values = storyPollScaleRange(element);
    if (values.isEmpty) return const SizedBox.shrink();
    final answered = _poll.answered;
    final highlighted = _poll.rateValue;
    return Row(
      children: <Widget>[
        for (final (index, value) in values.indexed) ...<Widget>[
          if (index > 0) const SizedBox(width: _Poll.scaleGap),
          Expanded(
            child: _ScaleCell(
              theme: theme,
              value: value,
              color: storyPollScaleColor(
                element.pollType,
                value,
                values.first,
                values.last,
              ),
              selected: value == highlighted,
              dimmed: answered && value != highlighted,
              onTap: answered || _poll.sending ? null : () => _poll.rate(value),
            ),
          ),
        ],
      ],
    );
  }
}

/// Стиль текста карточки: шрифт кита, свой цвет — карточка светлая в любой теме.
TextStyle _style(
  PersonalizationTheme theme,
  double size,
  FontWeight weight, {
  Color color = _Poll.text,
  double height = _Poll.lineHeight,
  bool tabular = false,
}) => TextStyle(
  fontSize: size,
  height: height,
  fontWeight: weight,
  letterSpacing: 0,
  color: color,
  decoration: TextDecoration.none,
  fontFamily: theme.fontFamily.familyFor(weight),
  package: theme.fontFamily.package,
  fontFeatures: tabular
      ? const <FontFeature>[FontFeature.tabularFigures()]
      : null,
);

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

/// Вариант ответа: в форме выбора одного — кнопка, у отвеченного — строка с итогом
/// [percent] (полоска растёт от нуля от начала строки).
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.theme,
    required this.label,
    required this.selected,
    this.percent,
    this.onTap,
  });

  final PersonalizationTheme theme;
  final String label;
  final bool selected;
  final int? percent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = _style(theme, _Poll.fontBase, FontWeight.w600);
    final percent = this.percent;
    final row = Container(
      decoration: BoxDecoration(
        color: _Poll.optionBackground,
        border: Border.all(
          color: selected ? _Poll.selectedBorder : _Poll.optionBorder,
          width: _Poll.border,
        ),
        borderRadius: BorderRadius.circular(_Poll.controlRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_Poll.controlRadius - _Poll.border),
        child: Stack(
          children: <Widget>[
            if (percent != null)
              Positioned.fill(
                child: _Fill(
                  value: percent / 100,
                  color: selected ? _Poll.selectedFill : _Poll.fill,
                ),
              ),
            Padding(
              padding: _Poll.optionPadding,
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(label, style: style)),
                  if (percent != null) ...<Widget>[
                    const SizedBox(width: PersonalizationSpacing.md),
                    Text(
                      '$percent%',
                      style: _style(
                        theme,
                        _Poll.fontBase,
                        FontWeight.w600,
                        tabular: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: onTap == null ? row : _Tap(onTap: onTap, child: row),
    );
  }
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

/// Чип выбора нескольких: переключатель.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.theme,
    required this.label,
    required this.pressed,
    required this.onTap,
  });

  final PersonalizationTheme theme;
  final String label;
  final bool pressed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: pressed,
    child: _Tap(
      onTap: onTap,
      child: Container(
        padding: _Poll.chipPadding,
        decoration: BoxDecoration(
          color: pressed ? _Poll.dark : _Poll.optionBackground,
          border: Border.all(
            color: pressed ? _Poll.dark : _Poll.optionBorder,
            width: _Poll.border,
          ),
          borderRadius: BorderRadius.circular(PersonalizationRadius.rounded),
        ),
        child: Text(
          label,
          style: _style(
            theme,
            _Poll.fontSmall,
            FontWeight.w600,
            color: pressed ? _Poll.fill : _Poll.text,
          ),
        ),
      ),
    ),
  );
}

/// Ячейка шкалы: выбранная — в обводке с зазором, приглушённая — у отвеченной шкалы.
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
      child: Opacity(
        opacity: dimmed ? _Poll.dimmed : 1,
        child: CustomPaint(
          foregroundPainter: selected ? const _Outline() : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(_Poll.scaleRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: _Poll.scalePadding),
              child: Text(
                '$value',
                maxLines: 1,
                textAlign: TextAlign.center,
                style: _style(
                  theme,
                  _Poll.fontScale,
                  FontWeight.w700,
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

/// Обводка выбранной ячейки: 2 снаружи, через 1 от края.
class _Outline extends CustomPainter {
  const _Outline();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 1 + _Poll.outline / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(inset),
        const Radius.circular(_Poll.scaleRadius + inset),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _Poll.outline
        ..color = _Poll.text,
    );
  }

  @override
  bool shouldRepaint(_Outline oldDelegate) => false;
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
