import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../popups_v3/popup_v3.dart';
import '../../popups_v3/popups_v3_api.dart';
import '../../popups_v3/popups_v3_engine.dart';
import '../personalization_theme.dart';
import 'popup_markup.dart';
import 'popup_v3_design.dart';
import 'popup_v3_elements.dart';
import 'popup_v3_grid.dart';
import 'popup_v3_texts.dart';

/// Что элементам попапа нужно от показа: документ, действия, тексты, закрытие.
class PopupV3Scope extends InheritedWidget {
  const PopupV3Scope({
    super.key,
    required this.design,
    required this.actions,
    required this.texts,
    required this.onClose,
    required this.onDismiss,
    required super.child,
  });

  final PopupV3Design design;
  final PopupV3Actions actions;
  final PopupV3Texts texts;

  /// Закрыть попап пользователем (крестик, кнопка `close`): событие `close`.
  final VoidCallback onClose;

  /// Убрать попап без события (ссылку или товар забрал хост).
  final VoidCallback onDismiss;

  PopupV3Variables get variables => design.variables;

  static PopupV3Scope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PopupV3Scope>();
    assert(scope != null, 'PopupV3Scope is missing above a popup v3 element');
    return scope!;
  }

  /// Открыть ссылку элемента: событие `click`, затем ссылка ([followLink]).
  void openLink(String url) {
    actions.event(PopupV3Event.click);
    followLink(url);
  }

  /// Ссылка без события: открыл её хост — попап уходит без `close`, как после
  /// перехода; ушла системе — остаётся.
  void followLink(String url) {
    if (actions.openLink(url)) onDismiss();
  }

  @override
  bool updateShouldNotify(PopupV3Scope oldWidget) =>
      design != oldWidget.design ||
      actions != oldWidget.actions ||
      texts != oldWidget.texts;
}

/// Фон попапа под элементом [element]: его фон, если он не прозрачный, иначе фон
/// рамки, иначе белый, как рамка по умолчанию; полупрозрачные — друг поверх друга.
Color popupV3BackgroundUnder(PopupV3Design design, PopupV3Element element) =>
    Color.alphaBlend(
      element.box.background,
      Color.alphaBlend(design.frame.background, const Color(0xffffffff)),
    );

/// Компоненты кита в элементе [element] — в теме кита по фону попапа под ним
/// ([popupV3BackgroundUnder]), а не по теме системы: попап рисуется по цветам дизайна.
/// Окна поверх приложения (тост) — не часть рамки и остаются по теме приложения.
class PopupV3KitTheme extends StatelessWidget {
  const PopupV3KitTheme({
    super.key,
    required this.element,
    required this.child,
  });

  final PopupV3Element element;
  final Widget child;

  @override
  Widget build(BuildContext context) => PersonalizationBrightness(
    brightness: PersonalizationBrightness.on(
      popupV3BackgroundUnder(PopupV3Scope.of(context).design, element),
    ),
    child: child,
  );
}

/// Насыщенность шрифта по числу CSS (100–900).
FontWeight popupV3FontWeight(double value) {
  final index = ((value / 100).round() - 1).clamp(0, 8);
  return FontWeight.values[index];
}

/// Шрифт по `fontFamily` дизайна: моноширинный и с засечками — системные по ключевому
/// слову, остальное — шрифт приложения (шрифтов приложения по имени не ищем).
String? popupV3FontFamily(String? family) {
  final name = family?.toLowerCase() ?? '';
  final ios =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  if (name.contains('mono') || name.contains('courier')) {
    return ios ? 'Menlo' : 'monospace';
  }
  if (name.contains('serif') && !name.contains('sans')) {
    return ios ? 'Georgia' : 'serif';
  }
  return null;
}

/// Стиль текста коробки [box]; поля можно перекрыть.
TextStyle popupV3TextStyle(
  PopupV3Box box, {
  double? fontSize,
  double? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  String? fontFamily,
}) => TextStyle(
  color: color ?? box.textColor,
  fontSize: fontSize ?? box.fontSize,
  fontWeight: popupV3FontWeight(fontWeight ?? box.fontWeight),
  letterSpacing: letterSpacing ?? box.letterSpacing,
  height: height ?? box.lineHeight,
  fontFamily: fontFamily ?? popupV3FontFamily(box.fontFamily),
  decoration: TextDecoration.none,
);

/// Текст с разметкой и переменными.
class PopupV3RichText extends StatelessWidget {
  const PopupV3RichText(
    this.spans, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.left,
  });

  final List<PopupMarkupSpan> spans;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) =>
      Text.rich(popupMarkupTextSpan(spans, style), textAlign: textAlign);
}

/// Попап целиком: рамка (фон, граница, радиус, поля) и сетка. Рамка не выше
/// [maxHeight]: если содержимое выше, оно прокручивается внутри неё, а рамка
/// остаётся на месте.
class PopupV3FrameView extends StatelessWidget {
  const PopupV3FrameView({
    super.key,
    required this.design,
    required this.layout,
    required this.screen,
    required this.maxWidth,
    required this.maxHeight,
  });

  final PopupV3Design design;
  final PopupV3Layout layout;

