import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'personalization_code128.dart';

/// Штрихкод Code 128.
///
/// Источник: Figma Mobile SDK UI Kit, компонент Wallet/Code (520:8886): штрихкод
/// 232×42 на белой подложке. Здесь только штрихи — подложку с полями рисует тот,
/// кто кладёт штрихкод (карта лояльности, промокод).
///
/// Ширина модуля — целое число физических пикселей: дробные модули на экране
/// размываются, и сканер читает их хуже. Во Flutter разметка в логических
/// единицах, поэтому модуль считается через плотность экрана:
/// `floor(232 * dpr / модулей) / dpr`, не меньше `1 / dpr`. Штрихкод не
/// растягивается ровно на 232, а берёт наибольший целый модуль, при котором в
/// 232 помещается, — итоговая ширина чуть меньше и зависит от длины кода. Если
/// разметка даёт меньше 232, модуль считается от доступной ширины. Штрихи
/// чёрные в любой теме: сканеру нужен контраст, а не палитра.
///
/// Строку, которую Code 128 не несёт (пустую, не ASCII), не рисует — размер
/// нулевой. Для скринридера штрихкод читается своей строкой.
class PersonalizationBarcode extends StatelessWidget {
  const PersonalizationBarcode({super.key, required this.code});

  /// Кодируемая строка — номер карты, промокод.
  final String code;

  /// Ширина, в которую штрихкод вписывается, и его высота — из макета.
  static const double preferredWidth = 232;
  static const double preferredHeight = 42;

  @override
  Widget build(BuildContext context) {
    final modules = PersonalizationCode128.encode(code);
    if (modules == null) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: code,
      child: _Bars(
        modules: modules,
        devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
      ),
    );
  }
}

/// Штрихи как RenderBox, а не CustomPaint под LayoutBuilder: модуль зависит от
/// доступной ширины, а карта лояльности меряет содержимое через IntrinsicHeight,
/// которого LayoutBuilder не поддерживает.
class _Bars extends LeafRenderObjectWidget {
  const _Bars({required this.modules, required this.devicePixelRatio});

  final List<bool> modules;
  final double devicePixelRatio;

  @override
  _RenderBars createRenderObject(BuildContext context) =>
      _RenderBars(modules, devicePixelRatio);

  @override
  void updateRenderObject(BuildContext context, _RenderBars renderObject) {
    renderObject
      ..modules = modules
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _RenderBars extends RenderBox {
  _RenderBars(this._modules, this._devicePixelRatio);

  List<bool> _modules;
  set modules(List<bool> value) {
    if (listEquals(value, _modules)) return;
    _modules = value;
    markNeedsLayout();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsLayout();
  }

  /// Модуль, найденный при последней разметке: пересчитывать его из размера при
  /// отрисовке нельзя — погрешность деления может отнять целый пиксель.
  double _module = 0;

  /// Ширина модуля в логических единицах при данной доступной ширине.
  double _moduleFor(double maxWidth) {
    final available = math.min(PersonalizationBarcode.preferredWidth, maxWidth);
    // Эпсилон — против погрешности плотности вроде 2.625: 3.9999 не должно
    // превратиться в 3.
    final pixels = (available * _devicePixelRatio / _modules.length + 1e-6)
        .floorToDouble();
    return math.max(1, pixels) / _devicePixelRatio;
  }

  Size _sizeFor(BoxConstraints constraints, double module) =>
      constraints.constrain(
        Size(_modules.length * module, PersonalizationBarcode.preferredHeight),
      );

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _sizeFor(constraints, _moduleFor(constraints.maxWidth));

  @override
  void performLayout() {
    _module = _moduleFor(constraints.maxWidth);
    size = _sizeFor(constraints, _module);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _modules.length * _moduleFor(double.infinity);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      computeMinIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      PersonalizationBarcode.preferredHeight;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      PersonalizationBarcode.preferredHeight;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final drawn = _modules.length * _module;
    // По центру, если разметка дала больше, чем занимают модули. Начало
    // прижато к физическому пикселю, иначе края всех штрихов лягут между
    // пикселями.
    final dpr = _devicePixelRatio;
    double x = offset.dx + (size.width - drawn) / 2;
    x = (x * dpr).roundToDouble() / dpr;

    // Без сглаживания: край штриха либо закрашен, либо нет — полупрозрачная
    // кромка сканеру только мешает.
    final paint = Paint()
      // Чёрный, а не токен: сканеру нужен контраст в любой теме.
      ..color = const Color(0xFF000000)
      ..isAntiAlias = false;

    int i = 0;
    while (i < _modules.length) {
      int run = 1;
      while (i + run < _modules.length && _modules[i + run] == _modules[i]) {
        run++;
      }
      if (_modules[i]) {
        canvas.drawRect(
          Rect.fromLTWH(x, offset.dy, run * _module, size.height),
          paint,
        );
      }
      x += run * _module;
      i += run;
    }
  }
}
