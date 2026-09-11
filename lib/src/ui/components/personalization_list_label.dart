import 'package:flutter/widgets.dart';

import '../personalization_colors.dart';

/// Подпись-разделитель списка.
///
/// Источник: Figma Mobile SDK UI Kit, секция List (241:10565), символ Label (243:10967).
/// Единственное место в макете, где шрифт берётся из Font Family/Body, а не Heading.
/// Inter в SDK не поставляется, так что на отрисовку это пока не влияет.
///
/// Текст переводится в верхний регистр самим компонентом — так задано в макете.
class PersonalizationListLabel extends StatelessWidget {
  const PersonalizationListLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationColors.of(context);
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: 0.05,
        fontWeight: FontWeight.w400,
        color: colors.textHint,
      ),
    );
  }
}
