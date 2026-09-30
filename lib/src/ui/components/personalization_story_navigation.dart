import 'package:flutter/widgets.dart';

import '../personalization_icons.dart';
import '../personalization_theme.dart';
import 'personalization_story_progress.dart';

/// Шапка просмотра сторис: прогресс слайдов и крестик.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент
/// Navigation/Story.
///
/// Колонка с шагом 12: [PersonalizationStoryProgress] и строка высотой 32, в конце
/// которой крестик — иконка cross 32 (глиф 18) цвета Text/Secondary с прозрачностью 65%.
class PersonalizationStoryNavigation extends StatelessWidget {
  const PersonalizationStoryNavigation({
    super.key,
    required this.count,
    this.current = 0,
    this.progress = 0,
    this.onClose,
    this.closeLabel = 'Close',
    this.iconBuilder,
  });

  /// См. [PersonalizationStoryProgress].
  final int count;
  final int current;
  final double progress;

  final VoidCallback? onClose;

  /// Подпись крестика для скринридера.
  final String closeLabel;

  /// Как нарисовать крестик: пакет не рисует SVG сам.
  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  static const double _close = 32;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PersonalizationStoryProgress(
          count: count,
          current: current,
          progress: progress,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _close,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Semantics(
              button: true,
              label: closeLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: SizedBox.square(
                  dimension: _close,
                  child: Opacity(
                    opacity: 0.65,
                    child: iconBuilder?.call(
                      context,
                      PersonalizationIcons.cross,
                      _close,
                      colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
