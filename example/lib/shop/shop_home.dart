import 'package:flutter/material.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

import 'shop.dart';
import 'shop_category.dart';
import 'shop_product.dart';
import 'shop_products.dart';
import 'shop_search.dart';

/// "Shop" — a demo shop built from the kit and the public SDK methods: the way a
/// host would integrate them. Home has the instant search, the stories bar, the
/// recommender block and the top-level categories; from there the category,
/// product and search screens go on the app's navigator, so back walks them in
/// reverse. "Add to cart" sends the cart event and shows a toast — there is no
/// cart screen.
///
/// The Android, iOS and React Native demos build the same shop.
class ShopPane extends StatefulWidget {
  const ShopPane({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopPane> createState() => _ShopPaneState();
}

class _ShopPaneState extends State<ShopPane> {
  /// Top-level categories; `null` while they load.
  List<ProductCategory>? _categories;
  Object? _categoriesError;

  /// The search field has been focused: its panel (recent searches, suggestions,
  /// categories, products) is open and the rest of home steps aside until Cancel.
  bool _searching = false;

  /// Bumped on Cancel: a new field starts with an empty query.
  int _searchField = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      // The listing is only read for its categories, so one page is enough: 50
      // products bring up the main top-level ones.
      final response = await REES46
          .getInstance(widget.shopId)
          .getProductsList(params: const ProductsListParams(limit: 50));
      if (mounted) setState(() => _categories = shopTopCategories(response));
    } catch (error) {
      if (mounted) setState(() => _categoriesError = error);
    }
  }

  void _retryCategories() {
    setState(() => _categoriesError = null);
    _loadCategories();
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = false;
      _searchField++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopId = widget.shopId;
    // Back with the search panel open closes the panel, not the shop.
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      child: Scaffold(
        backgroundColor: PersonalizationTheme.of(
          context,
        ).colors.backgroundGeneric,
        appBar: AppBar(title: const Text('Shop')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                onFocusChange: (focused) {
                  if (focused && !_searching) setState(() => _searching = true);
                },
                child: PersonalizationInstantSearchField(
                  key: ValueKey(_searchField),
                  shopId: shopId,
                  placeholder: 'Search',
                  cancelText: _searching ? 'Cancel' : null,
                  showRecent: _searching,
                  showSuggestions: _searching,
                  showCategories: _searching,
                  showProducts: _searching,
                  recentLabel: 'Recent searches',
                  clearText: 'Clear',
                  moreText: 'more',
                  categoriesLabel: 'Categories',
                  productsLabel: 'Products',
                  onCancel: _closeSearch,
                  onSubmit: (query) =>
                      ShopSearchScreen.open(context, shopId, query),
                  onProductTap: (product) =>
                      ShopProductScreen.open(context, shopId, product.id),
                  onCategoryTap: (category) {
                    // Popular categories of the empty state come without an id.
                    final id = category.id;
                    if (id == null || id.isEmpty) return;
                    ShopCategoryScreen.open(context, shopId, id, category.name);
                  },
                  iconBuilder: shopIcon,
                ),
              ),
              // Offstage, not removed: the stories and the block keep what they loaded.
              Offstage(offstage: _searching, child: _home(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _home(BuildContext context) {
    final shopId = widget.shopId;
    final categories = _categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Collapses when the block is empty or fails. A product of a story closes the
        // viewer and opens here.
        PersonalizationStories(
          code: shopStoriesCode,
          shopId: shopId,
          padding: EdgeInsets.zero,
          promoCopiedText: 'Code copied to clipboard',
          onProductClick: (product) =>
              ShopProductScreen.open(context, shopId, product.id),
          iconBuilder: shopIcon,
        ),
        const SizedBox(height: 24),
        // Title from the response; hidden until its products arrive. The card button
        // remembers the block as the source before the cart event goes out.
        PersonalizationRecommenderBlock(
          code: shopRecommenderCode,
          shopId: shopId,
          actionText: shopAddToCartText,
          onProductTap: (product) =>
              ShopProductScreen.open(context, shopId, product.id),
          onProductAction: (product) =>
              addToShopCart(context, shopId, product.id),
          iconBuilder: shopIcon,
        ),
        const SizedBox(height: 24),
        const PersonalizationTitle(title: 'Categories'),
        const SizedBox(height: 12),
        if (_categoriesError != null)
          ShopRetry(onRetry: _retryCategories)
        else if (categories == null)
          const Center(child: PersonalizationLoader())
        else if (categories.isEmpty)
          const PersonalizationEmptyState(message: 'No categories yet.')
        else
          for (final (index, category) in categories.indexed) ...[
            if (index > 0) const SizedBox(height: 16),
            PersonalizationSuggestionRow(
              kind: PersonalizationSuggestionKind.category,
              title: category.name,
              onTap: () => ShopCategoryScreen.open(
                context,
                shopId,
                category.id,
                category.name,
              ),
              iconBuilder: shopIcon,
            ),
          ],
      ],
    );
  }
}
