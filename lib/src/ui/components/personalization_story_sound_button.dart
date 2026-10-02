import 'package:flutter/widgets.dart';

import '../personalization_icons.dart';
import '../personalization_theme.dart';

/// Кнопка звука видео-слайда: динамик или перечёркнутый динамик.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), слайды с видео —
/// иконки speaker / speaker-off 32 цвета Text/Secondary в левом нижнем углу.
class PersonalizationStorySoundButton extends StatelessWidget {
  const PersonalizationStorySoundButton({
    super.key,
    required this.muted,
    this.onPressed,
    this.soundOnLabel = 'Sound on',
    this.soundOffLabel = 'Sound off',
    this.iconBuilder,
  });

  /// Звук выключен: показывается перечёркнутый динамик.
  final bool muted;
  final VoidCallback? onPressed;

  /// Подписи для скринридера — действие, которое сделает нажатие: без звука —
  /// [soundOnLabel], со звуком — [soundOffLabel].
  final String soundOnLabel;
  final String soundOffLabel;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  static const double size = 32;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    return Semantics(
      button: true,
      label: muted ? soundOnLabel : soundOffLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: iconBuilder?.call(
            context,
            muted
                ? PersonalizationIcons.speakerOff
                : PersonalizationIcons.speaker,
            size,
            colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
