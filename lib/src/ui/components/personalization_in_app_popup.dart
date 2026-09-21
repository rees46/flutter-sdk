import 'package:flutter/widgets.dart';

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
/// крестик у них нарисован. Текстовая кнопка закрытия ([closeText]) в макете не
/// нарисована — её даёт админка отдельным тумблером рядом с кнопкой действия,
/// поэтому она здесь вторичной кнопкой под основной. Пустой текст — кнопки нет,
/// остаётся один крестик.
///
/// Отступ 20 у модалки и интерлиньяж 48 у полноэкранного заголовка вне шкал
/// кита — взяты из макета как есть.
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
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final pad = _modal ? 20.0 : PersonalizationSpacing.xl2;
    final gapSection = _modal ? 20.0 : PersonalizationSpacing.xl2;

    // Background/Modal, а не Card: в светлой они совпадают (белый), в тёмной у
    // модалки своя ступень. В Figma компонент привязан к Card, но значение Card
    // в ките отстало от файла (там уже белый) — ресинк цветов отдельной задачей.
    final surface = colors.backgroundModal;
    final radius = _modal
        ? BorderRadius.circular(PersonalizationRadius.xl6)
        : BorderRadius.zero;

    Widget content;
    switch (view) {
      case PersonalizationInAppPopupView.image:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Картинка забирает всё, что остаётся над карточкой с текстом.
            Expanded(child: _image()),
            Container(
              color: surface,
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _textBlock(context),
                  SizedBox(
                    height: _modal
                        ? PersonalizationSpacing.xl
                        : PersonalizationSpacing.xl2,
                  ),
                  _buttons(context),
                ],
              ),
            ),
          ],
        );

      case PersonalizationInAppPopupView.imageBackground:
        content = Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _image(),
            Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Здесь крестик не накладкой, а первой строкой: в макете он
                  // занимает свою строку, иначе заголовок заезжает под него.
                  Align(
                    alignment: Alignment.topRight,
                    child: _closeIcon(context),
                  ),
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

      case PersonalizationInAppPopupView.text:
      case PersonalizationInAppPopupView.icon:
        final centre = <Widget>[
          if (view == PersonalizationInAppPopupView.icon &&
              icon != null) ...<Widget>[
            SizedBox(
              width: _modal ? 100 : 120,
              height: _modal ? 100 : 120,
              child: icon,
            ),
            const SizedBox(height: PersonalizationSpacing.xl2),
          ],
          _textBlock(context),
        ];
        content = Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: centre,
                  ),
                ),
              ),
              SizedBox(height: gapSection),
              _buttons(context),
            ],
          ),
        );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        color: surface,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: content),
            // Крестик всегда на месте — у видов без картинки тоже. У фона-картинки
            // он уже стоит в колонке.
            if (!_overImage)
              Positioned(top: pad, right: pad, child: _closeIcon(context)),
          ],
        ),
      ),
    );
  }

  Widget _image() => image == null
      ? const SizedBox.shrink()
      : Image(image: image!, fit: BoxFit.cover);

  Widget _textBlock(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    // Полноэкранный заголовок в макете 36/48, а ступень 4XL кита — 36/52:
    // кегль с одной ступени, интерлиньяж с другой, как и в остальном файле.
    final titleStyle = _modal
        ? PersonalizationTypography.xl3Emphasized
        : PersonalizationTypography.xl4Emphasized.copyWith(height: 48 / 36);
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
        if (action && close) const SizedBox(height: PersonalizationSpacing.md),
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

  Widget _closeIcon(BuildContext context) => PersonalizationButton(
    size: PersonalizationButtonSize.md,
    view: PersonalizationButtonView.secondary,
    onDark: _overImage,
    iconStart: PersonalizationIcons.crossLarge,
    iconBuilder: iconBuilder,
    onPressed: onClose,
  );
}
