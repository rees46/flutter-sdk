import 'package:flutter/widgets.dart';

import '../personalization_icons.dart';
import '../personalization_spacing.dart';
import 'personalization_button.dart';
import 'personalization_count.dart';
import 'personalization_empty_state.dart';
import 'personalization_loader.dart';
import 'personalization_product.dart';
import 'personalization_product_card.dart';
import 'personalization_product_image.dart';
import 'personalization_products_list.dart';

/// Счётчик каталога «показано N из M». Слова — параметры.
@immutable
class PersonalizationCatalogCount {
  const PersonalizationCatalogCount({
    required this.prefix,
    required this.shown,
    required this.separator,
    required this.total,
  });

  final String prefix;
  final int shown;
  final String separator;
  final int total;
}

/// Экран каталога: заголовок, плитка или список товаров, внизу лоадер, счётчик
/// и кнопка «загрузить ещё».
///
/// Источник: Figma Mobile SDK UI Kit, секция Card — Search results (167:4477) и
/// Category (167:4856). Оба одной формы, разница только в заголовке: у выдачи
/// [PersonalizationSearchResultsTitle], у категории [PersonalizationTitle] с
/// переключателем вида. Поэтому заголовок здесь — слот, а не вариант.
/// Три нижних элемента в макете скрываемые (showLoader, showCount, showLoadMore).
/// Шаг блока 12, шаг плитки и списка 16 по обеим осям.
///
/// Пустая выдача — страница SearchResultsScreen, Search Results/Empty State (319:7743):
/// заголовок тот же, вместо плитки [PersonalizationEmptyState]. Показывается, когда
/// задан [emptyText] и товаров нет.
///
/// Весь каталог — одна лента: заголовок, карточки и нижние элементы — её части, а
/// карточки строятся только под видимую часть, сколько бы страниц ни догрузилось.
/// Поэтому его не вкладывают в прокрутку, он прокручивается сам. Внутри чужой
/// вертикальной прокрутки ([scrollable] `false` или высота не ограничена) он
/// раскладывается целиком, как обычный блок, и сам не прокручивается.
class PersonalizationCatalog extends StatelessWidget {
  const PersonalizationCatalog({
    super.key,
    this.header,
    this.layout = PersonalizationProductsLayout.grid,
    required this.products,
    this.imageAspect = PersonalizationProductImageAspect.square,
    this.onProductAction,
    this.onProductTap,
    this.emptyText,
    this.loading = false,
    this.count,
    this.loadMoreText,
    this.onLoadMore,
    this.iconBuilder,
    this.scrollable = true,
    this.controller,
    this.padding,
  });

  final Widget? header;
  final PersonalizationProductsLayout layout;
  final List<PersonalizationProduct> products;

  /// Пропорция картинок карточек, см. [PersonalizationProductCard.imageAspect].
  final PersonalizationProductImageAspect imageAspect;
  final ValueChanged<PersonalizationProduct>? onProductAction;

  /// Нажатие на карточку — открыть товар.
  final ValueChanged<PersonalizationProduct>? onProductTap;

  /// Текст пустой выдачи. `null` — без пустого состояния, плитка остаётся на месте.
  final String? emptyText;
  final bool loading;
  final PersonalizationCatalogCount? count;

  /// Подпись кнопки «загрузить ещё». `null` — без кнопки.
  final String? loadMoreText;
  final VoidCallback? onLoadMore;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  /// Прокручивается ли каталог сам. `false` — раскладывается целиком по высоте
  /// содержимого и не прокручивается: так его кладут в чужую вертикальную прокрутку.
  /// Где высота не ограничена (колонка, скролл), он и без флага раскладывается целиком.
  final bool scrollable;

  /// Контроллер собственной прокрутки: следить за ней (бесконечная прокрутка) и
  /// возвращать ленту к началу.
  final ScrollController? controller;

  /// Поля ленты. Содержимое прокручивается под ними, а не обрезается по их краю.
  final EdgeInsetsGeometry? padding;

  /// Шаг между блоками каталога.
  static const double _gapBlock = PersonalizationSpacing.lg;

