import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';
import '../personalization_typography.dart';

/// Текстовая ссылка: «Cancel» у поля поиска, «Clear» у недавних запросов.
///
/// В секции Components такого символа нет — стиль снят с экранов Instant Search
/// (страница InstantSearchField, 151:3976 и 310:9829): кегль base 16/24,
/// начертание 600, цвет Text/Link, без подложки и отступов. Нажатого состояния
/// в макете нет, поэтому ссылка только слегка гаснет под пальцем.
class PersonalizationLink extends StatefulWidget {
  const PersonalizationLink({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  State<PersonalizationLink> createState() => _PersonalizationLinkState();
}

class _PersonalizationLinkState extends State<PersonalizationLink> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: Opacity(
        opacity: _pressed ? _pressedOpacity : 1,
        child: Text(
          widget.label,
          maxLines: 1,
          style: PersonalizationTypography.baseEmphasized.copyWith(
            fontFamily: theme.fontFamily.familyFor(FontWeight.w600),
            package: theme.fontFamily.package,
            color: theme.colors.textLink,
          ),
        ),
      ),
    );
  }

  static const double _pressedOpacity = 0.6;
}
