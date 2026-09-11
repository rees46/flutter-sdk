import 'package:flutter/widgets.dart';

import '../personalization_colors.dart';

/// Размер бейджа.
enum PersonalizationBadgeSize { sm, md, lg }

/// Бейдж дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Badge (241:7434).
///
/// Внимание: типографика бейджа не совпадает со ступенями [PersonalizationTypography] —
/// кегль берётся с одной ступени, интерлиньяж с другой (20/24, 16/20, 14/16).
/// Поэтому стиль собирается здесь явно, а не переиспользуется.
class PersonalizationBadge extends StatelessWidget {
  const PersonalizationBadge({
    super.key,
    required this.label,
    this.size = PersonalizationBadgeSize.lg,
  });

  final String label;
  final PersonalizationBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationColors.of(context);
    final (padH, padV, radius, fontSize, lineHeight) = switch (size) {
      PersonalizationBadgeSize.lg => (12.0, 8.0, 10.0, 20.0, 24.0),
      PersonalizationBadgeSize.md => (8.0, 4.0, 8.0, 16.0, 20.0),
      PersonalizationBadgeSize.sm => (4.0, 2.0, 6.0, 14.0, 16.0),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: colors.semanticWarning,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight / fontSize,
          fontWeight: FontWeight.w600,
          color: colors.textLightPrimary,
        ),
      ),
    );
  }
}
