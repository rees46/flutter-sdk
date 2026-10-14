import 'package:flutter/widgets.dart';

import '../personalization_colors.dart';
import '../personalization_theme.dart';

/// Размер кнопки.
enum PersonalizationButtonSize { lg, md, sm }

/// Вид кнопки.
enum PersonalizationButtonView { primary, secondary, ghost }

/// Кнопка дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Button (90:862), фрейм 90:869.
/// Матрица: 3 размера x 3 вида x 3 состояния x 4 конфигурации контента.
///
/// Состояние Focus из макета — это нажатие, оно ведётся внутри виджета.
/// Disabled наступает, когда [onPressed] не задан.
///
/// Иконки отдаются путями к SVG-ассетам ([PersonalizationIcons]): пакет не
/// рисует SVG сам, отрисовку выбирает потребитель через [iconBuilder].
class PersonalizationButton extends StatefulWidget {
  const PersonalizationButton({
    super.key,
    this.label,
    this.size = PersonalizationButtonSize.lg,
    this.view = PersonalizationButtonView.primary,
    this.onPressed,
    this.iconStart,
    this.iconEnd,
    this.iconBuilder,
    this.onDark = false,
    this.rounded = false,
  });

  final String? label;
  final PersonalizationButtonSize size;
  final PersonalizationButtonView view;

  /// Не задан — кнопка недоступна.
  final VoidCallback? onPressed;

  /// Кнопка стоит поверх тёмного (картинки-фона). В макете такие контролы берут
  /// инвертированную палитру: заливка Secondary белая 5%, подпись и иконка светлые.
  /// На [PersonalizationButtonView.primary] не влияет — она и так светлая по тексту.
  final bool onDark;

  /// Скругление Rounded вместо радиуса размера: кнопка-иконка становится кругом.
  /// Так в макете устроен крестик Close (секция Button) — кнопка MD Secondary,
  /// у которой радиус переопределён на Rounded.
  final bool rounded;

  /// Ассет иконки перед текстом. Без текста кнопка становится кнопкой-иконкой.
  final String? iconStart;

  /// Ассет иконки после текста.
  final String? iconEnd;

  /// Как нарисовать иконку заданного размера и цвета из ассета. Не задан —
  /// место под иконку остаётся пустым, но отступы сохраняются.
  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  @override
  State<PersonalizationButton> createState() => _PersonalizationButtonState();
}

