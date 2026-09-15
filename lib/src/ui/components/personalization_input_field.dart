import 'package:flutter/material.dart'
    show InputDecoration, Material, MaterialType, TextField;
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import '../personalization_colors.dart';
import '../personalization_theme.dart';
import '../personalization_icons.dart';

/// Размер поля ввода.
enum PersonalizationInputFieldSize { lg, md, sm }

/// Тип поля ввода.
enum PersonalizationInputFieldType { search, input, select }

/// Поле ввода дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Input (167:3746), фрейм Input Field (205:10194).
/// Матрица: 3 размера x 4 состояния x 3 типа.
///
/// Состояния из макета не задаются снаружи, а выводятся из самого поля:
/// Default — пусто, Filled — есть текст, Focus — поле в фокусе, Disabled — [enabled].
///
/// Иконки отдаются путями к SVG-ассетам: пакет не рисует SVG сам,
/// отрисовку выбирает потребитель через [iconBuilder].
///
/// Поле построено на [TextField] ради выделения и меню копирования. [TextField]
/// требует в предках `Material` и `MaterialLocalizations`. Первое компонент
/// добавляет сам, так что его можно класть в любой оверлей. Второе даёт
/// `MaterialApp`; в `CupertinoApp` нужно добавить делегат:
/// ```dart
/// CupertinoApp(
///   localizationsDelegates: [DefaultMaterialLocalizations.delegate],
/// )
/// ```
class PersonalizationInputField extends StatefulWidget {
  const PersonalizationInputField({
    super.key,
    this.controller,
    this.placeholder,
    this.size = PersonalizationInputFieldSize.lg,
    this.type = PersonalizationInputFieldType.search,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onSelectTap,
    this.iconBuilder,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final PersonalizationInputFieldSize size;
  final PersonalizationInputFieldType type;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// Кнопка «искать» на клавиатуре у типа Search, «готово» у остальных.
  final ValueChanged<String>? onSubmitted;

  /// Нажатие на крестик у типа Search. Поле очищается в любом случае.
  final VoidCallback? onClear;

  /// Нажатие на поле у типа Select: список открывает потребитель.
  final VoidCallback? onSelectTap;

  /// Как нарисовать иконку заданного размера и цвета из ассета. Не задан —
  /// место под иконку остаётся пустым, но отступы сохраняются.
  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )? iconBuilder;

  @override
  State<PersonalizationInputField> createState() => _PersonalizationInputFieldState();
}

class _PersonalizationInputFieldState extends State<PersonalizationInputField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  bool get _ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.removeListener(_onTextChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() => _focused = _focusNode.hasFocus);

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final metrics = _inputMetrics[widget.size]!;
    final filled = _controller.text.isNotEmpty;
    final foreground =
        filled && widget.enabled ? colors.textPrimary : colors.textHint;

    final style = TextStyle(
      fontSize: metrics.fontSize,
      height: metrics.lineHeight / metrics.fontSize,
      letterSpacing: metrics.letterSpacing,
      fontWeight: FontWeight.w400,
      fontFamily: theme.fontFamily.familyFor(FontWeight.w400),
      package: theme.fontFamily.package,
      color: foreground,
    );

    // Крестик — это очистка, поэтому он появляется только когда есть что чистить.
    final String? endAsset;
    switch (widget.type) {
      case PersonalizationInputFieldType.select:
        endAsset = PersonalizationIcons.angleDown;
      case PersonalizationInputFieldType.search:
        endAsset = filled && widget.enabled ? PersonalizationIcons.cross : null;
      case PersonalizationInputFieldType.input:
        endAsset = null;
    }

