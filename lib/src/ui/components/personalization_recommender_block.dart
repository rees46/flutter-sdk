import 'package:flutter/widgets.dart';

import '../personalization_icons.dart';
import 'personalization_button.dart';
import 'personalization_dots.dart';
import 'personalization_product.dart';
import 'personalization_product_card.dart';
import 'personalization_product_image.dart';
import 'personalization_products_list.dart';
import 'personalization_title.dart';

/// Блок рекомендаций: заголовок, товары, у карусели — точки.
///
/// Источник: Figma Mobile SDK UI Kit, секция Card — Recommender/Carousel (90:655),
/// Recommender/Grid (126:1944), Recommender/List (126:2551).
/// У карусели заголовок с кнопкой «Show all» и точки под лентой, шаг блока 16;
/// у плитки и списка только заголовок, шаг 12.
///
/// Собран из [PersonalizationTitle], [PersonalizationButton],
/// [PersonalizationProductsList], [PersonalizationDots].
class PersonalizationRecommenderBlock extends StatefulWidget {
  const PersonalizationRecommenderBlock({
    super.key,
    this.layout = PersonalizationProductsLayout.carousel,
    required this.title,
    this.showAllText,
    this.onShowAll,
    this.showDots = true,
    required this.products,
    this.imageAspect = PersonalizationProductImageAspect.square,
    this.onProductAction,
    this.iconBuilder,
  });

  final PersonalizationProductsLayout layout;
  final String title;

  /// Подпись кнопки «показать все» у карусели. `null` — без кнопки.
  final String? showAllText;
  final VoidCallback? onShowAll;

  /// У карусели точки под лентой; выключаются, как в макете (showDots).
  final bool showDots;
  final List<PersonalizationProduct> products;

  /// Пропорция картинок карточек, см. [PersonalizationProductCard.imageAspect].
  final PersonalizationProductImageAspect imageAspect;
  final ValueChanged<PersonalizationProduct>? onProductAction;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )? iconBuilder;

  @override
  State<PersonalizationRecommenderBlock> createState() => _PersonalizationRecommenderBlockState();
}

class _PersonalizationRecommenderBlockState extends State<PersonalizationRecommenderBlock> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final carousel = widget.layout == PersonalizationProductsLayout.carousel;
    final double gap = carousel ? 16 : 12;
    final bool showAll = carousel && widget.showAllText != null && widget.showAllText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PersonalizationTitle(
          title: widget.title,
          trailing: showAll
              ? PersonalizationButton(
                  label: widget.showAllText,
                  size: PersonalizationButtonSize.sm,
                  view: PersonalizationButtonView.ghost,
                  iconEnd: PersonalizationIcons.angleLargeRight,
                  iconBuilder: widget.iconBuilder,
                  onPressed: widget.onShowAll,
                )
              : null,
        ),
        SizedBox(height: gap),
        PersonalizationProductsList(
          layout: widget.layout,
          products: widget.products,
          imageAspect: widget.imageAspect,
          onProductAction: widget.onProductAction,
          onFirstVisibleChanged: carousel ? (int index) => setState(() => _page = index) : null,
          iconBuilder: widget.iconBuilder,
        ),
        if (carousel && widget.showDots) ...<Widget>[
          SizedBox(height: gap),
          PersonalizationDots(count: widget.products.length, selectedIndex: _page),
        ],
      ],
    );
  }
}
