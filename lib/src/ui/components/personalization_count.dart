import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';

/// Счётчик «показано N из M».
///
/// Источник: Figma Mobile SDK UI Kit, секция Navigation (90:660), символ Count (301:6810).
/// Слова — параметры, а не константы: локализация остаётся за интегратором.
/// В макете это «Showed 6 from 569».
class PersonalizationCount extends StatelessWidget {
  const PersonalizationCount({
    super.key,
    required this.prefix,
    required this.shown,
    required this.separator,
    required this.total,
  });

  /// Слово перед первым числом («Показано»).
  final String prefix;
  final int shown;

  /// Слово между числами («из»).
  final String separator;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    const double fontSize = 16;
    final TextStyle regular = TextStyle(
      fontSize: fontSize,
      height: 24 / fontSize,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
      fontFamily: theme.fontFamily.familyFor(FontWeight.w400),
      package: theme.fontFamily.package,
      color: colors.textSecondary,
    );
    final TextStyle strong = regular.copyWith(
      fontWeight: FontWeight.w600,
      fontFamily: theme.fontFamily.familyFor(FontWeight.w600),
      package: theme.fontFamily.package,
      color: colors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(prefix, style: regular),
          const SizedBox(width: 4),
          Text('$shown', style: strong),
          const SizedBox(width: 4),
          Text(separator, style: regular),
          const SizedBox(width: 4),
          Text('$total', style: strong),
        ],
      ),
    );
  }
}
