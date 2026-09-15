import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

/// "UI Kit" screen — the design system, one exhibit per component.
///
/// "Components" walks through the primitives in every size, view and state the
/// design file defines; "Blocks" shows the compositions built from them
/// (product cards, recommender layouts, search suggestions, the catalogue).
/// Mirror of the Android `UiKitPane` / iOS `UIKitShowcaseViewController` /
/// React Native `UiKitPane`.
///
/// The kit does not draw SVG itself: every icon comes back through an
/// `iconBuilder`, rendered here with flutter_svg. Product data is static and
/// images are plain [ImageProvider]s — the kit does not fetch or format
/// anything.
class UiKitPane extends StatelessWidget {
  const UiKitPane({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('UI Kit'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Components'),
              Tab(text: 'Blocks'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Showcase(exhibits: _componentExhibits),
            _Showcase(exhibits: _blockExhibits),
          ],
        ),
      ),
    );
  }
}

class _Exhibit {
  const _Exhibit(this.title, this.build);

  final String title;
  final WidgetBuilder build;
}

class _Showcase extends StatelessWidget {
  const _Showcase({required this.exhibits});

  final List<_Exhibit> exhibits;

  @override
  Widget build(BuildContext context) {
    final caption = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: exhibits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        final exhibit = exhibits[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exhibit.title, style: caption),
            const SizedBox(height: 8),
            exhibit.build(context),
          ],
        );
      },
    );
  }
}

// --- Exhibits ---------------------------------------------------------------