    final field = Container(
      padding: _padding(metrics),
      decoration: BoxDecoration(
        color: widget.enabled ? colors.backgroundInput : colors.backgroundInputDisabled,
        borderRadius: BorderRadius.circular(theme.radius.resolve(metrics.radius)),
        border: Border.all(
          color: _focused && widget.enabled ? colors.lineInputFocus : colors.lineInput,
          width: _border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (widget.type == PersonalizationInputFieldType.search) ...<Widget>[
            // В макете иконка идёт в цвет текста: серая в Default и Disabled, тёмная в Filled.
            _icon(context, PersonalizationIcons.magnifier, metrics, foreground),
            const SizedBox(width: 8),
          ],
          Expanded(child: _body(style, colors)),
          if (endAsset != null) ...<Widget>[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.type == PersonalizationInputFieldType.search
                  ? _clear
                  : widget.onSelectTap,
              child: _icon(context, endAsset, metrics, foreground),
            ),
          ],
        ],
      ),
    );

    // Select — не поле ввода: список открывает потребитель по нажатию на всю строку.
    if (widget.type == PersonalizationInputFieldType.select) {
      return GestureDetector(
        onTap: widget.enabled ? widget.onSelectTap : null,
        child: field,
      );
    }
    return field;
  }

  Widget _body(TextStyle style, PersonalizationColors colors) {
    if (widget.type == PersonalizationInputFieldType.select) {
      final filled = _controller.text.isNotEmpty;
      return Text(
        filled ? _controller.text : (widget.placeholder ?? ''),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    // TextField требует предка Material — без этой обёртки он падает на ассерте
    // везде, кроме Scaffold. Прозрачный тип ничего не рисует поверх нашего фона.
    return Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textInputAction: widget.type == PersonalizationInputFieldType.search
            ? TextInputAction.search
            : TextInputAction.done,
        style: style,
        decoration: InputDecoration.collapsed(
          hintText: widget.placeholder,
          hintStyle: style.copyWith(color: colors.textHint),
        ),
      ),
    );
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  Widget _icon(
    BuildContext context,
    String asset,
    _InputMetrics metrics,
    Color color,
  ) {
    return SizedBox(
      width: metrics.iconSize,
      height: metrics.iconSize,
      child: widget.iconBuilder?.call(context, asset, metrics.iconSize, color),
    );
  }

  EdgeInsets _padding(_InputMetrics metrics) {
    // Рамка добавляется к размеру сверх отступов, поэтому отступ уменьшен на её
    // толщину: иначе поле выходит на 2px выше макета.
    final double vertical = metrics.paddingVertical - _border;
    switch (widget.type) {
      case PersonalizationInputFieldType.search:
        return EdgeInsets.all(vertical);
      case PersonalizationInputFieldType.input:
        return EdgeInsets.symmetric(
          vertical: vertical,
          horizontal: metrics.paddingInput - _border,
        );
      case PersonalizationInputFieldType.select:
        return EdgeInsets.only(
          left: metrics.paddingSelectStart - _border,
          right: vertical,
          top: vertical,
          bottom: vertical,
        );
    }
  }
}

const double _border = 1;

class _InputMetrics {
  const _InputMetrics({
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.radius,
    required this.paddingVertical,
    required this.paddingInput,
    required this.paddingSelectStart,
    required this.iconSize,
  });

  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final PersonalizationRadiusToken radius;
  final double paddingVertical;

  /// Горизонтальный отступ типа Input. У Search он равен вертикальному.
  final double paddingInput;

  /// Отступ слева у типа Select. Справа там тоже вертикальный.
  final double paddingSelectStart;
  final double iconSize;
}

// LG берёт кегль со ступени lg, а интерлиньяж со ступени xl: в макете 18/32,
// тогда как ступень lg — это 18/28. SM так же смешан: 14/24 против 14/20.
const Map<PersonalizationInputFieldSize, _InputMetrics> _inputMetrics =
    <PersonalizationInputFieldSize, _InputMetrics>{
  PersonalizationInputFieldSize.lg: _InputMetrics(
    fontSize: 18,
    lineHeight: 32,
    letterSpacing: 0,
    radius: PersonalizationRadiusToken.buttonLg,
    paddingVertical: 12,
    paddingInput: 16,
    paddingSelectStart: 16,
    iconSize: 32,
  ),
  PersonalizationInputFieldSize.md: _InputMetrics(
    fontSize: 16,
    lineHeight: 24,
    letterSpacing: 0,
    radius: PersonalizationRadiusToken.buttonMd,
    paddingVertical: 8,
    paddingInput: 12,
    paddingSelectStart: 12,
    iconSize: 24,
  ),
  PersonalizationInputFieldSize.sm: _InputMetrics(
    fontSize: 14,
    lineHeight: 24,
    letterSpacing: 0.05,
    radius: PersonalizationRadiusToken.buttonSm,
    paddingVertical: 4,
    paddingInput: 12,
    paddingSelectStart: 8,
    iconSize: 24,
  ),
};
