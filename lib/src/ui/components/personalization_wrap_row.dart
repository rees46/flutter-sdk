import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Два ребёнка в строку, а когда вместе не влезают — второй переносится под первый.
/// Нужен list-карточке товара: в узкой колонке (экран 360 dp, крупный системный шрифт)
/// цена с бейджем скидки и кнопка в строку не помещаются. Он же держит цену со старой
/// ценой у карточек колонкой: длинные цены («799 990 ₽» и «1 574 990 ₽») в колонку
/// плитки рядом не помещаются.
///
/// В строке дети выровнены по центру по вертикали (с [alignBottom] — по низу), второй
/// стоит через [horizontalGap] после первого, а с [pinEnd] — у правого края (ряд тогда
/// занимает всю ширину). После переноса второй лежит под первым через [verticalGap]
/// (с [wrapAbove] — над ним): у левого края, а с [pinEnd] — у правого. Ребёнок шире
/// ряда ужимается до него. `Wrap` не подходит: одиночного ребёнка
/// в строке он ставит к началу, а кнопка должна остаться справа.
///
/// Внутренний: из барреля не экспортируется.
class PersonalizationWrapRow extends MultiChildRenderObjectWidget {
  const PersonalizationWrapRow({
    super.key,
    required this.horizontalGap,
    required this.verticalGap,
    this.pinEnd = false,
    this.wrapAbove = false,
    this.alignBottom = false,
    super.children,
  });

  final double horizontalGap;
  final double verticalGap;
  final bool pinEnd;
  final bool wrapAbove;
  final bool alignBottom;

  @override
  RenderPersonalizationWrapRow createRenderObject(BuildContext context) =>
      RenderPersonalizationWrapRow(
        horizontalGap: horizontalGap,
        verticalGap: verticalGap,
        pinEnd: pinEnd,
        wrapAbove: wrapAbove,
        alignBottom: alignBottom,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPersonalizationWrapRow renderObject,
  ) {
    renderObject
      ..horizontalGap = horizontalGap
      ..verticalGap = verticalGap
      ..pinEnd = pinEnd
      ..wrapAbove = wrapAbove
      ..alignBottom = alignBottom;
  }
}

class _WrapRowParentData extends ContainerBoxParentData<RenderBox> {}

class RenderPersonalizationWrapRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _WrapRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _WrapRowParentData> {
  RenderPersonalizationWrapRow({
    required double horizontalGap,
    required double verticalGap,
    required bool pinEnd,
    bool wrapAbove = false,
    bool alignBottom = false,
  }) : _horizontalGap = horizontalGap,
       _verticalGap = verticalGap,
       _pinEnd = pinEnd,
       _wrapAbove = wrapAbove,
       _alignBottom = alignBottom;

  double _horizontalGap;
  set horizontalGap(double value) {
    if (value == _horizontalGap) return;
    _horizontalGap = value;
    markNeedsLayout();
  }

  double _verticalGap;
  set verticalGap(double value) {
    if (value == _verticalGap) return;
    _verticalGap = value;
    markNeedsLayout();
  }

  bool _pinEnd;
  set pinEnd(bool value) {
    if (value == _pinEnd) return;
    _pinEnd = value;
    markNeedsLayout();
  }

  bool _wrapAbove;
  set wrapAbove(bool value) {
    if (value == _wrapAbove) return;
    _wrapAbove = value;
    markNeedsLayout();
  }

  bool _alignBottom;
  set alignBottom(bool value) {
    if (value == _alignBottom) return;
    _alignBottom = value;
    markNeedsLayout();
  }