final List<_Exhibit> _componentExhibits = [
  _Exhibit('Button — LG / MD / SM, primary · secondary · ghost', (context) {
    return _Column(
      children: [
        for (final size in PersonalizationButtonSize.values)
          _ScrollRow(
            children: [
              PersonalizationButton(
                label: 'Primary',
                size: size,
                view: PersonalizationButtonView.primary,
                onPressed: () {},
              ),
              PersonalizationButton(
                label: 'Secondary',
                size: size,
                view: PersonalizationButtonView.secondary,
                onPressed: () {},
              ),
              PersonalizationButton(
                label: 'Ghost',
                size: size,
                view: PersonalizationButtonView.ghost,
                onPressed: () {},
              ),
            ],
          ),
      ],
    );
  }),
  _Exhibit('Button — icons and disabled', (context) {
    return _ScrollRow(
      children: [
        PersonalizationButton(
          label: 'Filters',
          size: PersonalizationButtonSize.md,
          iconStart: PersonalizationIcons.equalizerHorizontal,
          iconBuilder: _icon,
          onPressed: () {},
        ),
        PersonalizationButton(
          label: 'Sort',
          size: PersonalizationButtonSize.md,
          view: PersonalizationButtonView.secondary,
          iconEnd: PersonalizationIcons.arrowsUpDown,
          iconBuilder: _icon,
          onPressed: () {},
        ),
        PersonalizationButton(
          size: PersonalizationButtonSize.md,
          view: PersonalizationButtonView.ghost,
          iconStart: PersonalizationIcons.copy,
          iconBuilder: _icon,
          onPressed: () {},
        ),
        const PersonalizationButton(
          label: 'Disabled',
          size: PersonalizationButtonSize.md,
        ),
      ],
    );
  }),
  _Exhibit('Button Group — MD and SM', (context) {
    return const _Row(
      children: [
        _ButtonGroupExhibit(size: PersonalizationButtonGroupSize.md),
        _ButtonGroupExhibit(size: PersonalizationButtonGroupSize.sm),
      ],
    );
  }),
  _Exhibit('Input Field — search LG, input MD, select SM, disabled', (context) {
    return _Column(
      children: [
        PersonalizationInputField(
          size: PersonalizationInputFieldSize.lg,
          type: PersonalizationInputFieldType.search,
          placeholder: 'Search',
          iconBuilder: _icon,
        ),
        PersonalizationInputField(
          size: PersonalizationInputFieldSize.md,
          type: PersonalizationInputFieldType.input,
          controller: TextEditingController(text: 'Running shoes'),
          iconBuilder: _icon,
        ),
        PersonalizationInputField(
          size: PersonalizationInputFieldSize.sm,
          type: PersonalizationInputFieldType.select,
          controller: TextEditingController(text: 'Size 42'),
          iconBuilder: _icon,
          onSelectTap: () {},
        ),
        PersonalizationInputField(
          size: PersonalizationInputFieldSize.md,
          type: PersonalizationInputFieldType.input,
          placeholder: 'Disabled',
          enabled: false,
          iconBuilder: _icon,
        ),
      ],
    );
  }),
  _Exhibit('Title — plain, with trailing action, with leading back', (context) {
    return _Column(
      children: [
        const PersonalizationTitle(title: 'Recommended for you'),
        PersonalizationTitle(
          title: 'Recently viewed',
          trailing: PersonalizationButton(
            label: 'Show all',
            size: PersonalizationButtonSize.sm,
            view: PersonalizationButtonView.ghost,
            iconEnd: PersonalizationIcons.angleLargeRight,
            iconBuilder: _icon,
            onPressed: () {},
          ),
        ),
        PersonalizationTitle(
          title: 'Sneakers',
          leading: PersonalizationButton(
            size: PersonalizationButtonSize.sm,
            view: PersonalizationButtonView.ghost,
            iconStart: PersonalizationIcons.arrowLeft,
            iconBuilder: _icon,
            onPressed: () {},
          ),
        ),
      ],
    );
  }),
  _Exhibit('Search Results Title', (context) => const _SearchResultsTitleExhibit()),
  _Exhibit('Accordion — collapsed with count, expanded', (context) {
    return _Column(
      children: [
        PersonalizationAccordion(label: 'Brand', count: 12, iconBuilder: _icon),
        PersonalizationAccordion(label: 'Size', expanded: true, iconBuilder: _icon),
      ],
    );
  }),
  _Exhibit('List Label', (context) => const PersonalizationListLabel(label: 'Popular categories')),
  _Exhibit('Badge — warning LG / MD / SM, danger', (context) {
    return const _Row(
      children: [
        PersonalizationBadge(label: 'New', size: PersonalizationBadgeSize.lg),
        PersonalizationBadge(label: 'New', size: PersonalizationBadgeSize.md),
        PersonalizationBadge(label: 'New', size: PersonalizationBadgeSize.sm),
        PersonalizationBadge(
          label: '-15%',
          size: PersonalizationBadgeSize.md,
          view: PersonalizationBadgeView.danger,
        ),
      ],
    );
  }),
  _Exhibit('Tag — primary with remove, secondary', (context) {
    return _Row(
      children: [
        PersonalizationTag(label: 'Nike', onRemove: () {}, removeIconBuilder: _removeIcon),
        PersonalizationTag(
          label: 'Size 42',
          view: PersonalizationTagView.secondary,
          onRemove: () {},
          removeIconBuilder: _removeIcon,
        ),
        const PersonalizationTag(label: 'Running', view: PersonalizationTagView.secondary),
      ],
    );
  }),
  _Exhibit('Checkbox — unchecked, checked, indeterminate, disabled; with label', (context) {
    return const _Column(
      children: [
        _Row(
          children: [
            PersonalizationCheckbox(state: PersonalizationCheckboxState.unchecked),
            PersonalizationCheckbox(state: PersonalizationCheckboxState.checked),
            PersonalizationCheckbox(state: PersonalizationCheckboxState.indeterminate),
            PersonalizationCheckbox(state: PersonalizationCheckboxState.checked, disabled: true),
          ],
        ),
        PersonalizationCheckboxWithLabel(
          label: 'In stock only',
          state: PersonalizationCheckboxState.checked,
        ),
      ],
    );
  }),
  _Exhibit('Dots, Count, Rating', (context) {
    return _Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PersonalizationDots(count: 5, selectedIndex: 1),
        const PersonalizationCount(prefix: 'Showing', shown: 12, separator: 'of', total: 128),
        PersonalizationRating(value: '4.7', reviews: 128, iconBuilder: _icon),
      ],
    );
  }),
  _Exhibit('Loader, Favorites Badge', (context) {
    return _Row(
      children: [
        const PersonalizationLoader(),
        PersonalizationFavoritesBadge(iconBuilder: _icon),
      ],
    );
  }),
  _Exhibit('Product Image — 1:1, 4:3, 3:4', (context) {
    return _Row(
      children: [
        for (final (index, aspect) in PersonalizationProductImageAspect.values.indexed)
          SizedBox(
            width: 104,
            child: PersonalizationProductImage(aspect: aspect, image: _products[index].image),
          ),
      ],
    );
  }),
  _Exhibit('Empty State', (context) => const PersonalizationEmptyState(message: 'No results for your request.')),
  _Exhibit('Icons — the full set, 24 dp', (context) {
    final color = PersonalizationTheme.of(context).colors.textPrimary;
    return _ScrollRow(
      children: [
        for (final asset in PersonalizationIcons.all) _icon(context, asset, 24, color),
      ],
    );
  }),
];

