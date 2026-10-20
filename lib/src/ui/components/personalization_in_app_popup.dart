import 'package:flutter/widgets.dart';

import '../personalization_elevation.dart';
import '../personalization_icons.dart';
import '../personalization_radius.dart';
import '../personalization_spacing.dart';
import '../personalization_theme.dart';
import '../personalization_typography.dart';
import 'personalization_button.dart';

/// Вид попапа: чем занято место над текстом.
enum PersonalizationInAppPopupView { image, imageBackground, text, icon }

/// Модалка карточкой или во весь экран — от этого зависят метрики.
enum PersonalizationInAppPopupPresentation { modal, fullscreen }

/// Инап-попап: карточка с картинкой, заголовком, текстом и кнопками.
///
/// Источник: Figma Mobile SDK UI Kit, страница InAppPopup / Modal (1:33),
/// компонент-сеты In App Popup/Modal (469:2767) и In App Popup/Fullscreen
/// (469:2835). У обоих четыре вида: картинка сверху, картинка фоном, только
/// текст, иконка.
///
/// Позицию на экране (верх/центр/низ/во весь экран) виджет не выбирает — это
/// дело того, кто его показывает; здесь только [presentation], от которой
/// зависят метрики: у модалки скругление 24 и отступы 20, у полноэкранной
/// скруглений нет и отступы 24, а кегли на ступень крупнее.
///
/// Крестик стоит **всегда** и принадлежит самому попапу, а не контейнеру
/// картинки: в макете виды «только текст» и «иконка» картинки не имеют, но
/// крестик у них нарисован. Он круглый (компонент Close: кнопка MD с радиусом
/// Rounded) и во всех видах лежит поверх содержимого в правом верхнем углу, на
/// отступе попапа. Над фотографией макет рисует его в тёмном варианте (белая
/// иконка на белой подложке 5%), но на светлом фото — а фото товара почти всегда на
/// белом — такой крестик пропадает. Поэтому крестик везде обычный вторичный и лежит
/// на круге цвета карточки: на любом фото виден либо круг, либо иконка. Текстовая
/// кнопка
/// закрытия ([closeText]) в макете не нарисована — её даёт админка отдельным
/// тумблером рядом с кнопкой действия, поэтому она здесь вторичной кнопкой под
/// основной, на шаге 12 у модалки и 16 у полноэкранного. Пустой текст — кнопки
/// нет, остаётся один крестик.
///
/// Поля и зазор между блоками — семантические отступы Padding/Gap Modal (20) и
/// Padding/Gap Full Screen (24), скругление модалки — радиус Modal, фон —
/// Background/Card. У модалки тень Elevation 3 цветом Shadow/Heavy темы, у
/// полноэкранного тени нет.
///
/// Высоту задаёт тот, кто показывает. Ограничена — картинка и текст делят её как в
/// макете; не ограничена (попап в прокрутке или колонке) — попап берёт высоту по
/// содержимому: картинка сверху в пропорции [imageAspectRatio] (без неё 16:10),
/// картинка фоном — вся карточка 4:5.
///
/// Картинка сверху показывается целиком: по содержимому — в своей пропорции
/// ([imageAspectRatio]), при заданной высоте — вписана в оставшееся место, поля
/// цвета карточки. Фото товара почти всегда на белом, и обрезка срезала бы сам товар.
/// Картинка фоном заполняет попап и обрезается — на то она и фон.
///
/// Полноэкранный учитывает безопасные зоны: крестик, текст и кнопки остаются внутри,
/// а картинка сверху начинается под строкой состояния — иконки той лежат на
/// карточке, а не на светлом фото, где их не видно.
///
/// Без [iconBuilder] крестик рисуется самим пакетом, так что попап можно показать и
/// без библиотеки SVG; SDK так и показывает попапы с сервера.
class PersonalizationInAppPopup extends StatelessWidget {
  const PersonalizationInAppPopup({
    super.key,
    this.view = PersonalizationInAppPopupView.image,
    this.presentation = PersonalizationInAppPopupPresentation.modal,
    this.title,
    this.text,
    this.actionText,
    this.closeText,
    this.image,
    this.imageAspectRatio,
    this.icon,
    this.iconBuilder,
    this.onAction,
    this.onClose,
  });

