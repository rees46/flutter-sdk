import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';

/// Прогресс сторис: по отрезку на слайд.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), шапка Navigation/Story.
///
/// [count] отрезков равной ширины, высота 2, шаг 2, скругление 1. Дорожка — Line/Generic,
/// заливка — Text/Secondary. Отрезки до [current] залиты целиком, текущий — на
/// [progress] (0…1), после него — пустые.
class PersonalizationStoryProgress extends StatelessWidget {
  const PersonalizationStoryProgress({
    super.key,
    required this.count,
    this.current = 0,
    this.progress = 0,
  });

  final int count;

  /// Индекс текущего слайда.
  final int current;

  /// Сколько показано из текущего слайда, 0…1.
  final double progress;

  static const double height = 2;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    final radius = BorderRadius.circular(1);
    return SizedBox(
      height: height,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < count; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: ClipRRect(
                borderRadius: radius,
                child: ColoredBox(
                  color: colors.lineGeneric,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: i < current
                          ? 1
                          : i == current
                          ? progress.clamp(0, 1).toDouble()
                          : 0,
                      heightFactor: 1,
                      child: ColoredBox(color: colors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
