import 'package:flutter/widgets.dart';

import 'personalization_product.dart';
import 'personalization_product_card.dart';
import 'personalization_product_image.dart';

/// Раскладка каталога.
enum PersonalizationProductsLayout { carousel, grid, list }

/// Лента, плитка и список карточек товара.
///
/// Источник: Figma Mobile SDK UI Kit, секция Card — Products Carousel (203:6296)
/// и Products Grid (203:4766) в видах Grid и List.
/// Карусель — карточки carousel горизонтально с шагом 16; плитка — карточки grid
/// в две колонки с шагом 16 по обеим осям; список — карточки list столбиком с шагом 16.
///
/// Плитка и список сами не скроллят: их высоту задаёт содержимое, прокрутка
/// остаётся за экраном хоста. Карусель скроллит горизонтально и сообщает
/// индекс первой видимой карточки через [onFirstVisibleChanged].
class PersonalizationProductsList extends StatefulWidget {
  const PersonalizationProductsList({
    super.key,
    this.layout = PersonalizationProductsLayout.carousel,
    required this.products,
    this.imageAspect = PersonalizationProductImageAspect.square,
    this.onProductAction,
    this.onFirstVisibleChanged,
    this.iconBuilder,
  });

  final PersonalizationProductsLayout layout;
  final List<PersonalizationProduct> products;

  /// Пропорция картинок карточек, см. [PersonalizationProductCard.imageAspect].
  final PersonalizationProductImageAspect imageAspect;
  final ValueChanged<PersonalizationProduct>? onProductAction;
  final ValueChanged<int>? onFirstVisibleChanged;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )? iconBuilder;

  @override
  State<PersonalizationProductsList> createState() => _PersonalizationProductsListState();
}

class _PersonalizationProductsListState extends State<PersonalizationProductsList> {
  final ScrollController _controller = ScrollController();
  int _lastFirst = -1;

  static const double _gap = 16;
  static const double _carouselCard = 220;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.layout != PersonalizationProductsLayout.carousel) return;
    // Первая полностью видимая карточка: шаг ленты — ширина карточки плюс зазор.
    final first = (_controller.offset / (_carouselCard + _gap)).ceil();
    final clamped = first.clamp(0, widget.products.isEmpty ? 0 : widget.products.length - 1);
    if (clamped != _lastFirst) {
      _lastFirst = clamped;
      widget.onFirstVisibleChanged?.call(clamped);
    }
  }

  Widget _card(PersonalizationProduct product, PersonalizationProductCardType type) {
    return PersonalizationProductCard(
      type: type,
      image: product.image,
      imageAspect: widget.imageAspect,
      brand: product.brand,
      name: product.name,
      rating: product.rating,
      price: product.price,
      oldPrice: product.oldPrice,
      discount: product.discount,
      actionText: product.actionText,
      onAction: widget.onProductAction == null ? null : () => widget.onProductAction!(product),
      iconBuilder: widget.iconBuilder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    switch (widget.layout) {
      case PersonalizationProductsLayout.carousel:
        return SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < products.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: _gap),
                _card(products[i], PersonalizationProductCardType.carousel),
              ],
            ],
          ),
        );
      case PersonalizationProductsLayout.grid:
        return Column(
          children: <Widget>[
            for (int row = 0; row < products.length; row += 2) ...<Widget>[
              if (row > 0) const SizedBox(height: _gap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _card(products[row], PersonalizationProductCardType.grid)),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: row + 1 < products.length
                        ? _card(products[row + 1], PersonalizationProductCardType.grid)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ],
        );
      case PersonalizationProductsLayout.list:
        return Column(
          children: <Widget>[
            for (int i = 0; i < products.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: _gap),
              _card(products[i], PersonalizationProductCardType.list),
            ],
          ],
        );
    }
  }
}
