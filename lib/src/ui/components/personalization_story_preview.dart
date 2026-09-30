import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';
import '../personalization_typography.dart';
import 'personalization_story_cover.dart';
import 'personalization_story_shimmer.dart';

/// Превью сторис в ленте: обложка и подпись под ней.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент Story/Preview.
///
/// Колонка шириной 88 с шагом 8: [PersonalizationStoryCover] и подпись Regular 12/16
/// (ступень XS) цветом Text/Primary, по центру, в одну строку с многоточием. У заглушки
/// вместо подписи — переливающаяся плашка 64×8 со скруглением 5 на месте строки.
class PersonalizationStoryPreview extends StatelessWidget {
  const PersonalizationStoryPreview({
    super.key,
    this.label = '',
    this.image,
    this.state = PersonalizationStoryCoverState.unviewed,
    this.pinned = false,
    this.segments = 0,
    this.seenSegments = 0,
    this.onTap,
    this.iconBuilder,
  });

  final String label;
  final ImageProvider? image;
  final PersonalizationStoryCoverState state;
  final bool pinned;

  /// См. [PersonalizationStoryCover.segments].
  final int segments;

  /// См. [PersonalizationStoryCover.seenSegments].
  final int seenSegments;

  /// Нажатие на превью — открыть сторис. У заглушки не вызывается.
  final VoidCallback? onTap;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  static const double width = PersonalizationStoryCover.size;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final skeleton = state == PersonalizationStoryCoverState.skeleton;
    const style = PersonalizationTypography.xsDefault;

    final column = SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PersonalizationStoryCover(
            image: image,
            state: state,
            pinned: pinned,
            segments: segments,
            seenSegments: seenSegments,
            iconBuilder: iconBuilder,
          ),
          const SizedBox(height: 8),
          if (skeleton)
            // Плашка на месте строки: высота превью та же, что с подписью.
            SizedBox(
              height: 16,
              child: Center(
                child: PersonalizationStoryShimmer(
                  builder: (context, gradient) => Container(
                    width: 64,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: gradient,
                    ),
                  ),
                ),
              ),
            )
          else
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: style.copyWith(
                color: theme.colors.textPrimary,
                fontFamily: theme.fontFamily.familyFor(style.fontWeight!),
                package: theme.fontFamily.package,
              ),
            ),
        ],
      ),
    );

    if (skeleton || onTap == null) return column;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: column,
      ),
    );
  }
}
