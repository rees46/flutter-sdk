import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../personalization_colors.dart';
import '../personalization_theme.dart';
import 'personalization_favorites_badge.dart';
import 'personalization_story_shimmer.dart';

/// Состояние обложки сторис.
///
/// В макете у Story/Cover четыре состояния: Default, Pinned, Viewed, Skeleton. Pinned
/// здесь не состояние, а флаг [PersonalizationStoryCover.pinned]: в данных «закреплена»
/// и «просмотрена» независимы, и закреплённая сторис остаётся со звездой и после
/// просмотра — так и в прежних сторис SDK. Default — [unviewed].
enum PersonalizationStoryCoverState { unviewed, viewed, skeleton }

/// Обложка сторис: круглая картинка в кольце.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент Story/Cover,
/// сегменты кольца — Progress/Circular.
///
/// Круг 88. Кольцо — обводка 4 внутрь; картинка — круг 76 с отступом 6, то есть между
/// ними зазор 2. Цвет кольца: Button/Primary у непросмотренной, Semantic/Warning у
/// закреплённой — всегда, и после просмотра, Semantic/Neutral Subtle у просмотренной
/// незакреплённой. Закреплённой в правом нижнем углу (x62, y62) — метка Favorites 24:
/// звезда на Semantic/Warning, тоже всегда. У заглушки кольцо и картинка переливаются
/// градиентом (см. [PersonalizationStoryShimmer]).
///
/// Сегменты: при [segments] > 1 кольцо делится на столько дуг с небольшими зазорами —
/// по дуге на слайд. Дуга i горит — Button/Primary Disabled (Brand/Primary 65%), — если
/// слайд i просмотрен (его номер есть в [seenSegments]), остальные в цвете состояния.
/// Просмотренная сторис рисуется сплошным кольцом без дуг и зазоров: незакреплённая —
/// Neutral Subtle, как состояние Viewed в макете, закреплённая — Warning. Правило
/// цветов — [ringColors].
class PersonalizationStoryCover extends StatelessWidget {
  const PersonalizationStoryCover({
    super.key,
    this.image,
    this.state = PersonalizationStoryCoverState.unviewed,
    this.pinned = false,
    this.segments = 0,
    this.seenSegments = const <int>{},
    this.iconBuilder,
  });

  /// Картинку даёт хост — кит не тянет сеть.
  final ImageProvider? image;
  final PersonalizationStoryCoverState state;

  /// Закреплена магазином: кольцо Semantic/Warning и звезда — и после просмотра.
  final bool pinned;

  /// На сколько дуг поделить кольцо; 0 и 1 — сплошное.
  final int segments;

  /// Номера просмотренных слайдов — горящие дуги.
  final Set<int> seenSegments;

  /// Как нарисовать звезду метки закреплённой: пакет не рисует SVG сам.
  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  static const double size = 88;
  static const double _ring = 4;

  /// Цвета дуг кольца по порядку; одна — кольцо сплошное.
  ///
  /// - просмотренная незакреплённая — одно Neutral Subtle;
  /// - просмотренная закреплённая — одно Warning, без горящих дуг;
  /// - иначе цвет состояния (Warning у закреплённой, Button/Primary у остальных), а при
  ///   [segments] > 1 дуга i — Button/Primary Disabled, если слайд i в [seen].
  static List<Color> ringColors(
    PersonalizationColors colors, {
    required PersonalizationStoryCoverState state,
    bool pinned = false,
    int segments = 0,
    Set<int> seen = const <int>{},
  }) {
    final viewed = state == PersonalizationStoryCoverState.viewed;
    if (viewed && !pinned) return <Color>[colors.neutralSubtle];
    final stateColor = pinned ? colors.semanticWarning : colors.buttonPrimary;
    if (viewed || segments <= 1) return <Color>[stateColor];
    return <Color>[
      for (int i = 0; i < segments; i++)
        seen.contains(i) ? colors.buttonPrimaryDisabled : stateColor,
    ];
  }

  static const double _imageInset = 6;
  static const double _badgeOffset = 62;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;

    if (state == PersonalizationStoryCoverState.skeleton) {
      return PersonalizationStoryShimmer(
        builder: (context, gradient) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              colors: const <Color>[],
              gradient: gradient,
              segments: 1,
            ),
            child: Padding(
              padding: const EdgeInsets.all(_imageInset),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final ring = ringColors(
      colors,
      state: state,
      pinned: pinned,
      segments: segments,
      seen: seenSegments,
    );

    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(colors: ring, segments: ring.length),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(_imageInset),
              child: ClipOval(
                child: ColoredBox(
                  // Заглушка до загрузки — Neutral 50, как у картинки товара.
                  color: colors.neutral50,
                  child: image == null
                      ? null
                      : Image(image: image!, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          if (pinned)
            Positioned(
              left: _badgeOffset,
              top: _badgeOffset,
              child: PersonalizationFavoritesBadge(iconBuilder: iconBuilder),
            ),
        ],
      ),
    );
  }
}

/// Кольцо обложки: обводка 4 внутрь круга, сплошная или дугами с зазорами.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.colors,
    required this.segments,
    this.gradient,
  });

  /// Цвет каждой дуги; игнорируется, если задан [gradient].
  final List<Color> colors;
  final int segments;
  final Gradient? gradient;

  /// Зазор между дугами по средней линии кольца.
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = PersonalizationStoryCover._ring;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final shader = gradient?.createShader(Offset.zero & size);

    if (segments <= 1) {
      if (shader != null) {
        paint.shader = shader;
      } else {
        paint.color = colors.first;
      }
      canvas.drawOval(rect, paint);
      return;
    }

    final gapAngle = _gap / (rect.width / 2);
    final sweep = (math.pi * 2 - gapAngle * segments) / segments;
    for (int i = 0; i < segments; i++) {
      if (shader != null) {
        paint.shader = shader;
      } else {
        paint.color = colors[i];
      }
      // Первая дуга начинается сверху, после половины зазора.
      final start = -math.pi / 2 + gapAngle / 2 + i * (sweep + gapAngle);
      canvas.drawArc(rect, start, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.gradient != gradient ||
      !_sameColors(oldDelegate.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
