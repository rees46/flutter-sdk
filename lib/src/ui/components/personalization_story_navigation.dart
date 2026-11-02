import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../personalization_icons.dart';
import '../personalization_spacing.dart';
import '../personalization_theme.dart';
import 'personalization_story_progress.dart';

/// Шапка просмотра сторис: прогресс слайдов и крестик.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент
/// Navigation/Story.
///
/// Колонка с шагом 12: [PersonalizationStoryProgress] и строка высотой 32, в конце
/// которой крестик — иконка cross 32 (глиф 18) цвета Text/Secondary с прозрачностью 65%.
/// С [onShare] слева от крестика, через 8, — «Поделиться» в том же виде: коробка 32,
/// глиф 18, Text/Secondary, 65%, без фона. Касания ловят только кнопки.
class PersonalizationStoryNavigation extends StatelessWidget {
  const PersonalizationStoryNavigation({
    super.key,
    required this.count,
    this.current = 0,
    this.progress = 0,
    this.onClose,
    this.closeLabel = 'Close',
    this.onShare,
    this.shareLabel = 'Share',
    this.iconBuilder,
  });

  /// См. [PersonalizationStoryProgress].
  final int count;
  final int current;
  final double progress;

  final VoidCallback? onClose;

  /// Подпись крестика для скринридера.
  final String closeLabel;

  /// Нажата «Поделиться»; `null` — кнопки нет. Приходит кнопка в глобальных логических
  /// координатах: к ней на iPad крепится системное окно.
  final ValueChanged<Rect>? onShare;

  /// Подпись «Поделиться» для скринридера.
  final String shareLabel;

  /// Как нарисовать крестик: пакет не рисует SVG сам.
  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  static const double _close = 32;

  /// Высота шапки: прогресс, шаг 12 и строка крестика.
  static const double height =
      PersonalizationStoryProgress.height + 12 + _close;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Прогресс касаний не ловит: они уходят слайду под шапкой.
        IgnorePointer(
          child: PersonalizationStoryProgress(
            count: count,
            current: current,
            progress: progress,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _close,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (onShare != null) ...<Widget>[
                Semantics(
                  button: true,
                  label: shareLabel,
                  child: _ShareButton(
                    onPressed: onShare!,
                    child: _icon(
                      context,
                      PersonalizationIcons.share,
                      colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: PersonalizationSpacing.md),
              ],
              Semantics(
                button: true,
                label: closeLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: _icon(
                    context,
                    PersonalizationIcons.cross,
                    colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Иконка кнопки шапки: коробка 32, прозрачность 65%.
  Widget _icon(BuildContext context, String asset, Color color) =>
      SizedBox.square(
        dimension: _close,
        child: Opacity(
          opacity: 0.65,
          child: iconBuilder?.call(context, asset, _close, color),
        ),
      );
}

/// «Поделиться»: нажатие любой длины — нажатие. Удержание и свайпы, начатые на кнопке,
/// забирает она сама — слайд под ней не встаёт на паузу удержания и не листается.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.onPressed, required this.child});

  final ValueChanged<Rect> onPressed;
  final Widget child;

  /// Короче удержания слайда (200 мс): долгое нажатие достаётся кнопке, а не слайду.
  static const Duration _hold = Duration(milliseconds: 150);

  void _press(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    onPressed(box.localToGlobal(Offset.zero) & box.size);
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.opaque,
    gestures: <Type, GestureRecognizerFactory>{
      TapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            TapGestureRecognizer.new,
            (recognizer) => recognizer.onTap = () => _press(context),
          ),
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(duration: _hold),
            (recognizer) => recognizer.onLongPressEnd = (details) {
              // Отпустили на кнопке — нажатие; увели палец — ничего.
              final box = context.findRenderObject() as RenderBox?;
              if (box != null && box.size.contains(details.localPosition)) {
                _press(context);
              }
            },
          ),
      VerticalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
            VerticalDragGestureRecognizer.new,
            (recognizer) => recognizer.onStart = (_) {},
          ),
      HorizontalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
            HorizontalDragGestureRecognizer.new,
            (recognizer) => recognizer.onStart = (_) {},
          ),
    },
    child: child,
  );
}
