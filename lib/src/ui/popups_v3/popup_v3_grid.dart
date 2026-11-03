import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'popup_v3_design.dart';

/// Строка сетки попапа: ячейки по долям ширины с промежутком [gap], высота — самая
/// высокая ячейка, но не меньше [minHeight]; каждая ячейка растягивается на высоту
/// строки. Содержимое за краями строки обрезается (`overflow: hidden`).
class PopupV3RowLayout extends MultiChildRenderObjectWidget {
  const PopupV3RowLayout({
    super.key,
    required this.fractions,
    required this.gap,
    required this.minHeight,
    required super.children,
  });

  final List<double> fractions;
  final double gap;
  final double minHeight;

  @override
  RenderPopupV3Row createRenderObject(BuildContext context) =>
      RenderPopupV3Row(fractions: fractions, gap: gap, minHeight: minHeight);

  @override
  void updateRenderObject(BuildContext context, RenderPopupV3Row renderObject) {
    renderObject
      ..fractions = fractions
      ..gap = gap
      ..minHeight = minHeight;
  }
}

class PopupV3RowParentData extends ContainerBoxParentData<RenderBox> {}

class RenderPopupV3Row extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, PopupV3RowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, PopupV3RowParentData> {
  RenderPopupV3Row({
    required List<double> fractions,
    required double gap,
    required double minHeight,
  }) : _fractions = fractions,
       _gap = gap,
       _minHeight = minHeight;

  List<double> _fractions;
  set fractions(List<double> value) {
    if (listEquals(value, _fractions)) return;
    _fractions = value;
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _minHeight;
  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! PopupV3RowParentData) {
      child.parentData = PopupV3RowParentData();
    }
  }

  List<double> _widths(double width) {
    final count = childCount;
    final available = math.max(0.0, width - _gap * math.max(0, count - 1));
    return <double>[
      for (var index = 0; index < count; index++)
        available * (index < _fractions.length ? _fractions[index] : 0),
    ];
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : constraints.minWidth;
    final widths = _widths(width);
    // Первый проход — естественная высота каждой ячейки, второй — ячейка на всю
    // высоту строки (в ней работает вертикальное выравнивание).
    var height = _minHeight;
    var child = firstChild;
    var index = 0;
    while (child != null) {
      child.layout(
        BoxConstraints(minWidth: widths[index], maxWidth: widths[index]),
        parentUsesSize: true,
      );
      height = math.max(height, child.size.height);
      child = childAfter(child);
      index++;
    }
    height = constraints.constrainHeight(height);
    child = firstChild;
    index = 0;
    var x = 0.0;
    while (child != null) {
      // Не жёсткие ограничения: с жёсткими ячейка стала бы границей перекладки, и
      // выросшее содержимое (форма опроса после оценки) не раздвинуло бы строку.
      child.layout(
        BoxConstraints(
          minWidth: widths[index],
          maxWidth: widths[index],
          minHeight: height,
        ),
        parentUsesSize: true,
      );
      (child.parentData! as PopupV3RowParentData).offset = Offset(x, 0);
      x += widths[index] + _gap;
      child = childAfter(child);
      index++;
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      defaultPaint,
      oldLayer: _clip.layer,
    );
  }

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

/// Как элемент стоит в ячейке.
class PopupV3CellSlot extends ParentDataWidget<PopupV3CellParentData> {
  const PopupV3CellSlot({
    super.key,
    required this.align,
    required this.verticalAlign,
    required super.child,
  });

  /// По горизонтали; `null` — на всю ширину ячейки.
  final PopupV3Align? align;

  /// Своя вертикаль элемента (`cellVerticalAlign`).
  final PopupV3VerticalAlign? verticalAlign;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as PopupV3CellParentData;
    if (data.align == align && data.verticalAlign == verticalAlign) return;
    data
      ..align = align
      ..verticalAlign = verticalAlign;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => PopupV3CellLayout;
}

/// Ячейка: элементы столбиком с промежутком [gap]. Ячейка выше содержимого — элементы
/// встают по [verticalAlign]; элемент со своей вертикалью отодвигается сам, как
/// `margin: auto` во flex-колонке.
class PopupV3CellLayout extends MultiChildRenderObjectWidget {
  const PopupV3CellLayout({
    super.key,
    required this.gap,
    required this.verticalAlign,
    required super.children,
  });

  final double gap;
  final PopupV3VerticalAlign verticalAlign;

  @override
  RenderPopupV3Cell createRenderObject(BuildContext context) =>
      RenderPopupV3Cell(gap: gap, verticalAlign: verticalAlign);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPopupV3Cell renderObject,
  ) {
    renderObject
      ..gap = gap
      ..verticalAlign = verticalAlign;
  }
}

class PopupV3CellParentData extends ContainerBoxParentData<RenderBox> {
  PopupV3Align? align;
  PopupV3VerticalAlign? verticalAlign;
}

class RenderPopupV3Cell extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, PopupV3CellParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, PopupV3CellParentData> {
  RenderPopupV3Cell({
    required double gap,
    required PopupV3VerticalAlign verticalAlign,
  }) : _gap = gap,
       _verticalAlign = verticalAlign;

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  PopupV3VerticalAlign _verticalAlign;
  set verticalAlign(PopupV3VerticalAlign value) {
    if (value == _verticalAlign) return;
    _verticalAlign = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! PopupV3CellParentData) {
      child.parentData = PopupV3CellParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : constraints.minWidth;
    var content = 0.0;
    var autos = 0;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as PopupV3CellParentData;
      child.layout(
        data.align == null
            ? BoxConstraints.tightFor(width: width)
            : BoxConstraints(maxWidth: width),
        parentUsesSize: true,
      );
      content += child.size.height;
      autos += switch (data.verticalAlign) {
        PopupV3VerticalAlign.center => 2,
        PopupV3VerticalAlign.bottom => 1,
        _ => 0,
      };
      child = childAfter(child);
    }
    if (childCount > 1) content += _gap * (childCount - 1);
    final height = constraints.hasBoundedHeight
        ? constraints.constrainHeight(math.max(content, constraints.minHeight))
        : math.max(content, constraints.minHeight);
    final free = math.max(0.0, height - content);
    final perAuto = autos == 0 ? 0.0 : free / autos;
    var y = autos > 0
        ? 0.0
        : switch (_verticalAlign) {
            PopupV3VerticalAlign.center => free / 2,
            PopupV3VerticalAlign.bottom => free,
            PopupV3VerticalAlign.top => 0.0,
          };
    child = firstChild;
    while (child != null) {
      final data = child.parentData! as PopupV3CellParentData;
      if (data.verticalAlign == PopupV3VerticalAlign.center ||
          data.verticalAlign == PopupV3VerticalAlign.bottom) {
        y += perAuto;
      }
      final x = switch (data.align) {
        PopupV3Align.center => (width - child.size.width) / 2,
        PopupV3Align.right => width - child.size.width,
        _ => 0.0,
      };
      data.offset = Offset(x, y);
      y += child.size.height + _gap;
      if (data.verticalAlign == PopupV3VerticalAlign.center) y += perAuto;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
