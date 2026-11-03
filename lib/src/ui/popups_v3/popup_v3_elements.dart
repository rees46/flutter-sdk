import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../popups_v3/popups_v3_api.dart';
import '../components/personalization_products_list.dart';
import '../components/personalization_toast.dart';
import '../widgets/personalization_recommender_block.dart';
import 'popup_v3_design.dart';
import 'popup_v3_forms.dart';
import 'popup_v3_view.dart';

/// Рисует содержимое элемента внутри его «коробки»; `null` — элемент не рисуется.
typedef PopupV3ElementBuilder =
    Widget? Function(BuildContext context, PopupV3Element element);

/// Реестр элементов по `type`. Нового типа (`countdown`, `wheel` …) достаточно
/// добавить сюда: документ берёт список известных типов отсюда, остальные
/// пропускает с записью в лог.
final Map<String, PopupV3ElementBuilder> popupV3ElementBuilders =
    <String, PopupV3ElementBuilder>{
      'text': _text,
      'box': _text,
      'button': (context, element) => PopupV3Button(element: element),
      'close': (context, element) => PopupV3Button(element: element),
      'image': _image,
      'emailCollector': (context, element) =>
          PopupV3EmailCollector(element: element),
      'form': (context, element) => PopupV3ProfileForm(element: element),
      'promoCode': (context, element) => PopupV3PromoCode(element: element),
      'survey': (context, element) => PopupV3Survey(element: element),
      'recommendation': _recommendation,
    };

Widget? _text(BuildContext context, PopupV3Element element) {
  final scope = PopupV3Scope.of(context);
  final spans = scope.variables.rich(element.text('message'));
  if (spans.isEmpty) return const SizedBox.shrink();
  return PopupV3RichText(
    spans,
    textAlign: element.messageAlign,
    style: popupV3TextStyle(
      element.box,
      fontSize: element.messageFontSize,
      fontWeight: element.messageFontWeight,
    ),
  );
}

/// Кнопка (`link`, `close`, `copy`) и крестик.
class PopupV3Button extends StatelessWidget {
  const PopupV3Button({super.key, required this.element});

  final PopupV3Element element;

  bool get _close => element.type == 'close';

  void _press(BuildContext context) {
    final scope = PopupV3Scope.of(context);
    switch (element.buttonAction) {
      case 'close':
        scope.onClose();
      case 'copy':
        final text = element.copyText(scope.variables);
        scope.actions.event(PopupV3Event.click);
        Clipboard.setData(ClipboardData(text: text));
        PersonalizationToast.show(context, scope.texts.copied);
      default:
        scope.actions.event(PopupV3Event.click);
        final href = element.buttonHref(scope.variables);
        if (href != null) scope.actions.openLink(href);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = PopupV3Scope.of(context);
    final box = element.box;
    final color = element.color(
      'buttonTextColor',
      _close ? '#71717a' : '#ffffff',
    );
    final fontSize = element.number('buttonFontSize', _close ? 22 : 12);
    final label = _label(scope, box, color, fontSize);
    return Semantics(
      button: true,
      label: _close ? scope.texts.close : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _press(context),
        child: Container(
          decoration: BoxDecoration(
            color: element.color(
              'buttonBgColor',
              _close ? 'transparent' : '#2563eb',
            ),
            borderRadius: BorderRadius.circular(
              element.number('buttonRadius', _close ? 999 : 0),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: element.number('buttonPaddingX', _close ? 8 : 0),
            vertical: element.number('buttonPaddingY', _close ? 2 : 0),
          ),
          child: label,
        ),
      ),
    );
  }

  Widget _label(
    PopupV3Scope scope,
    PopupV3Box box,
    Color color,
    double fontSize,
  ) {
    if (_close) {
      final size = element.closeIconSize;
      final image = element.closeImageUrl(scope.variables);
      if (image != null) {
        return SizedBox.square(
          dimension: size,
          child: Image.network(
            image,
            fit: BoxFit.contain,
            semanticLabel: element.text('imageAlt') ?? scope.texts.close,
            errorBuilder: (context, error, _) =>
                PopupV3CloseCross(size: size, color: color),
          ),
        );
      }
      // Встроенный SVG без сторонней библиотеки не нарисовать — стандартный крестик.
      if (element.closeSvg != null) {
        return PopupV3CloseCross(size: size, color: color);
      }
    }
    final text =
        element.text('buttonText') ?? (_close ? '×' : scope.texts.detail);
    return PopupV3RichText(
      scope.variables.rich(text),
      textAlign: TextAlign.center,
      style: popupV3TextStyle(box, color: color, fontSize: fontSize, height: 1),
    );
  }
}

/// Крестик: две диагонали толщиной в 1/12 размера.
class PopupV3CloseCross extends StatelessWidget {
  const PopupV3CloseCross({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CrossPainter(color));
}

class _CrossPainter extends CustomPainter {
  _CrossPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width / 12
      ..strokeCap = StrokeCap.round;
    final inset = size.width / 4;
    canvas
      ..drawLine(
        Offset(inset, inset),
        Offset(size.width - inset, size.height - inset),
        paint,
      )
      ..drawLine(
        Offset(size.width - inset, inset),
        Offset(inset, size.height - inset),
        paint,
      );
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => oldDelegate.color != color;
}

Widget? _image(BuildContext context, PopupV3Element element) {
  if (!element.showImage) return null;
  final scope = PopupV3Scope.of(context);
  final url = popupV3ImageUrl(element.text('imageUrl'), scope.variables);
  if (url == null) return null;
  final screen = MediaQuery.sizeOf(context);
  final height = element.imageHeight.resolve(screen.height);
  final ratio = height == null ? element.imageAspectRatio : null;
  Widget image = Image.network(
    url,
    width: double.infinity,
    height: height,
    fit: element.imageFit,
    semanticLabel: element.text('imageAlt') ?? scope.texts.image,
    errorBuilder: (context, error, _) => const SizedBox.shrink(),
  );
  if (ratio != null) image = AspectRatio(aspectRatio: ratio, child: image);
  return Padding(
    padding: EdgeInsets.only(
      bottom: element.number('imageMarginBottom', 0).clamp(0, 1000).toDouble(),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(element.number('imageRadius', 0)),
      child: image,
    ),
  );
}

/// Промокод: подпись, код моноширинным жирным и «Скопировать» → «Скопировано»;
/// после копирования — ссылка применения.
class PopupV3PromoCode extends StatefulWidget {
  const PopupV3PromoCode({super.key, required this.element});

