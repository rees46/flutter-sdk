import 'package:flutter/material.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

import 'shop.dart';
import 'shop_product.dart';
import 'shop_products.dart';

/// Category screen of the demo shop: `getCategory` page by page in the kit's
/// catalog — the category title with the grid ⇄ list switch, "showing N of M",
/// "Load more", the empty state, and Retry where a page did not load (the first
/// one: in place of the products; a next one: in place of "Load more"). No
/// filters or sorting yet.
class ShopCategoryScreen extends StatefulWidget {
  const ShopCategoryScreen({
    super.key,
    required this.shopId,
    required this.categoryId,
    required this.name,
  });

  final String shopId;
  final String categoryId;

  /// The title: the category response carries no name, the list it was picked
  /// from does.
  final String name;

  /// Opens the category on top of the current screen.
  static void open(
    BuildContext context,
    String shopId,
    String categoryId,
    String name,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopCategoryScreen(
          shopId: shopId,
          categoryId: categoryId,
          name: name,
        ),
      ),
    );
  }

  @override
  State<ShopCategoryScreen> createState() => _ShopCategoryScreenState();
}

class _ShopCategoryScreenState extends State<ShopCategoryScreen> {
  static const int _pageSize = 20;

  final List<Product> _products = <Product>[];
  int _total = 0;

  /// The last page that came; pages start at 1.
  int _page = 0;

  /// A page came back empty: the category has nothing more, whatever the total says.
  bool _ended = false;

  /// The first page came: only then an empty list means an empty category.
  bool _answered = false;

  /// The page whose request failed; `null` — no error.
  int? _failedPage;
  bool _loading = true;
  PersonalizationProductsLayout _layout = PersonalizationProductsLayout.grid;

  @override
  void initState() {
    super.initState();
    _fetch(1);
  }

  Future<void> _fetch(int page) async {
    try {
      final response = await REES46
          .getInstance(widget.shopId)
          .getCategory(widget.categoryId, limit: _pageSize, page: page);
      if (!mounted) return;
      setState(() {
        _products.addAll(response.products);
        _total = response.productsTotal;
        _page = page;
        _ended = response.products.isEmpty;
        _answered = true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failedPage = page;
        _loading = false;
      });
    }
  }

  void _loadMore() {
    if (_loading) return;
    setState(() => _loading = true);
    _fetch(_page + 1);
  }

  void _retry() {
    final page = _failedPage;
    if (page == null || _loading) return;
    setState(() {
      _failedPage = null;
      _loading = true;
    });
    _fetch(page);
  }

  Product? _find(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final firstPageFailed = _failedPage == 1;
    final nextPageFailed = (_failedPage ?? 0) > 1;
    final hasMore = !_ended && _products.length < _total;
    final grid = _layout == PersonalizationProductsLayout.grid;

    final header = PersonalizationTitle(
      title: widget.name,
      leading: const ShopBackButton(),
      trailing: PersonalizationButtonGroup(
        selectedIndex: grid ? 0 : 1,
        onSelected: (index) => setState(() {
          _layout = index == 0
              ? PersonalizationProductsLayout.grid
              : PersonalizationProductsLayout.list;
        }),
        iconBuilder: shopIcon,
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
      ),
    );

    return Scaffold(
      backgroundColor: PersonalizationTheme.of(
        context,
      ).colors.backgroundGeneric,
      body: SafeArea(
        // The catalog scrolls on its own and builds only the cards in view, however
        // many pages have come.
        child: PersonalizationCatalog(
          padding: const EdgeInsets.all(16),
          header: header,
          layout: _layout,
          products: [
            for (final product in _products)
              shopCard(product, actionText: shopAddToCartText),
          ],
          showRating: false,
          emptyText: firstPageFailed
              ? shopErrorText
              : (_answered ? 'No products in this category yet.' : null),
          emptyActionText: firstPageFailed ? shopRetryText : null,
          onEmptyAction: _retry,
          loading: _loading,
          count: _products.isEmpty
              ? null
              : PersonalizationCatalogCount(
                  prefix: 'Showing',
                  shown: _products.length,
                  separator: 'of',
                  total: _total,
                ),
          loadMoreText: nextPageFailed
              ? shopRetryText
              : (hasMore ? 'Load more' : null),
          onLoadMore: nextPageFailed ? _retry : _loadMore,
          onProductTap: (card) =>
              ShopProductScreen.open(context, widget.shopId, card.id),
          onProductAction: (card) => addToShopCart(
            context,
            widget.shopId,
            card.id,
            price: _find(card.id)?.price,
          ),
          iconBuilder: shopIcon,
        ),
      ),
    );
  }
}
