import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';

/// Состояние чекбокса.
enum PersonalizationCheckboxState { unchecked, checked, indeterminate }

/// Чекбокс дизайн-системы, 20x20.
///
/// Источник: Figma Mobile SDK UI Kit, секция Input, фрейм Checkbox (205:10128).
/// В макете только размер MD, поэтому размера в API нет.
///
/// Галка и черта рисуются штрихом по геометрии из макета:
/// `M5 10 L8.75 13.75 L15 7.5` и `M5 10 H15`, толщина 2, круглые концы.
class PersonalizationCheckbox extends StatelessWidget {
  const PersonalizationCheckbox({
    super.key,
    this.state = PersonalizationCheckboxState.unchecked,
    this.disabled = false,
    this.onChanged,
  });

  final PersonalizationCheckboxState state;
  final bool disabled;

  /// Зовётся с состоянием, в которое чекбокс переходит по нажатию.
  final ValueChanged<PersonalizationCheckboxState>? onChanged;

  static const double size = 20;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final isFilled = state != PersonalizationCheckboxState.unchecked;

    final Widget box = CustomPaint(
      size: const Size.square(size),
      painter: _CheckboxPainter(
        state: state,
        fill: isFilled
            ? (disabled ? colors.buttonPrimaryDisabled : colors.buttonPrimary)
            : (disabled ? colors.backgroundInputDisabled : colors.backgroundInput),
        border: isFilled ? null : colors.lineInput,
        glyph: colors.textLightPrimary,
        radius: theme.radius.resolve(PersonalizationRadiusToken.sm),
      ),
    );

    if (disabled || onChanged == null) return box;

    return GestureDetector(
      onTap: () => onChanged!(
        state == PersonalizationCheckboxState.checked
            ? PersonalizationCheckboxState.unchecked
            : PersonalizationCheckboxState.checked,
      ),
      child: box,
    );
  }
}

class _CheckboxPainter extends CustomPainter {
  const _CheckboxPainter({
    required this.state,
    required this.fill,
    required this.border,
    required this.glyph,
    required this.radius,
  });

  final PersonalizationCheckboxState state;
  final Color fill;
  final Color? border;
  final Color glyph;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.drawRRect(rrect, Paint()..color = fill);

    if (border != null) {
      // Рамка внутрь, чтобы внешний размер остался ровно 20.
      final inset = rect.deflate(0.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(inset, Radius.circular(radius)),
        Paint()
          ..color = border!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    if (state == PersonalizationCheckboxState.unchecked) return;

    final stroke = Paint()
      ..color = glyph
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    if (state == PersonalizationCheckboxState.checked) {
      path
        ..moveTo(5, 10)
        ..lineTo(8.75, 13.75)
        ..lineTo(15, 7.5);
    } else {
      path
        ..moveTo(5, 10)
        ..lineTo(15, 10);
    }
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_CheckboxPainter old) =>
      old.state != state ||
      old.fill != fill ||
      old.border != border ||
      old.glyph != glyph ||
      old.radius != radius;
}
