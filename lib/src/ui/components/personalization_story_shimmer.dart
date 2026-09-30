import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';

/// Переливание заглушек сторис: кольцо и картинка обложки, подпись превью.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), состояние Skeleton у
/// Story/Cover и Story/Preview — градиент чёрный 5% → 30% → 5%. Здесь он идёт от
/// Text/Primary, а не от сырого чёрного: в тёмной схеме чёрная заглушка пропала бы на
/// фоне, а белая с той же прозрачностью читается так же, как чёрная на светлом.
///
/// Градиент проезжает по заглушке слева направо за [period]; [builder] получает его на
/// каждом кадре и сам решает, чем залить — фоном или шейдером кисти.
///
/// Внутренняя деталь обложки и превью: из кита не экспортируется.
class PersonalizationStoryShimmer extends StatefulWidget {
  const PersonalizationStoryShimmer({
    super.key,
    required this.builder,
    this.period = const Duration(milliseconds: 1200),
  });

  final Widget Function(BuildContext context, Gradient gradient) builder;
  final Duration period;

  @override
  State<PersonalizationStoryShimmer> createState() =>
      _PersonalizationStoryShimmerState();
}

class _PersonalizationStoryShimmerState
    extends State<PersonalizationStoryShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = PersonalizationTheme.of(context).colors.textPrimary;
    final faint = base.withValues(alpha: 0.05);
    final strong = base.withValues(alpha: 0.30);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(
        context,
        LinearGradient(
          colors: <Color>[faint, strong, faint],
          // Полоса шириной в заглушку въезжает слева и уходит вправо.
          transform: _Slide(_controller.value * 2 - 1),
        ),
      ),
    );
  }
}

/// Сдвиг градиента по горизонтали в долях ширины заглушки.
class _Slide extends GradientTransform {
  const _Slide(this.fraction);

  final double fraction;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}