  final PersonalizationInAppPopupView view;
  final PersonalizationInAppPopupPresentation presentation;

  final String? title;
  final String? text;

  /// Подпись кнопки действия. Пусто — кнопки нет.
  final String? actionText;

  /// Подпись кнопки закрытия. Пусто — остаётся только крестик.
  final String? closeText;

  /// Картинку даёт хост — кит не тянет сеть.
  final ImageProvider? image;

  /// Ширина к высоте картинки сверху, когда высоту попап берёт по содержимому. Дайте
  /// пропорцию самой картинки — она войдёт целиком; без неё 16:10, и картинка другой
  /// формы обрезается.
  final double? imageAspectRatio;

  /// Иконка вида [PersonalizationInAppPopupView.icon].
  final Widget? icon;

  /// Как нарисовать иконку крестика: пакет не рисует SVG сам.
  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  final VoidCallback? onAction;
  final VoidCallback? onClose;

  bool get _modal =>
      presentation == PersonalizationInAppPopupPresentation.modal;

  bool get _overImage => view == PersonalizationInAppPopupView.imageBackground;

  bool get _centred =>
      view == PersonalizationInAppPopupView.text ||
      view == PersonalizationInAppPopupView.icon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _build(context, hug: !constraints.hasBoundedHeight),
  );

  Widget _build(BuildContext context, {required bool hug}) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final pad = _modal
        ? PersonalizationSpacing.paddingModal
        : PersonalizationSpacing.paddingFullScreen;
    final gapSection = _modal
        ? PersonalizationSpacing.gapModal
        : PersonalizationSpacing.gapFullScreen;
    // Полноэкранный лежит под строкой состояния и индикатором «Домой»: фон и фото
    // уходят под них, всё, что нажимают и читают, — нет.
    final insets = _modal ? EdgeInsets.zero : MediaQuery.paddingOf(context);
    final inner = EdgeInsets.fromLTRB(
      pad + insets.left,
      pad + insets.top,
      pad + insets.right,
      pad + insets.bottom,
    );

    final surface = colors.backgroundCard;
    final radius = _modal
        ? BorderRadius.circular(PersonalizationRadius.modal)
        : BorderRadius.zero;

    Widget content;
    switch (view) {
      case PersonalizationInAppPopupView.image:
        final card = Container(
          color: surface,
          padding: inner.copyWith(top: pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _textBlock(context),
              SizedBox(
                height: _modal
                    ? PersonalizationSpacing.xl
                    : PersonalizationSpacing.xl3,
              ),
              _buttons(context),
            ],
          ),
        );
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: hug ? MainAxisSize.min : MainAxisSize.max,
          children: <Widget>[
            // Картинка забирает всё, что остаётся над карточкой с текстом; по
            // содержимому — свою пропорцию.
            if (hug)
              AspectRatio(
                aspectRatio: imageAspectRatio ?? 16 / 10,
                child: _image(BoxFit.contain),
              )
            else
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: insets.top),
                  child: _image(BoxFit.contain),
                ),
              ),
            card,
          ],
        );

      case PersonalizationInAppPopupView.imageBackground:
        final stack = Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _image(BoxFit.cover),
            Padding(
              padding: inner,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Текст прижат к низу, над кнопками.
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: _textBlock(context),
                    ),
                  ),
                  SizedBox(height: gapSection),
                  _buttons(context),
                ],
              ),
            ),
          ],
        );
        content = hug ? AspectRatio(aspectRatio: 4 / 5, child: stack) : stack;

      case PersonalizationInAppPopupView.text:
      case PersonalizationInAppPopupView.icon:
        final centre = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (view == PersonalizationInAppPopupView.icon &&
                icon != null) ...<Widget>[
              Center(
                child: SizedBox(
                  width: _modal ? 100 : 120,
                  height: _modal ? 100 : 120,
                  child: icon,
                ),
              ),
              const SizedBox(height: PersonalizationSpacing.xl3),
            ],
            _textBlock(context),
          ],
        );
        content = Padding(
          padding: inner,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: hug ? MainAxisSize.min : MainAxisSize.max,
            children: <Widget>[
              // По содержимому текст начинается под крестиком, а не рядом с ним.
              if (hug) ...<Widget>[
                const SizedBox(height: _closeSize),
                SizedBox(height: gapSection),
                centre,
              ] else
                Expanded(child: Center(child: centre)),
              SizedBox(height: gapSection),
              _buttons(context),
            ],
          ),
        );
    }

    // Тень снаружи карточки, поэтому она на обёртке, а не под ClipRRect — обрезка
    // срезала бы её. Цвет берётся из темы: в тёмной схеме Shadow/Heavy плотнее.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: _modal
            ? <BoxShadow>[
                for (final shadow in PersonalizationElevation.e3)
                  shadow.copyWith(color: colors.shadowHeavy),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          color: surface,
          child: Stack(
            children: <Widget>[
              // По содержимому размер попапа задаёт само содержимое, иначе — тот,
              // кто показывает.
              if (hug) content else Positioned.fill(child: content),
              // Крестик всегда на месте — у видов без картинки тоже, накладкой
              // поверх содержимого.
              Positioned(
                top: pad + insets.top,
                right: pad + insets.right,
                child: _closeIcon(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(BoxFit fit) =>
      image == null ? const SizedBox.shrink() : Image(image: image!, fit: fit);

  Widget _textBlock(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    final titleStyle = _modal
        ? PersonalizationTypography.xl3Emphasized
        : PersonalizationTypography.xl4Emphasized;
    final textStyle = _modal
        ? PersonalizationTypography.lgDefault
        : PersonalizationTypography.xl2Default;
    final align = _centred ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if ((title ?? '').isNotEmpty)
          Text(
            title!,
            textAlign: align,
            style: titleStyle.copyWith(
              color: _overImage ? colors.textLightPrimary : colors.textPrimary,
            ),
          ),
        if ((title ?? '').isNotEmpty && (text ?? '').isNotEmpty)
          const SizedBox(height: PersonalizationSpacing.md),
        if ((text ?? '').isNotEmpty)
          Text(
            text!,
            textAlign: align,
            style: textStyle.copyWith(
              color: _overImage
                  ? colors.textLightSecondary
                  : colors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buttons(BuildContext context) {
    final action = (actionText ?? '').isNotEmpty;
    final close = (closeText ?? '').isNotEmpty;
    if (!action && !close) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (action)
          PersonalizationButton(
            label: actionText,
            onPressed: onAction,
            iconBuilder: iconBuilder,
          ),
        if (action && close)
          SizedBox(
            height: _modal
                ? PersonalizationSpacing.lg
                : PersonalizationSpacing.xl,
          ),
        if (close)
          PersonalizationButton(
            label: closeText,
            view: PersonalizationButtonView.secondary,
            onDark: _overImage,
            onPressed: onClose,
            iconBuilder: iconBuilder,
          ),
      ],
    );
  }

  // Круг цвета карточки под полупрозрачной вторичной кнопкой: крестик виден на любом
  // фото, в отличие от тёмного варианта из макета (см. описание класса). Над самой
  // карточкой круг сливается с ней.
  Widget _closeIcon(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: PersonalizationTheme.of(context).colors.backgroundCard,
      shape: BoxShape.circle,
    ),
    child: PersonalizationButton(
      size: PersonalizationButtonSize.md,
      view: PersonalizationButtonView.secondary,
      rounded: true,
      iconStart: PersonalizationIcons.crossLarge,
      iconBuilder: iconBuilder ?? _crossIcon,
      onPressed: onClose,
    ),
  );

  /// Сторона кнопки-крестика: иконка MD 24 и по 8 с каждой стороны.
  static const double _closeSize = 40;

  static Widget _crossIcon(
    BuildContext context,
    String asset,
    double size,
    Color color,
  ) => CustomPaint(size: Size.square(size), painter: _CrossPainter(color));
}

/// Иконка cross-large без SVG: два штриха 2/32 от 6/32 до 26/32, концы скруглены.
class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 32;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2 * unit
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        Offset(6 * unit, 6 * unit),
        Offset(26 * unit, 26 * unit),
        paint,
      )
      ..drawLine(
        Offset(26 * unit, 6 * unit),
        Offset(6 * unit, 26 * unit),
        paint,
      );
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => oldDelegate.color != color;
}
