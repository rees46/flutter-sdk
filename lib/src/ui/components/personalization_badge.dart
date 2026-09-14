import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';

/// Размер бейджа.
enum PersonalizationBadgeSize { sm, md, lg }

/// Вид: warning — как в секции Badge, danger — бейдж скидки на карточке товара (Card/Product, 126:2263), тот же SM в цвете Semantic/Danger.
enum PersonalizationBadgeView { warning, danger }

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
    this.view = PersonalizationBadgeView.warning,
  });

  final String label;
  final PersonalizationBadgeSize size;
  final PersonalizationBadgeView view;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final (padH, padV, radius, fontSize, lineHeight) = switch (size) {
      PersonalizationBadgeSize.lg =>
        (12.0, 8.0, PersonalizationRadiusToken.buttonLg, 20.0, 24.0),
      PersonalizationBadgeSize.md =>
        (8.0, 4.0, PersonalizationRadiusToken.buttonMd, 16.0, 20.0),
      PersonalizationBadgeSize.sm =>
        (4.0, 2.0, PersonalizationRadiusToken.buttonSm, 14.0, 16.0),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: view == PersonalizationBadgeView.danger
            ? colors.semanticDanger
            : colors.semanticWarning,
        borderRadius: BorderRadius.circular(theme.radius.resolve(radius)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight / fontSize,
          fontWeight: FontWeight.w600,
          fontFamily: theme.fontFamily.familyFor(FontWeight.w600),
          package: theme.fontFamily.package,
          color: colors.textLightPrimary,
        ),
      ),
    );
  }
}