final List<_Exhibit> _blockExhibits = [
  _Exhibit('Product Card — carousel, grid, list', (context) {
    return _Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 220, child: _card(PersonalizationProductCardType.carousel, _products[0])),
        SizedBox(width: 161, child: _card(PersonalizationProductCardType.grid, _products[1])),
        _card(PersonalizationProductCardType.list, _products[2]),
      ],
    );
  }),
  _Exhibit('Recommender Block — carousel', (context) {
    return _recommender(PersonalizationProductsLayout.carousel, 'Recommended for you', _products);
  }),
  _Exhibit('Recommender Block — grid', (context) {
    return _recommender(PersonalizationProductsLayout.grid, 'Similar products', _products.take(4).toList());
  }),
  _Exhibit('Recommender Block — list', (context) {
    return _recommender(PersonalizationProductsLayout.list, 'Recently viewed', _products.take(3).toList());
  }),
  _Exhibit('Search Suggestions', (context) {
    return PersonalizationSearchSuggestions(
      highlight: 'run',
      showImages: true,
      tags: const ['running shoes', 'running jacket', 'run belt'],
      categories: const [
        PersonalizationSuggestion(id: 'c1', title: 'Running shoes', subtitle: 'Shoes'),
        PersonalizationSuggestion(id: 'c2', title: 'Running apparel', subtitle: 'Clothing'),
      ],
      products: [
        for (final p in _products.take(3))
          PersonalizationSuggestion(id: p.id, title: p.name, subtitle: p.price, image: p.image),
      ],
      onTagTap: (_) {},
      onCategoryTap: (_) {},
      onProductTap: (_) {},
      iconBuilder: _icon,
    );
  }),
  _Exhibit('Catalog — header, grid ⇄ list, count, load more', (context) => const _CatalogExhibit()),
];

// --- Stateful exhibits ------------------------------------------------------

class _ButtonGroupExhibit extends StatefulWidget {
  const _ButtonGroupExhibit({required this.size});

  final PersonalizationButtonGroupSize size;

  @override
  State<_ButtonGroupExhibit> createState() => _ButtonGroupExhibitState();
}

class _ButtonGroupExhibitState extends State<_ButtonGroupExhibit> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return PersonalizationButtonGroup(
      size: widget.size,
      selectedIndex: _selected,
      onSelected: (index) => setState(() => _selected = index),
      iconBuilder: _icon,
      items: const [
        PersonalizationButtonGroupItem(
          icon: PersonalizationIcons.grid2x2,
          activeIcon: PersonalizationIcons.grid2x2Fill,
        ),
        PersonalizationButtonGroupItem(
          icon: PersonalizationIcons.list,
          activeIcon: PersonalizationIcons.listFill,
        ),
      ],
    );
  }
}

class _SearchResultsTitleExhibit extends StatefulWidget {
  const _SearchResultsTitleExhibit({this.onViewChanged});

  final ValueChanged<int>? onViewChanged;

  @override
  State<_SearchResultsTitleExhibit> createState() => _SearchResultsTitleExhibitState();
}

class _SearchResultsTitleExhibitState extends State<_SearchResultsTitleExhibit> {
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    return PersonalizationSearchResultsTitle(
      title: 'Sneakers',
      selectedViewIndex: _view,
      onViewChanged: (index) {
        setState(() => _view = index);
        widget.onViewChanged?.call(index);
      },
      onBack: () {},
      onFilters: () {},
      onSort: () {},
      results: const PersonalizationSearchResults(prefix: 'Found', count: 128, suffix: 'products'),
      filters: [
        PersonalizationSearchFilter(label: 'Nike', onRemove: () {}),
        PersonalizationSearchFilter(label: 'Size 42', onRemove: () {}),
      ],
      iconBuilder: _icon,
    );
  }
}

/// The catalogue as a host would wire it: the results title in the header slot
/// drives the grid/list switch, "load more" appends a page after a short
/// simulated delay.
class _CatalogExhibit extends StatefulWidget {
  const _CatalogExhibit();

  @override
  State<_CatalogExhibit> createState() => _CatalogExhibitState();
}

class _CatalogExhibitState extends State<_CatalogExhibit> {
  PersonalizationProductsLayout _layout = PersonalizationProductsLayout.grid;
  List<PersonalizationProduct> _shown = _products.take(4).toList();
  bool _loading = false;

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      final page = _products.skip(_shown.length % _products.length).take(4);
      _shown = [
        ..._shown,
        for (final p in page) p.copyWith(id: '${p.id}-${_shown.length}'),
      ];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PersonalizationCatalog(
      header: _SearchResultsTitleExhibit(
        onViewChanged: (index) => setState(() {
          _layout = index == 0 ? PersonalizationProductsLayout.grid : PersonalizationProductsLayout.list;
        }),
      ),
      layout: _layout,
      products: _shown,
      loading: _loading,
      count: PersonalizationCatalogCount(
        prefix: 'Showing',
        shown: _shown.length,
        separator: 'of',
        total: _totalProducts,
      ),
      loadMoreText: 'Load more',
      onLoadMore: _loadMore,
      onProductAction: (_) {},
      iconBuilder: _icon,
    );
  }
}

