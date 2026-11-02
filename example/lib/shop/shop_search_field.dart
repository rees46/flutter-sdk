import 'package:flutter/material.dart';

// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

import 'shop.dart';
import 'shop_category.dart';
import 'shop_product.dart';
import 'shop_search.dart';

/// The shop's instant search, the same on home, category and product: once the field
/// is focused its panel (recent searches, suggestions, categories, products) opens
/// and the rest of the screen steps aside until Cancel; back with the panel open
/// closes the panel, not the screen. Submit opens the search results, a product of
/// the panel its product screen, a category of the panel its category screen.
class ShopSearchField extends StatefulWidget {
  const ShopSearchField({
    super.key,
    required this.shopId,
    required this.builder,
  });

  /// The field pinned on top of [child], which fills the rest of the screen and
  /// scrolls on its own. With the panel open the panel takes the whole screen.
  ShopSearchField.above({
    Key? key,
    required String shopId,
    required Widget child,
  }) : this(
         key: key,
         shopId: shopId,
         builder: (context, field, searching) =>
             _Above(field: field, searching: searching, child: child),
       );

  final String shopId;

  /// Lays the screen out around [field] — the search field with its panel. While
  /// [searching] the rest of the screen goes offstage, not away: it keeps what it
  /// loaded.
  final Widget Function(BuildContext context, Widget field, bool searching)
  builder;

  @override
  State<ShopSearchField> createState() => _ShopSearchFieldState();
}

class _ShopSearchFieldState extends State<ShopSearchField> {
  /// The field has been focused: its panel is open until Cancel.
  bool _searching = false;

  /// Bumped on Cancel: a new field starts with an empty query.
  int _searchField = 0;

  void _close() {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = false;
      _searchField++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopId = widget.shopId;
    final field = Focus(
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
        onCancel: _close,
        onSubmit: (query) => ShopSearchScreen.open(context, shopId, query),
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
    );
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: widget.builder(context, field, _searching),
    );
  }
}

/// [ShopSearchField.above]: the field over the screen, the open panel over all of it.
class _Above extends StatelessWidget {
  const _Above({
    required this.field,
    required this.searching,
    required this.child,
  });

  final Widget field;
  final bool searching;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Closed, the field takes its own height; open, the panel scrolls within
          // the screen.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: searching ? constraints.maxHeight : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: field,
            ),
          ),
          Expanded(
            child: Offstage(offstage: searching, child: child),
          ),
        ],
      ),
    );
  }
}
