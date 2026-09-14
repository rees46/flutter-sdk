import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';
import '../personalization_icons.dart';

/// Рейтинг товара, короткая форма.
///
/// Источник: Figma Mobile SDK UI Kit, секция Rating (88:209), фрейм Product Short (237:4711).
/// Вариант Reviews меняет только данные и цвет звезды: без отзывов она серая.
///
/// Внимание: типографика 16/20 — кегль со ступени base, интерлиньяж со ступени sm.
/// Ступень base — это 16/24, поэтому размеры заданы явно.
///
/// Цвет заполненной звезды в макете не привязан к переменной, взят ближайший
/// существующий токен semanticWarning — его стоит подтвердить у дизайнера.
class PersonalizationRating extends StatelessWidget {
  const PersonalizationRating({
    super.key,
    required this.value,
    required this.reviews,
    this.iconBuilder,
  });

  /// Уже отформатированная оценка: в макете «4,7» с запятой.
  final String value;
  final int reviews;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    const double fontSize = 16;
    final TextStyle base = TextStyle(
      fontSize: fontSize,
      height: 20 / fontSize,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
      fontFamily: theme.fontFamily.familyFor(FontWeight.w400),
      package: theme.fontFamily.package,
      color: colors.textHint,
    );
    final Color starColor =
        reviews > 0 ? colors.semanticWarning : colors.lineGeneric;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 20,
            height: 20,
            child: iconBuilder?.call(
              context,
              PersonalizationIcons.starFill,
              20,
              starColor,
            ),
          ),
          const SizedBox(width: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                value,
                style: base.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFamily: theme.fontFamily.familyFor(FontWeight.w600),
                  package: theme.fontFamily.package,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 2),
              Text('($reviews)', style: base),
            ],
          ),
        ],
      ),
    );
  }
}
