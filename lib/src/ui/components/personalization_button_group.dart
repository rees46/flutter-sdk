import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';

/// Размер группы кнопок.
enum PersonalizationButtonGroupSize { md, sm }

/// Сегмент группы.
class PersonalizationButtonGroupItem {
  const PersonalizationButtonGroupItem({required this.icon, this.activeIcon});

  /// Ассет иконки сегмента.
  final String icon;

  /// Ассет иконки выбранного сегмента. В макете Grid оставляет ту же иконку,
  /// а List подменяет её на залитую, поэтому это отдельное поле.
  final String? activeIcon;
}

/// Группа кнопок (сегментированный переключатель).
///
/// Источник: Figma Mobile SDK UI Kit, секция Button Group (185:5253):
/// фрейм Base Button (185:5315) — сегмент, фрейм Button Group (185:5484) — сама группа.
///
/// В макете нарисован только случай на два сегмента (Grid/List) в размере MD,
/// сегмент же есть и в MD, и в SM — поэтому размер вынесен в API,
/// а число сегментов не ограничено.
class PersonalizationButtonGroup extends StatelessWidget {
  const PersonalizationButtonGroup({
    super.key,
    required this.items,
    this.selectedIndex = 0,
    this.size = PersonalizationButtonGroupSize.md,
    this.onSelected,
    this.iconBuilder,
  });

  final List<PersonalizationButtonGroupItem> items;
  final int selectedIndex;
  final PersonalizationButtonGroupSize size;
  final ValueChanged<int>? onSelected;

  /// Как нарисовать иконку заданного размера и цвета из ассета. Не задан —
  /// место под иконку остаётся пустым, но отступы сохраняются.
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
    final metrics = _groupMetrics[size]!;
    final side = metrics.iconSize + metrics.padding * 2;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.buttonSecondary,
        borderRadius: BorderRadius.circular(
          theme.radius.resolve(PersonalizationRadiusToken.buttonMd),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int index = 0; index < items.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 2),
            _segment(context, theme, metrics, side, index),
          ],
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    PersonalizationTheme theme,
    _GroupMetrics metrics,
    double side,
    int index,
  ) {
    final colors = theme.colors;
    final item = items[index];
    final active = index == selectedIndex;
    final asset = active ? (item.activeIcon ?? item.icon) : item.icon;
    final tint = active ? colors.textInvertedPrimary : colors.textHint;

    return GestureDetector(
      onTap: onSelected == null ? null : () => onSelected!(index),
      child: Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colors.buttonPrimary : colors.backgroundTransparent,
          borderRadius: BorderRadius.circular(theme.radius.resolve(metrics.radius)),
        ),
        child: SizedBox(
          width: metrics.iconSize,
          height: metrics.iconSize,
          child: iconBuilder?.call(context, asset, metrics.iconSize, tint),
        ),
      ),
    );
  }
}

class _GroupMetrics {
  const _GroupMetrics({
    required this.radius,
    required this.padding,
    required this.iconSize,
  });

  final PersonalizationRadiusToken radius;

  /// Отступ сегмента: 6 в MD и 2 в SM, обоих значений нет в шкале спейсингов.
  final double padding;
  final double iconSize;
}

const Map<PersonalizationButtonGroupSize, _GroupMetrics> _groupMetrics =
    <PersonalizationButtonGroupSize, _GroupMetrics>{
  PersonalizationButtonGroupSize.md:
      _GroupMetrics(radius: PersonalizationRadiusToken.segmentedMd, padding: 6, iconSize: 24),
  PersonalizationButtonGroupSize.sm:
      _GroupMetrics(radius: PersonalizationRadiusToken.segmentedSm, padding: 2, iconSize: 20),
};
