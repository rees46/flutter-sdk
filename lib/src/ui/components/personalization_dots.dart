import 'package:flutter/widgets.dart';

import '../personalization_colors.dart';

/// Точки-индикатор карусели.
///
/// Источник: Figma Mobile SDK UI Kit, секция Navigation (90:660),
/// символы Dots (90:669) и Dot (90:685).
/// В макете нарисовано пять точек, число вынесено в API.
class PersonalizationDots extends StatelessWidget {
  const PersonalizationDots({
    super.key,
    required this.count,
    this.selectedIndex = 0,
  });

  final int count;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (int index = 0; index < count; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 12),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == selectedIndex
                    ? colors.brandPrimary
                    : colors.lineGeneric,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