// --- Layout helpers ---------------------------------------------------------

class _Row extends StatelessWidget {
  const _Row({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const SizedBox(width: 8),
          child,
        ],
      ],
    );
  }
}

class _ScrollRow extends StatelessWidget {
  const _ScrollRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: _Row(children: children),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.children, this.crossAxisAlignment = CrossAxisAlignment.stretch});

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const SizedBox(height: 12),
          child,
        ],
      ],
    );
  }
}

/// The kit hands over the asset and the colour it wants; the host picks the renderer.
Widget _icon(BuildContext context, String asset, double size, Color color) {
  return SvgPicture.asset(
    asset,
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

Widget _removeIcon(BuildContext context, String asset) {
  return _icon(context, asset, 16, PersonalizationTheme.of(context).colors.textPrimary);
}

Widget _card(PersonalizationProductCardType type, PersonalizationProduct product) {
  return PersonalizationProductCard(
    type: type,
    image: product.image,
    brand: product.brand,
    name: product.name,
    rating: product.rating,
    price: product.price,
    oldPrice: product.oldPrice,
    discount: product.discount,
    actionText: product.actionText,
    onAction: () {},
    iconBuilder: _icon,
  );
}

Widget _recommender(PersonalizationProductsLayout layout, String title, List<PersonalizationProduct> products) {
  return PersonalizationRecommenderBlock(
    layout: layout,
    title: title,
    showAllText: 'Show all',
    onShowAll: () {},
    products: products,
    onProductAction: (_) {},
    iconBuilder: _icon,
  );
}

// --- Fixtures ---------------------------------------------------------------

const int _totalProducts = 128;

ImageProvider _image(String seed) => NetworkImage('https://picsum.photos/seed/$seed/600/600');

/// Static products for the exhibits. Strings arrive formatted — that is the kit's contract.
final List<PersonalizationProduct> _products = [
  PersonalizationProduct(id: '1', name: 'Air Zoom Pegasus 41 running shoes', price: r'$140', image: _image('pegasus'), brand: 'Nike', rating: const PersonalizationProductRating(value: '4.7', reviews: 128), oldPrice: r'$165', discount: '-15%', actionText: 'Add to cart'),
  PersonalizationProduct(id: '2', name: 'Wireless over-ear headphones', price: r'$299', image: _image('headphones'), brand: 'Sony', rating: const PersonalizationProductRating(value: '4.8', reviews: 2140), actionText: 'Add to cart'),
  PersonalizationProduct(id: '3', name: 'Everyday backpack 20 L', price: r'$89', image: _image('backpack'), brand: 'Peak Design', rating: const PersonalizationProductRating(value: '4.6', reviews: 412), oldPrice: r'$110', discount: '-19%', actionText: 'Add to cart'),
  PersonalizationProduct(id: '4', name: 'Trail running jacket', price: r'$175', image: _image('jacket'), brand: 'Salomon', rating: const PersonalizationProductRating(value: '4.5', reviews: 77), actionText: 'Add to cart'),
  PersonalizationProduct(id: '5', name: 'Polarized sunglasses', price: r'$120', image: _image('sunglasses'), brand: 'Oakley', rating: const PersonalizationProductRating(value: '4.4', reviews: 305), oldPrice: r'$150', discount: '-20%', actionText: 'Add to cart'),
  PersonalizationProduct(id: '6', name: 'Insulated bottle 750 ml', price: r'$35', image: _image('bottle'), brand: 'Hydro Flask', rating: const PersonalizationProductRating(value: '4.9', reviews: 980), actionText: 'Add to cart'),
  PersonalizationProduct(id: '7', name: 'GPS running watch', price: r'$449', image: _image('watch'), brand: 'Garmin', rating: const PersonalizationProductRating(value: '4.7', reviews: 1532), actionText: 'Add to cart'),
  PersonalizationProduct(id: '8', name: 'Court sneakers', price: r'$95', image: _image('sneakers'), brand: 'Adidas', rating: const PersonalizationProductRating(value: '4.3', reviews: 64), oldPrice: r'$120', discount: '-21%', actionText: 'Add to cart'),
];

extension on PersonalizationProduct {
  PersonalizationProduct copyWith({required String id}) {
    return PersonalizationProduct(
      id: id,
      name: name,
      price: price,
      image: image,
      brand: brand,
      rating: rating,
      oldPrice: oldPrice,
      discount: discount,
      actionText: actionText,
    );
  }
}