  final PopupV3Element element;

  @override
  State<PopupV3PromoCode> createState() => _PopupV3PromoCodeState();
}

class _PopupV3PromoCodeState extends State<PopupV3PromoCode> {
  bool _copied = false;

  void _copy(String code) {
    final scope = PopupV3Scope.of(context);
    Clipboard.setData(ClipboardData(text: code));
    scope.actions.event(PopupV3Event.click);
    setState(() => _copied = true);
    final apply = widget.element.promoApplyHref(scope.variables);
    if (apply != null) scope.actions.openLink(apply);
  }

  @override
  Widget build(BuildContext context) {
    final element = widget.element;
    final scope = PopupV3Scope.of(context);
    final box = element.box;
    final code = element.promoCode(scope.variables);
    final align = switch (element.value('messageAlign')) {
      'left' => CrossAxisAlignment.start,
      'right' => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };
    final codeColor = element.color('promoCodeColor', '#92400e');
    final copyText = _copied
        ? (element.text('promoCopiedText') ?? scope.texts.copied)
        : (element.text('promoCopyText') ?? scope.texts.copy);
    final label = element.text('promoLabel');
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null) ...<Widget>[
          PopupV3RichText(
            scope.variables.rich(label),
            textAlign: element.messageAlign,
            style: popupV3TextStyle(
              box,
              fontSize: element.messageFontSize,
              fontWeight: element.messageFontWeight,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: element.color('promoCodeBg', '#fef3c7'),
            borderRadius: BorderRadius.circular(
              element.number('promoCodeRadius', 10),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  code,
                  style: popupV3TextStyle(
                    box,
                    color: codeColor,
                    fontSize: element.number('promoCodeFontSize', 20),
                    fontWeight: 700,
                    letterSpacing: 1,
                    fontFamily: popupV3FontFamily('monospace'),
                  ),
                ),
              ),
              if (element.promoShowCopy) ...<Widget>[
                const SizedBox(width: 10),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _copy(code),
                  child: Opacity(
                    opacity: 0.8,
                    child: PopupV3RichText(
                      scope.variables.rich(copyText),
                      style: popupV3TextStyle(
                        box,
                        color: codeColor,
                        fontSize: 11,
                        fontWeight: 500,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

Widget? _recommendation(BuildContext context, PopupV3Element element) {
  final code = element.recommenderCode;
  if (code == null) return null;
  final scope = PopupV3Scope.of(context);
  return ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 40),
    child: PersonalizationRecommenderBlock(
      code: code,
      sdk: scope.actions.sdk,
      layout: PersonalizationProductsLayout.carousel,
      // Товар — ссылка: событие `click`, как у сайта (там товары блока — ссылки).
      // Открыл его хост — попап уходит, как после перехода; открылась ссылка — остаётся.
      onProductTap: (product) {
        scope.actions.event(PopupV3Event.click);
        if (scope.actions.openProduct(product)) scope.onDismiss();
      },
    ),
  );
}