  /// Перенесён ли второй ребёнок по последней раскладке.
  bool get isWrapped => _wrapped;
  bool _wrapped = false;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _WrapRowParentData) {
      child.parentData = _WrapRowParentData();
    }
  }

  List<RenderBox> get _children => getChildrenAsList();

  bool _wraps(double first, double second, double width) =>
      first + _horizontalGap + second > width;

  @override
  double computeMinIntrinsicWidth(double height) => _children.fold(
    0,
    (double widest, RenderBox child) =>
        math.max(widest, child.getMinIntrinsicWidth(height)),
  );

  @override
  double computeMaxIntrinsicWidth(double height) {
    final List<RenderBox> children = _children;
    final double sum = children.fold(
      0,
      (double total, RenderBox child) =>
          total + child.getMaxIntrinsicWidth(height),
    );
    return children.length < 2 ? sum : sum + _horizontalGap;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _heightFor(
    width,
    (RenderBox child, double w) => child.getMinIntrinsicHeight(w),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _heightFor(
    width,
    (RenderBox child, double w) => child.getMaxIntrinsicHeight(w),
  );

  double _heightFor(double width, double Function(RenderBox, double) heightOf) {
    final List<RenderBox> children = _children;
    if (children.isEmpty) return 0;
    final RenderBox first = children.first;
    if (children.length == 1) return heightOf(first, width);
    final RenderBox second = children[1];
    final double firstWidth = math.min(
      first.getMaxIntrinsicWidth(double.infinity),
      width,
    );
    final double secondWidth = math.min(
      second.getMaxIntrinsicWidth(double.infinity),
      width,
    );
    if (_wraps(firstWidth, secondWidth, width)) {
      return heightOf(first, width) + _verticalGap + heightOf(second, width);
    }
    return math.max(heightOf(first, firstWidth), heightOf(second, secondWidth));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final BoxConstraints childConstraints = BoxConstraints(
      maxWidth: constraints.maxWidth,
    );
    final List<Size> sizes = _children
        .map((RenderBox child) => child.getDryLayout(childConstraints))
        .toList();
    return _place(constraints, sizes).size;
  }

  @override
  void performLayout() {
    final BoxConstraints childConstraints = BoxConstraints(
      maxWidth: constraints.maxWidth,
    );
    final List<RenderBox> children = _children;
    for (final RenderBox child in children) {
      child.layout(childConstraints, parentUsesSize: true);
    }
    final _Placement placement = _place(
      constraints,
      children.map((RenderBox child) => child.size).toList(),
    );
    _wrapped = placement.wrapped;
    for (int i = 0; i < children.length; i++) {
      (children[i].parentData! as _WrapRowParentData).offset =
          placement.offsets[i];
    }
    size = placement.size;
  }

  _Placement _place(BoxConstraints constraints, List<Size> sizes) {
    if (sizes.isEmpty) {
      return _Placement(constraints.smallest, const <Offset>[], false);
    }
    final Size first = sizes.first;
    final bool pin = _pinEnd && constraints.hasBoundedWidth;
    if (sizes.length == 1) {
      final double width = pin ? constraints.maxWidth : first.width;
      return _Placement(
        constraints.constrain(Size(width, first.height)),
        const <Offset>[Offset.zero],
        false,
      );
    }
    final Size second = sizes[1];
    final bool wrapped = _wraps(
      first.width,
      second.width,
      constraints.maxWidth,
    );
    final double contentWidth = wrapped
        ? math.max(first.width, second.width)
        : first.width + _horizontalGap + second.width;
    final double height = wrapped
        ? first.height + _verticalGap + second.height
        : math.max(first.height, second.height);
    final Size size = constraints.constrain(
      Size(pin ? constraints.maxWidth : contentWidth, height),
    );
    if (wrapped) {
      final double x = _pinEnd ? size.width - second.width : 0;
      return _Placement(size, <Offset>[
        Offset(0, _wrapAbove ? second.height + _verticalGap : 0),
        Offset(x, _wrapAbove ? 0 : first.height + _verticalGap),
      ], true);
    }
    final double secondX = _pinEnd
        ? size.width - second.width
        : first.width + _horizontalGap;
    return _Placement(size, <Offset>[
      Offset(0, _inLine(height, first.height)),
      Offset(secondX, _inLine(height, second.height)),
    ], false);
  }

  double _inLine(double lineHeight, double height) =>
      _alignBottom ? lineHeight - height : (lineHeight - height) / 2;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

class _Placement {
  const _Placement(this.size, this.offsets, this.wrapped);

  final Size size;
  final List<Offset> offsets;
  final bool wrapped;
}
