import 'package:flutter/widgets.dart';

import '../personalization_icons.dart';
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
/// Шаг блока 12.
///
/// Пустая выдача — страница SearchResultsScreen, Search Results/Empty State (319:7743):
/// заголовок тот же, вместо плитки [PersonalizationEmptyState]. Показывается, когда
/// задан [emptyText] и товаров нет.
class PersonalizationCatalog extends StatelessWidget {
  const PersonalizationCatalog({
    super.key,
    this.header,
    this.layout = PersonalizationProductsLayout.grid,
    required this.products,
    this.imageAspect = PersonalizationProductImageAspect.square,
    this.onProductAction,
    this.emptyText,
    this.loading = false,
    this.count,
    this.loadMoreText,
    this.onLoadMore,
    this.iconBuilder,
  });

  final Widget? header;
  final PersonalizationProductsLayout layout;
  final List<PersonalizationProduct> products;

  /// Пропорция картинок карточек, см. [PersonalizationProductCard.imageAspect].
  final PersonalizationProductImageAspect imageAspect;
  final ValueChanged<PersonalizationProduct>? onProductAction;

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

  @override
  Widget build(BuildContext context) {
    final bool empty = products.isEmpty && (emptyText ?? '').isNotEmpty;
    final sections = <Widget>[
      ?header,
      if (empty)
        PersonalizationEmptyState(message: emptyText!)
      else
        PersonalizationProductsList(
          layout: layout,
          products: products,
          imageAspect: imageAspect,
          onProductAction: onProductAction,
          iconBuilder: iconBuilder,
        ),
      if (loading) const PersonalizationLoader(),
      if (count != null)
        PersonalizationCount(
          prefix: count!.prefix,
          shown: count!.shown,
          separator: count!.separator,
          total: count!.total,
        ),
      if (loadMoreText != null && loadMoreText!.isNotEmpty)
        PersonalizationButton(
          label: loadMoreText,
          size: PersonalizationButtonSize.md,
          view: PersonalizationButtonView.secondary,
          iconStart: PersonalizationIcons.arrowRotateCw,
          iconBuilder: iconBuilder,
          onPressed: onLoadMore,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < sections.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          sections[i],
        ],
      ],
    );
  }
}
