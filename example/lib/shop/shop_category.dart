import 'package:flutter/material.dart';

// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

import '../demo_app.dart';
import 'shop.dart';
import 'shop_facets.dart';
import 'shop_product.dart';
import 'shop_search_field.dart';
import 'shop_sort.dart';

/// Category screen of the demo shop: the shop's instant search on top and the kit's
/// category screen under it. The kit loads, pages, filters and tracks the category
/// view itself; its back button walks the shop's stack, "Add to cart" sends the cart
/// event with a toast. The sort comes from the shop's picker — on Flutter the kit
/// keeps the sort button hidden until the native SDKs sort a category.
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
        settings: const RouteSettings(name: DemoScreens.category),
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
  ShopSort _sort = ShopSort.relevance;

  Future<void> _pickSort() async {
    final sort = await pickShopSort(context, _sort);
    if (sort != null && mounted) setState(() => _sort = sort);
  }

  @override
  Widget build(BuildContext context) {
    final shopId = widget.shopId;
    return Scaffold(
      backgroundColor: PersonalizationTheme.of(
        context,
      ).colors.backgroundGeneric,
      body: SafeArea(
        child: ShopSearchField.above(
          shopId: shopId,
          child: PersonalizationCategoryScreen(
            shopId: shopId,
            categoryId: widget.categoryId,
            titleText: widget.name,
            sortBy: _sort.sortBy,
            sortDir: _sort.sortDir,
            productActionText: shopAddToCartText,
            emptyText: 'No products in this category yet.',
            errorText: shopErrorText,
            retryText: shopRetryText,
            onBack: () => Navigator.of(context).maybePop(),
            onSortTap: _pickSort,
            onProductTap: (product) =>
                ShopProductScreen.open(context, shopId, product.id),
            onProductAction: (product) => addToShopCart(
              context,
              shopId,
              product.id,
              price: product.price,
            ),
            facetTitle: shopFacetTitle,
            facetValueTitle: shopFacetValueTitle,
            iconBuilder: shopIcon,
          ),
        ),
      ),
    );
  }
}