  /// Размер экрана — для `%`, `vw`, `vh` и breakpoints.
  final Size screen;

  /// Сколько места у рамки.
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final frame = design.frame;
    final metrics = frame.metrics(screen);
    final fullscreen = layout == PopupV3Layout.fullscreen;
    final width = fullscreen ? maxWidth : metrics.resolveWidth(maxWidth);
    final minHeight = fullscreen
        ? maxHeight
        : math.min(metrics.minHeight, maxHeight);
    final fixed = fullscreen
        ? null
        : metrics.height?.clamp(minHeight, maxHeight);
    final radius = fullscreen ? 0.0 : metrics.radius;
    final border = fullscreen ? 0.0 : frame.borderWidth;
    return Container(
      width: width,
      constraints: BoxConstraints(
        minHeight: fixed ?? minHeight,
        maxHeight: fixed ?? maxHeight,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: frame.background,
        borderRadius: BorderRadius.circular(radius),
        border: border > 0
            ? Border.all(color: frame.borderColor, width: border)
            : null,
      ),
      padding: EdgeInsets.all(metrics.padding),
      child: SingleChildScrollView(
        // Без перетаскивания, пока всё помещается: свайп баннера к краю закрывает его.
        physics: const ClampingScrollPhysics(),
        child: PopupV3Grid(design: design),
      ),
    );
  }
}

/// Строки документа столбиком с промежутком 8.
class PopupV3Grid extends StatelessWidget {
  const PopupV3Grid({super.key, required this.design});

  final PopupV3Design design;

  @override
  Widget build(BuildContext context) {
    final rows = design.rows;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (index, row) in rows.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: 8),
          PopupV3RowView(row: row),
        ],
      ],
    );
  }
}

/// Строка: фон цветом или картинкой и ячейки по долям.
class PopupV3RowView extends StatelessWidget {
  const PopupV3RowView({super.key, required this.row});

  final PopupV3Row row;

  @override
  Widget build(BuildContext context) {
    Widget child = PopupV3RowLayout(
      fractions: row.fractions,
      gap: row.gap,
      minHeight: row.minHeight,
      children: <Widget>[
        for (final cell in row.cells)
          PopupV3CellLayout(
            gap: row.gap,
            verticalAlign: cell.verticalAlign,
            children: <Widget>[
              for (final element in cell.elements)
                PopupV3CellSlot(
                  key: ValueKey<String>('popup-v3-${element.id}'),
                  align: element.stretch ? null : element.alignIn(cell.align),
                  verticalAlign: element.verticalAlign,
                  child: PopupV3ElementView(element: element),
                ),
            ],
          ),
      ],
    );
    final image = row.backgroundImage;
    if (row.background != null || image != null) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: row.background,
          image: image == null
              ? null
              : DecorationImage(
                  image: NetworkImage(image),
                  fit: switch (row.backgroundSize) {
                    'contain' => BoxFit.contain,
                    'auto' => BoxFit.none,
                    _ => BoxFit.cover,
                  },
                  alignment: switch (row.backgroundPosition) {
                    'top' => Alignment.topCenter,
                    'bottom' => Alignment.bottomCenter,
                    'left' => Alignment.centerLeft,
                    'right' => Alignment.centerRight,
                    _ => Alignment.center,
                  },
                  repeat: switch (row.backgroundRepeat) {
                    'repeat' => ImageRepeat.repeat,
                    'repeat-x' => ImageRepeat.repeatX,
                    'repeat-y' => ImageRepeat.repeatY,
                    _ => ImageRepeat.noRepeat,
                  },
                  onError: (error, _) =>
                      debugPrint('PersonalizationPopupsV3: row image — $error'),
                ),
        ),
        child: child,
      );
    }
    return child;
  }
}

/// Элемент: содержимое по типу из реестра в «коробке» общих стилей; у `text`, `box` и
/// `image` — ссылка на всём элементе.
class PopupV3ElementView extends StatelessWidget {
  const PopupV3ElementView({super.key, required this.element});

  final PopupV3Element element;

  @override
  Widget build(BuildContext context) {
    final builder = popupV3ElementBuilders[element.type];
    if (builder == null) return const SizedBox.shrink();
    final content = builder(context, element);
    if (content == null) return const SizedBox.shrink();
    final box = element.box;
    final shadow = box.shadow;
    Widget child = Container(
      decoration: BoxDecoration(
        color: box.background,
        borderRadius: BorderRadius.circular(box.radius),
        border: box.borderWidth > 0
            ? Border.all(color: box.borderColor, width: box.borderWidth)
            : null,
        boxShadow: shadow == null
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: shadow.color,
                  offset: Offset(0, shadow.y),
                  blurRadius: shadow.blur,
                ),
              ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: box.paddingX,
        vertical: box.paddingY,
      ),
      child: DefaultTextStyle.merge(
        style: popupV3TextStyle(box),
        child: content,
      ),
    );
    if (box.opacity < 1) child = Opacity(opacity: box.opacity, child: child);
    final scope = PopupV3Scope.of(context);
    final link = element.link(scope.variables);
    if (link != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => scope.openLink(link),
        child: child,
      );
    }
    return child;
  }
}
