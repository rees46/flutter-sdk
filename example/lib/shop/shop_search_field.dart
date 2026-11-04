import 'package:flutter/material.dart';

// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

import 'shop.dart';
import 'shop_category.dart';
import 'shop_product.dart';
import 'shop_search.dart';

/// The shop's instant search on its home, behind the search button of its header: the
/// button opens the search mode — the kit's field in place of the header, focused, with
/// Cancel, and the field's panel (recent searches, suggestions, categories, products)
/// under it while the rest of the page steps aside. Cancel or back closes it, back with
/// it open does not leave the screen. Submit opens the search results and closes the
/// mode, so back from them finds home as it was; a product of the panel opens its
/// product screen, a category of the panel its category screen.
class ShopSearchField extends StatefulWidget {
  const ShopSearchField({
    super.key,
    required this.shopId,
    required this.builder,
  });

  final String shopId;

  /// Lays the screen out: [field] — the search field with its panel — while
  /// [searching], else the screen with [search] behind its search button. While
  /// searching the rest of the screen goes offstage, not away: it keeps what it
  /// loaded.
  final Widget Function(
    BuildContext context,
    Widget field,
    bool searching,
    VoidCallback search,
  )
  builder;

  @override
  State<ShopSearchField> createState() => _ShopSearchFieldState();
}

class _ShopSearchFieldState extends State<ShopSearchField> {
  /// The search mode is on until Cancel.
  bool _searching = false;

  /// Bumped on close: the next field starts with an empty query.
  int _searchField = 0;

  /// Holds the field, to focus it: the kit's field keeps its focus node to itself.
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'Shop search');

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _searching = true);
    // The field is built in the next frame; its text input is the one to focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_searching) return;
      for (final node in _scope.descendants) {
        if (node.context?.findAncestorWidgetOfExactType<EditableText>() !=
            null) {
          node.requestFocus();
          return;
        }
      }
    });
  }

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
    final field = FocusScope(
      node: _scope,
      child: PersonalizationInstantSearchField(
        key: ValueKey(_searchField),
        shopId: shopId,
        placeholder: 'Search',
        cancelText: 'Cancel',
        recentLabel: 'Recent searches',
        clearText: 'Clear',
        moreText: 'more',
        categoriesLabel: 'Categories',
        productsLabel: 'Products',
        onCancel: _close,
        onSubmit: (query) {
          _close();
          ShopSearchScreen.open(context, shopId, query);
        },
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
      child: widget.builder(context, field, _searching, _open),
    );
  }
}
