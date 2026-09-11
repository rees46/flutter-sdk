import 'package:flutter/widgets.dart';

import '../personalization_colors.dart';

/// Заголовок блока.
///
/// Источник: Figma Mobile SDK UI Kit, секция Title (167:3802).
/// Все четыре заголовка на странице — один и тот же ряд «слева иконка, заголовок,
/// справа управление», отличается только содержимое по краям:
/// Recommender block (157:5176) — кнопка «Show all», Category (167:3812) — группа кнопок,
/// Filters (204:8340) — кнопка-крестик, Search results (167:3807) — кнопка «назад» и группа.
/// Поэтому края здесь — произвольные виджеты, а не фиксированные варианты.
class PersonalizationTitle extends StatelessWidget {
  const PersonalizationTitle({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (leading != null) ...<Widget>[leading!, const SizedBox(width: 4)],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 24,
              height: 36 / 24,
              letterSpacing: 0,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 4), trailing!],
      ],
    );
  }
}
