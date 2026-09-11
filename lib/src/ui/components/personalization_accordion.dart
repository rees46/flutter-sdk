import 'package:flutter/widgets.dart';

import '../personalization_colors.dart';
import '../personalization_icons.dart';

/// Строка-аккордеон списка.
///
/// Источник: Figma Mobile SDK UI Kit, секция List (241:10565), фрейм Accordion (241:10575).
/// Два варианта — Expanded=False и True, отличаются только направлением шеврона.
///
/// Шеврон отдаётся путём к SVG-ассету: пакет не рисует SVG сам,
/// отрисовку выбирает потребитель через [iconBuilder].
class PersonalizationAccordion extends StatelessWidget {
  const PersonalizationAccordion({
    super.key,
    required this.label,
    this.count,
    this.expanded = false,
    this.onToggle,
    this.iconBuilder,
  });

  final String label;

  /// Число в скобках после подписи. `null` — не показывать.
  final int? count;
  final bool expanded;
  final ValueChanged<bool>? onToggle;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationColors.of(context);
    final style = TextStyle(
      fontSize: 16,
      height: 24 / 16,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
      color: colors.textPrimary,
    );
    final asset =
        expanded ? PersonalizationIcons.angleUp : PersonalizationIcons.angleDown;

    return GestureDetector(
      onTap: onToggle == null ? null : () => onToggle!(!expanded),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(label, style: style),
          if (count != null) ...<Widget>[
            const SizedBox(width: 4),
            Text('($count)', style: style.copyWith(color: colors.textSecondary)),
          ],
          const SizedBox(width: 4),
          SizedBox(
            width: 24,
            height: 24,
            child: iconBuilder?.call(context, asset, 24, colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