class _PersonalizationButtonState extends State<PersonalizationButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  bool get _hasText => widget.label != null && widget.label!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final metrics = _metrics[widget.size]!;
    final foreground = _foreground(colors);

    final children = <Widget>[
      if (widget.iconStart != null)
        _icon(context, widget.iconStart!, metrics, foreground),
      if (_hasText)
        Text(
          widget.label!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: metrics.fontSize,
            height: metrics.lineHeight / metrics.fontSize,
            letterSpacing: metrics.letterSpacing,
            fontWeight: FontWeight.w600,
            fontFamily: theme.fontFamily.familyFor(FontWeight.w600),
            package: theme.fontFamily.package,
            color: foreground,
          ),
        ),
      if (widget.iconEnd != null)
        _icon(context, widget.iconEnd!, metrics, foreground),
    ];

    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      child: Container(
        padding: _padding(metrics),
        decoration: BoxDecoration(
          color: _background(colors),
          borderRadius: BorderRadius.circular(
            theme.radius.resolve(
              widget.rounded
                  ? PersonalizationRadiusToken.rounded
                  : metrics.radius,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _icon(
    BuildContext context,
    String asset,
    _ButtonMetrics metrics,
    Color color,
  ) {
    return SizedBox(
      width: metrics.iconSize,
      height: metrics.iconSize,
      child: widget.iconBuilder?.call(context, asset, metrics.iconSize, color),
    );
  }

  EdgeInsets _padding(_ButtonMetrics metrics) {
    if (!_hasText) {
      // Кнопка-иконка: по вертикали как у текстовой, по горизонтали своё — 12/8/4.
      return EdgeInsets.symmetric(
        vertical: metrics.paddingVertical,
        horizontal: metrics.paddingIconOnly,
      );
    }
    return EdgeInsets.only(
      left: widget.iconStart != null
          ? metrics.paddingNarrow
          : metrics.paddingWide,
      right: widget.iconEnd != null
          ? metrics.paddingNarrow
          : metrics.paddingWide,
      top: metrics.paddingVertical,
      bottom: metrics.paddingVertical,
    );
  }

  Color _background(PersonalizationColors colors) {
    if (!_enabled) {
      switch (widget.view) {
        case PersonalizationButtonView.primary:
          return colors.buttonPrimaryDisabled;
        case PersonalizationButtonView.secondary:
          return colors.buttonSecondaryDisabled;
        case PersonalizationButtonView.ghost:
          return colors.backgroundTransparent;
      }
    }
    if (_pressed) {
      // Ghost в нажатии красится тем же, что и Secondary.
      return widget.view == PersonalizationButtonView.primary
          ? colors.buttonPrimaryFocus
          : colors.buttonSecondaryFocus;
    }
    switch (widget.view) {
      // Кнопка привязана к Brand/Primary, а не к Button/Primary — так в макете.
      case PersonalizationButtonView.primary:
        return colors.brandPrimary;
      case PersonalizationButtonView.secondary:
        return widget.onDark
            ? colors.buttonSecondaryOnDark
            : colors.buttonSecondary;
      case PersonalizationButtonView.ghost:
        return colors.backgroundTransparent;
    }
  }

  Color _foreground(PersonalizationColors colors) {
    if (widget.view == PersonalizationButtonView.primary || widget.onDark) {
      return _enabled ? colors.textLightPrimary : colors.textLightHint;
    }
    return _enabled ? colors.textPrimary : colors.textHint;
  }
}

class _ButtonMetrics {
  const _ButtonMetrics({
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.radius,
    required this.paddingVertical,
    required this.paddingWide,
    required this.paddingNarrow,
    required this.paddingIconOnly,
    required this.iconSize,
  });

  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final PersonalizationRadiusToken radius;
  final double paddingVertical;

  /// Горизонтальный отступ со стороны без иконки.
  final double paddingWide;

  /// Горизонтальный отступ со стороны с иконкой.
  final double paddingNarrow;

  /// Горизонтальный отступ кнопки-иконки: у LG он 12 при вертикальном 8,
  /// у остальных равен вертикальному.
  final double paddingIconOnly;
  final double iconSize;
}

const Map<PersonalizationButtonSize, _ButtonMetrics> _metrics =
    <PersonalizationButtonSize, _ButtonMetrics>{
      PersonalizationButtonSize.lg: _ButtonMetrics(
        fontSize: 20,
        lineHeight: 32,
        letterSpacing: 0,
        radius: PersonalizationRadiusToken.buttonLg,
        paddingVertical: 8,
        paddingWide: 24,
        paddingNarrow: 16,
        paddingIconOnly: 12,
        iconSize: 32,
      ),
      PersonalizationButtonSize.md: _ButtonMetrics(
        fontSize: 16,
        lineHeight: 24,
        letterSpacing: 0,
        radius: PersonalizationRadiusToken.buttonMd,
        paddingVertical: 8,
        paddingWide: 16,
        paddingNarrow: 12,
        paddingIconOnly: 8,
        iconSize: 24,
      ),
      // SM берёт кегль со ступени sm, а интерлиньяж со ступени base:
      // в макете 14/24, тогда как ступень sm — это 14/20.
      PersonalizationButtonSize.sm: _ButtonMetrics(
        fontSize: 14,
        lineHeight: 24,
        letterSpacing: 0.05,
        radius: PersonalizationRadiusToken.buttonSm,
        paddingVertical: 4,
        paddingWide: 12,
        paddingNarrow: 8,
        paddingIconOnly: 4,
        iconSize: 20,
      ),
    };