  /// Шаг карточек плитки и списка по обеим осям.
  static const double _gapTile = PersonalizationSpacing.xl;

  @override
  Widget build(BuildContext context) {
    if (!scrollable) return _list(embedded: true);
    // Высота не ограничена — каталог положили в колонку или чужой скролл без флага:
    // раскладываем целиком, как обычный блок, а не падаем на вьюпорте без высоты.
    return LayoutBuilder(
      builder: (context, constraints) =>
          _list(embedded: !constraints.hasBoundedHeight),
    );
  }

  Widget _list({required bool embedded}) {
    final bool empty = products.isEmpty && (emptyText ?? '').isNotEmpty;
    final bool grid = layout == PersonalizationProductsLayout.grid;
    // Плитка идёт строками по две карточки, список — по одной.
    final int rows = grid ? (products.length + 1) ~/ 2 : products.length;
    final footer = <Widget>[
      if (empty) PersonalizationEmptyState(message: emptyText!),
      // Во фреймах с лоадером (296:3544, 299:6606) счётчика и кнопки нет — на время
      // загрузки лоадер встаёт на их место.
      if (loading) const PersonalizationLoader(),
      if (count != null && !loading)
        PersonalizationCount(
          prefix: count!.prefix,
          shown: count!.shown,
          separator: count!.separator,
          total: count!.total,
        ),
      if (loadMoreText != null && loadMoreText!.isNotEmpty && !loading)
        PersonalizationButton(
          label: loadMoreText,
          size: PersonalizationButtonSize.md,
          view: PersonalizationButtonView.secondary,
          iconStart: PersonalizationIcons.arrowRotateCw,
          iconBuilder: iconBuilder,
          onPressed: onLoadMore,
        ),
    ];

    return CustomScrollView(
      controller: controller,
      // Вложенный каталог не прокручивается и не должен забирать чужой
      // PrimaryScrollController.
      primary: embedded ? false : null,
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      slivers: <Widget>[
        SliverPadding(
          padding: padding ?? EdgeInsets.zero,
          sliver: SliverMainAxisGroup(
            slivers: <Widget>[
              // Заголовок и нижние элементы — отдельные слайверы: они живут, пока жив
              // каталог, и не теряют состояние, уехав за экран. Строится лениво только
              // лента карточек.
              if (header != null) SliverToBoxAdapter(child: header),
              if (rows > 0)
                SliverPadding(
                  padding: EdgeInsets.only(top: header != null ? _gapBlock : 0),
                  sliver: SliverList.separated(
                    itemCount: rows,
                    itemBuilder: (context, row) => grid
                        ? _gridRow(row)
                        : _card(
                            products[row],
                            PersonalizationProductCardType.list,
                          ),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: _gapTile),
                  ),
                ),
              if (footer.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int i = 0; i < footer.length; i++) ...<Widget>[
                        if (i > 0 || header != null || rows > 0)
                          const SizedBox(height: _gapBlock),
                        footer[i],
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Строка плитки. IntrinsicHeight + stretch: соседние карточки одной высоты, и
  /// цена с кнопкой у них на одной линии (см. [PersonalizationProductsList]).
  Widget _gridRow(int row) {
    final int first = row * 2;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _card(products[first], PersonalizationProductCardType.grid),
          ),
          const SizedBox(width: _gapTile),
          Expanded(
            child: first + 1 < products.length
                ? _card(
                    products[first + 1],
                    PersonalizationProductCardType.grid,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Карточка товара — так же, как её собирает [PersonalizationProductsList].
  Widget _card(
    PersonalizationProduct product,
    PersonalizationProductCardType type,
  ) {
    return PersonalizationProductCard(
      type: type,
      image: product.image,
      imageAspect: imageAspect,
      brand: product.brand,
      name: product.name,
      rating: product.rating,
      price: product.price,
      oldPrice: product.oldPrice,
      discount: product.discount,
      actionText: product.actionText,
      onAction: onProductAction == null
          ? null
          : () => onProductAction!(product),
      onTap: onProductTap == null ? null : () => onProductTap!(product),
      iconBuilder: iconBuilder,
    );
  }
}
