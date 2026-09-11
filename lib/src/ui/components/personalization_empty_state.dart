import 'package:flutter/widgets.dart';

import '../personalization_colors.dart';

/// Пустое состояние дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Empty State (319:7736).
/// Горизонтальные отступы 16, вертикальные 92, текст по центру ступенью
/// XL/Default цветом Text/Secondary.
///
/// Текст не зашит: в макете стоит «No results for your request.», но строку
/// подставляет потребитель — локализация остаётся на его стороне.
class PersonalizationEmptyState extends StatelessWidget {
  const PersonalizationEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 92),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            height: 32 / 20,
            fontWeight: FontWeight.w400,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
