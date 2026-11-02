import 'package:flutter/material.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

import 'shop.dart';
import 'shop_products.dart';
import 'shop_search_field.dart';

/// Product screen of the demo shop: `getProductInfo`, the product view sent to
/// tracking once per opening, "Add to cart", and recommender blocks for this
/// product (`itemId`) — similar, bought with it and popular, each titled by the
/// server and hidden while it has no products. The shop's instant search is on top.
class ShopProductScreen extends StatefulWidget {
  const ShopProductScreen({
    super.key,
    required this.shopId,
    required this.productId,
  });

  final String shopId;
  final String productId;

  /// Opens the product on top of the current screen.
  static void open(BuildContext context, String shopId, String productId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopProductScreen(shopId: shopId, productId: productId),
      ),
    );
  }

  @override
  State<ShopProductScreen> createState() => _ShopProductScreenState();
}

const List<String> _productBlocks = <String>[
  shopSimilarCode,
  shopAlsoBoughtCode,
  shopRecommenderCode,
];

class _ShopProductScreenState extends State<ShopProductScreen> {
  Product? _product;
  Object? _error;

  /// Products each block shows: a hidden block takes no room, so its gap goes too.
  final Map<String, int> _blockCounts = <String, int>{};

  @override
  void initState() {
    super.initState();
    _trackView();
    _load();
  }

  /// Once per opening, not per retry. The source a block or the search remembered
  /// on the way here rides on this event.
  Future<void> _trackView() async {
    try {
      await REES46
          .getInstance(widget.shopId)
          .tracking
          .productView(widget.productId);
    } catch (error) {
      debugPrint('Shop: product view not tracked — $error');
    }
  }

  Future<void> _load() async {
    try {
      final product = await REES46
          .getInstance(widget.shopId)
          .getProductInfo(widget.productId);
      if (mounted) setState(() => _product = product);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _retry() {
    setState(() => _error = null);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Scaffold(
      backgroundColor: PersonalizationTheme.of(
        context,
      ).colors.backgroundGeneric,
      appBar: AppBar(title: const Text('Product')),
      body: ShopSearchField.above(
        shopId: widget.shopId,
        child: _error != null
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ShopRetry(onRetry: _retry),
                ),
              )
            : product == null
            ? const Center(child: PersonalizationLoader())
            : _details(context, product),
      ),
    );
  }

  Widget _details(BuildContext context, Product product) {
    final colors = PersonalizationTheme.of(context).colors;
    final card = shopCard(product);
    // The page shows the full image; `picture` is the copy resized for lists.
    final image = product.imageUrl.isNotEmpty
        ? product.imageUrl
        : (product.picture ?? '');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PersonalizationProductImage(
          image: image.isEmpty ? null : NetworkImage(image),
        ),
        const SizedBox(height: 16),
        if (card.brand != null)
          Text(
            card.brand!,
            style: shopTextStyle(
              context,
              PersonalizationTypography.smDefault,
              colors.textSecondary,
            ),
          ),
        Text(
          card.name,
          style: shopTextStyle(
            context,
            PersonalizationTypography.xlEmphasized,
            colors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              card.price,
              style: shopTextStyle(
                context,
                PersonalizationTypography.xl2Emphasized,
                colors.textPrimary,
              ),
            ),
            if (card.oldPrice != null)
              Text(
                card.oldPrice!,
                style: shopTextStyle(
                  context,
                  PersonalizationTypography.baseDefault,
                  colors.textSecondary,
                ).copyWith(decoration: TextDecoration.lineThrough),
              ),
            if (card.discount != null)
              PersonalizationBadge(
                label: card.discount!,
                size: PersonalizationBadgeSize.md,
                view: PersonalizationBadgeView.danger,
              ),
          ],
        ),
        const SizedBox(height: 16),
        PersonalizationButton(
          label: shopAddToCartText,
          onPressed: () => addToShopCart(
            context,
            widget.shopId,
            widget.productId,
            price: product.price,
          ),
        ),
        // Each block is hidden until its products arrive, and stays hidden when
        // there are none.
        for (final String code in _productBlocks) ...<Widget>[
          if ((_blockCounts[code] ?? 0) > 0) const SizedBox(height: 32),
          PersonalizationRecommenderBlock(
            key: ValueKey<String>(code),
            code: code,
            itemId: widget.productId,
            shopId: widget.shopId,
            actionText: shopAddToCartText,
            onLoaded: (count) {
              if (mounted && _blockCounts[code] != count) {
                setState(() => _blockCounts[code] = count);
              }
            },
            onProductTap: (item) =>
                ShopProductScreen.open(context, widget.shopId, item.id),
            onProductAction: (item) =>
                addToShopCart(context, widget.shopId, item.id),
            iconBuilder: shopIcon,
          ),
        ],
      ],
    );
  }
}
