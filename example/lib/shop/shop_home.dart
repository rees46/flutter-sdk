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
import 'shop_search_field.dart';

/// "Shop" — a demo shop built from the kit and the public SDK methods: the way a
/// host would integrate them. It is the home of the "Shop" tab (see `DemoTabs`).
/// Home has the instant search, the stories bar, the recommender block and the
/// top-level categories; from there the category, product and search screens go on
/// the tab's own navigator, so they open under the tab bar and back walks them in
/// reverse. The category and product screens carry the same instant search on top.
/// "Add to cart" sends the cart event and shows a toast — there is no cart screen.
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

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      // The listing is only read for its categories, which come with it whatever
      // the page size: a few products are enough.
      final response = await REES46
          .getInstance(widget.shopId)
          .getProductsList(params: const ProductsListParams(limit: 10));
      if (mounted) setState(() => _categories = shopTopCategories(response));
    } catch (error) {
      if (mounted) setState(() => _categoriesError = error);
    }
  }

  void _retryCategories() {
    setState(() => _categoriesError = null);
    _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PersonalizationTheme.of(
        context,
      ).colors.backgroundGeneric,
      appBar: AppBar(title: const Text('Shop')),
      // Home scrolls with the field: the field is the top of the page, not pinned.
      body: ShopSearchField(
        shopId: widget.shopId,
        builder: (context, field, searching) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              // Offstage, not removed: the stories and the block keep what they loaded.
              Offstage(offstage: searching, child: _home(context)),
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
