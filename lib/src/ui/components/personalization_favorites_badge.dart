import 'package:flutter/widgets.dart';

import '../personalization_icons.dart';
import '../personalization_theme.dart';

/// Метка «в избранном»: звезда в круге цвета Semantic/Warning, 24x24.
///
/// Источник: Figma Mobile SDK UI Kit, секция Badge, символ Favorites (391:17117).
class PersonalizationFavoritesBadge extends StatelessWidget {
  const PersonalizationFavoritesBadge({super.key, this.iconBuilder});

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    return Container(
      // Звезда 16 плюс поле 4 с каждой стороны.
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.semanticWarning,
      ),
      child: iconBuilder?.call(
        context,
        PersonalizationIcons.starFill,
        16,
        colors.textLightPrimary,
      ),
    );
  }
}
