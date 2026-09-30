import 'package:flutter/widgets.dart';

import '../personalization_icons.dart';
import '../personalization_theme.dart';
import 'personalization_button.dart';
import 'personalization_product.dart';
import 'personalization_products_list.dart';

/// Товары со слайда сторис: кнопка-переключатель внизу и карусель над ней.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), слайды Slide с товарами
/// (свёрнуто и развёрнуто).
///
/// Свёрнуто — строка высотой 64 с полями 16, по центру пилюля: кнопка SM Secondary со
/// скруглением Rounded, подпись [showText] (SemiBold 14/24) и иконка angle-up. Развёрнуто —
/// лист Background/Card: карусель кита (карточки 220, поля 16/0/16/16, шаг 16) и та же
/// строка с подписью [hideText] и иконкой angle-down. В начале строки — необязательный
/// [leading]: во вьюере это кнопка звука видео.
///
/// Раскрытие ведёт сам виджет; [onExpandedChanged] сообщает о нём — вьюер на это время
/// ставит слайд на паузу.
class PersonalizationStoryUsedProducts extends StatefulWidget {
  const PersonalizationStoryUsedProducts({
    super.key,
    required this.products,
    this.showText = 'Used products',
    this.hideText = 'Hide products',
    this.initiallyExpanded = false,
    this.onExpandedChanged,
    this.onProductTap,
    this.leading,
    this.iconBuilder,
  });

  final List<PersonalizationProduct> products;

  /// Подпись свёрнутого переключателя.
  final String showText;

  /// Подпись развёрнутого переключателя.
  final String hideText;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpandedChanged;

  /// Нажатие на карточку — открыть товар.
  final ValueChanged<PersonalizationProduct>? onProductTap;

  /// Виджет в начале строки переключателя.
  final Widget? leading;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  @override
  State<PersonalizationStoryUsedProducts> createState() =>
      _PersonalizationStoryUsedProductsState();
}

class _PersonalizationStoryUsedProductsState
    extends State<PersonalizationStoryUsedProducts> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpandedChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    final row = SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (widget.leading != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: widget.leading,
              ),
            PersonalizationButton(
              label: _expanded ? widget.hideText : widget.showText,
              size: PersonalizationButtonSize.sm,
              view: PersonalizationButtonView.secondary,
              rounded: true,
              iconEnd: _expanded
                  ? PersonalizationIcons.angleDown
                  : PersonalizationIcons.angleUp,
              iconBuilder: widget.iconBuilder,
              onPressed: _toggle,
            ),
          ],
        ),
      ),
    );

    if (!_expanded) return row;
    return ColoredBox(
      color: colors.backgroundCard,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PersonalizationProductsList(
            products: widget.products,
            carouselPadding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
            onProductTap: widget.onProductTap,
            iconBuilder: widget.iconBuilder,
          ),
          row,
        ],
      ),
    );
  }
}
