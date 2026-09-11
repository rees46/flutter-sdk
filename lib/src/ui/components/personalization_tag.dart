import 'package:flutter/widgets.dart';

import '../personalization_colors.dart';
import '../personalization_icons.dart';

/// Вид тега.
enum PersonalizationTagView { primary, secondary }

/// Тег дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Tag (243:10993).
/// В макете только размер MD, поэтому размера в API нет.
///
/// Крестик удаления отдаётся как путь к SVG-ассету в [iconAsset]: пакет не
/// рисует SVG сам, отрисовку выбирает потребитель.
class PersonalizationTag extends StatelessWidget {
  const PersonalizationTag({
    super.key,
    required this.label,
    this.view = PersonalizationTagView.primary,
    this.onRemove,
    this.removeIconBuilder,
  });

  final String label;
  final PersonalizationTagView view;

  /// Задан — тег показывает крестик и зовёт колбэк по нажатию.
  final VoidCallback? onRemove;

  /// Как нарисовать крестик 16x16 из [iconAsset]. Не задан — место под иконку
  /// остаётся пустым, но отступы сохраняются.
  final Widget Function(BuildContext context, String asset)? removeIconBuilder;

  /// Ассет крестика для [removeIconBuilder].
  static const String iconAsset = PersonalizationIcons.cross;

  bool get _removable => onRemove != null;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationColors.of(context);
    final isPrimary = view == PersonalizationTagView.primary;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: _removable ? 4 : 8,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: isPrimary ? colors.buttonPrimary : colors.buttonSecondary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              letterSpacing: 0.05,
              fontWeight: FontWeight.w400,
              color: isPrimary ? colors.textLightPrimary : colors.textPrimary,
            ),
          ),
          if (_removable) ...<Widget>[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: SizedBox(
                width: 16,
                height: 16,
                child: removeIconBuilder?.call(context, iconAsset),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
