import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Индикатор загрузки дизайн-системы.
///
/// Источник: Figma Mobile SDK UI Kit, секция Loader (296:3717).
/// Кольцо 26 с внешним радиусом 13 и толщиной 3.5, свип-градиент от прозрачного
/// к чёрному 47%, вращение против часовой стрелки.
///
/// Градиент снят с растрового экспорта макета: в переменных Figma значение
/// `Gradient/Loader` приходит пустым.
class PersonalizationLoader extends StatefulWidget {
  const PersonalizationLoader({
    super.key,
    this.size = 26,
    this.period = const Duration(milliseconds: 900),
  });

  final double size;
  final Duration period;

  @override
  State<PersonalizationLoader> createState() => _PersonalizationLoaderState();
}

class _PersonalizationLoaderState extends State<PersonalizationLoader>
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
    // Контейнер повторяет макет: вертикальные отступы 4, содержимое по центру.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: RotationTransition(
          turns: _controller,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: const _LoaderPainter(),
          ),
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  const _LoaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Толщина и радиус пропорциональны эталонным 26 из макета.
    final scale = size.width / 26;
    final strokeWidth = 3.5 * scale;
    final rect = Offset.zero & size;
    final ring = rect.deflate(strokeWidth / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: <Color>[Color(0x00000000), Color(0x78000000)],
      ).createShader(ring);

    canvas.drawArc(ring, 0, math.pi * 2, false, paint);
  }

  @override
  bool shouldRepaint(_LoaderPainter oldDelegate) => false;
}
