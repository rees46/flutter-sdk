import 'dart:async';

import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';

/// Вид таймера: одной плашкой или по плашке на единицу.
enum PersonalizationStoryTimerView { merged, separate }

/// Обратный отсчёт до [endTime]: дни, часы, минуты, секунды.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент Timer на
/// слайдах Action.
///
/// Каждая единица — число SemiBold 36 Text/Primary и подпись Regular 20 Text/Secondary с
/// шагом 2 по базовой линии. merged — одна плашка со скруглением 12, полями 8/12 и шагом
/// 12 между единицами, заливка Neutral/Neutral 100; separate — четыре плашки со
/// скруглением 8, полями 8/12 и шагом 8, каждая тянется на равную долю ширины. Часы,
/// минуты и секунды — двумя цифрами.
///
/// Тикает раз в секунду и останавливается на нуле, тогда же зовёт [onFinished]. В данных
/// сторис таймера нет: время конца даёт хост.
class PersonalizationStoryTimer extends StatefulWidget {
  const PersonalizationStoryTimer({
    super.key,
    required this.endTime,
    this.view = PersonalizationStoryTimerView.merged,
    this.daysLabel = 'd',
    this.hoursLabel = 'h',
    this.minutesLabel = 'm',
    this.secondsLabel = 's',
    this.onFinished,
  });

  final DateTime endTime;
  final PersonalizationStoryTimerView view;
  final String daysLabel;
  final String hoursLabel;
  final String minutesLabel;
  final String secondsLabel;

  /// Отсчёт дошёл до нуля.
  final VoidCallback? onFinished;

  /// Остаток, разложенный на единицы: `(дни, часы, минуты, секунды)` строками, как их
  /// показывает таймер. Отрицательный остаток — нули.
  static (String, String, String, String) format(Duration remaining) {
    final total = remaining.isNegative ? 0 : remaining.inSeconds;
    String two(int value) => value.toString().padLeft(2, '0');
    return (
      '${total ~/ Duration.secondsPerDay}',
      two(total % Duration.secondsPerDay ~/ Duration.secondsPerHour),
      two(total % Duration.secondsPerHour ~/ Duration.secondsPerMinute),
      two(total % Duration.secondsPerMinute),
    );
  }

  @override
  State<PersonalizationStoryTimer> createState() =>
      _PersonalizationStoryTimerState();
}

class _PersonalizationStoryTimerState extends State<PersonalizationStoryTimer> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(PersonalizationStoryTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTime != widget.endTime) _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _ticker?.cancel();
    _remaining = _left();
    if (_remaining <= Duration.zero) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Duration _left() {
    final left = widget.endTime.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _tick() {
    final left = _left();
    setState(() => _remaining = left);
    if (left <= Duration.zero) {
      _ticker?.cancel();
      _ticker = null;
      widget.onFinished?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final (days, hours, minutes, seconds) = PersonalizationStoryTimer.format(
      _remaining,
    );

    TextStyle style(double size, double height, FontWeight weight, Color c) =>
        TextStyle(
          fontSize: size,
          height: height / size,
          fontWeight: weight,
          letterSpacing: 0,
          fontFamily: theme.fontFamily.familyFor(weight),
          package: theme.fontFamily.package,
          color: c,
        );

    Widget unit(String value, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(value, style: style(36, 44, FontWeight.w600, colors.textPrimary)),
        const SizedBox(width: 2),
        Text(
          label,
          style: style(20, 28, FontWeight.w400, colors.textSecondary),
        ),
      ],
    );

    final units = <Widget>[
      unit(days, widget.daysLabel),
      unit(hours, widget.hoursLabel),
      unit(minutes, widget.minutesLabel),
      unit(seconds, widget.secondsLabel),
    ];

    const padding = EdgeInsets.symmetric(vertical: 8, horizontal: 12);
    switch (widget.view) {
      case PersonalizationStoryTimerView.merged:
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colors.neutral100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _fit(
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                for (int i = 0; i < units.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 12),
                  units[i],
                ],
              ],
            ),
          ),
        );
      case PersonalizationStoryTimerView.separate:
        return Row(
          children: <Widget>[
            for (int i = 0; i < units.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    color: colors.neutral100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _fit(units[i]),
                ),
              ),
            ],
          ],
        );
    }
  }

  // По центру плашки; не влезает по ширине — ужимается целиком, а не переносится. Высота
  // по содержимому: FittedBox без Center растянул бы плашку по пропорции.
  Widget _fit(Widget child) => Center(
    heightFactor: 1,
    child: FittedBox(fit: BoxFit.scaleDown, child: child),
  );
}
