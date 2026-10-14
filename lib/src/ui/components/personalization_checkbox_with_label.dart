import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';
import 'personalization_checkbox.dart';

/// Чекбокс с подписью.
///
/// Источник: Figma Mobile SDK UI Kit, фрейм Checkbox with Label (205:10151).
/// Зазор 8, подпись 16/20 обычного начертания; в disabled подпись уходит
/// в Text/Hint.
class PersonalizationCheckboxWithLabel extends StatelessWidget {
  const PersonalizationCheckboxWithLabel({
    super.key,
    required this.label,
    this.state = PersonalizationCheckboxState.unchecked,
    this.disabled = false,
    this.onChanged,
  });

  final String label;
  final PersonalizationCheckboxState state;
  final bool disabled;
  final ValueChanged<PersonalizationCheckboxState>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        PersonalizationCheckbox(state: state, disabled: disabled),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            height: 20 / 16,
            fontWeight: FontWeight.w400,
            fontFamily: theme.fontFamily.familyFor(FontWeight.w400),
            package: theme.fontFamily.package,
            color: disabled ? colors.textHint : colors.textPrimary,
          ),
        ),
      ],
    );

    if (disabled || onChanged == null) return row;

    return GestureDetector(
      onTap: () => onChanged!(
        state == PersonalizationCheckboxState.checked
            ? PersonalizationCheckboxState.unchecked
            : PersonalizationCheckboxState.checked,
      ),
      child: row,
    );
  }
}
