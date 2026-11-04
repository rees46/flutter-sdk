import 'package:flutter/material.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

import '../demo_app.dart';
import 'shop.dart';
import 'shop_products.dart';

/// Product screen of the demo shop, put together from the kit's pieces: `getProductInfo`,
/// the product view sent to tracking once per opening, and recommender blocks for this
/// product (`itemId`) — similar, bought with it and popular, each titled by the server
/// and hidden while it has no products. On top the photo's card runs under the status
/// bar with a round back button over it; "Add to cart" is pinned at the bottom with the
/// price. No search and no app bar here.
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
    Navigator.of(context).push(route(shopId, productId));
  }

  /// The product's page, for a navigator not reached through a context.
  static Route<void> route(String shopId, String productId) =>
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: DemoScreens.product),
        builder: (_) => ShopProductScreen(shopId: shopId, productId: productId),
      );

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

  final ScrollController _scroll = ScrollController();
  final GlobalKey _hero = GlobalKey();

  /// The photo's card has scrolled out from under the status bar: the page shades it.
  final ValueNotifier<bool> _shadeStatusBar = ValueNotifier<bool>(false);
  double _statusBar = 0;
  double? _heroHeight;

  /// Products each block shows: a hidden block takes no room, so its gap goes too.
  final Map<String, int> _blockCounts = <String, int>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _trackView();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _shadeStatusBar.dispose();
    super.dispose();
  }

  void _onScroll() {
    // The list drops the card once it is far out of view: its last height stands.
    final hero = _heroHeight =
        _hero.currentContext?.size?.height ?? _heroHeight;
    _shadeStatusBar.value = hero != null && _scroll.offset > hero - _statusBar;
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
    _statusBar = MediaQuery.paddingOf(context).top;
    return ShopScaffold(
      shadeStatusBar: _shadeStatusBar,
      body: product != null
          ? _details(context, product)
          : Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: _error != null
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(
                              PersonalizationSpacing.paddingX,
                            ),
                            child: ShopRetry(onRetry: _retry),
                          )
                        : const PersonalizationLoader(),
                  ),
                ),
                // There is no bar to go back with, loaded or not.
                const _ShopProductBack(),
              ],
            ),
    );
  }

  Widget _details(BuildContext context, Product product) {
    final card = shopCard(product);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            // From the very top: the photo's card goes under the status bar.
            padding: const EdgeInsets.only(bottom: PersonalizationSpacing.xl3),
            children: [
              _ShopProductHero(key: _hero, product: product, card: card),
              // Each block is hidden until its products arrive, and stays hidden
              // when there are none.
              for (final String code in _productBlocks) ...<Widget>[
                if ((_blockCounts[code] ?? 0) > 0)
                  const SizedBox(height: PersonalizationSpacing.xl3),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PersonalizationSpacing.paddingX,
                  ),
                  child: PersonalizationRecommenderBlock(
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
                ),
              ],
            ],
          ),
        ),
        _ShopBuyBar(
          card: card,
          onAddToCart: () => addToShopCart(
            context,
            widget.shopId,
            widget.productId,
            price: product.price,
          ),
        ),
      ],
    );
  }
}

/// Top of the product page: the photo, the brand, the name and the price on the kit's
/// card, which runs under the status bar and rounds off at the bottom. The back button
/// is over its top and scrolls away with it; the system's back is still there.
class _ShopProductHero extends StatelessWidget {
  const _ShopProductHero({
    super.key,
    required this.product,
    required this.card,
  });

  final Product product;
  final PersonalizationProduct card;

  /// Margin of the photo's square on either side.
  static const double _photoSide = PersonalizationSpacing.xl4;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    // The page shows the full image; `picture` is the copy resized for lists.
    final image = product.imageUrl.isNotEmpty
        ? product.imageUrl
        : (product.picture ?? '');
    final hero = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.backgroundCard,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(theme.radius.modal),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + PersonalizationSpacing.md,
          bottom: PersonalizationSpacing.xl2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A square of the screen's width less the margins, the photo fitted
            // whole into it.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _photoSide),
              child: AspectRatio(
                aspectRatio: 1,
                child: image.isEmpty
                    ? null
                    : Image(
                        image: NetworkImage(image),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
              ),
            ),
            // 8 under the photo's square and 8 over the text.
            const SizedBox(height: PersonalizationSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PersonalizationSpacing.xl2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (card.brand != null) ...[
                    Text(
                      card.brand!,
                      style: shopTextStyle(
                        context,
                        PersonalizationTypography.smDefault,
                        colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: PersonalizationSpacing.sm),
                  ],
                  Text(
                    card.name,
                    style: shopTextStyle(
                      context,
                      PersonalizationTypography.xlEmphasized,
                      colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: PersonalizationSpacing.lg),
                  Wrap(
                    spacing: PersonalizationSpacing.md,
                    runSpacing: PersonalizationSpacing.sm,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Stack(children: [hero, const _ShopProductBack()]);
  }
}

/// The product page's back: over the top left corner, under the status bar.
class _ShopProductBack extends StatelessWidget {
  const _ShopProductBack();

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return Positioned(
      top: safe.top,
      left: safe.left + PersonalizationSpacing.paddingX,
      child: const ShopBackButton(),
    );
  }
}

/// The pinned bottom of the product page: the price (and the old one) and the kit's
/// "Add to cart" across the rest of the width, on the kit's card over a hairline.
/// Clear of the home indicator; in the full demo it sits on the tab bar.
class _ShopBuyBar extends StatelessWidget {
  const _ShopBuyBar({required this.card, required this.onAddToCart});

  final PersonalizationProduct card;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.backgroundCard,
        border: Border(top: BorderSide(color: colors.lineGenericSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PersonalizationSpacing.paddingX,
            vertical: PersonalizationSpacing.lg,
          ),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.price,
                    style: shopTextStyle(
                      context,
                      PersonalizationTypography.lgEmphasized,
                      colors.textPrimary,
                    ),
                  ),
                  if (card.oldPrice != null)
                    Text(
                      card.oldPrice!,
                      style: shopTextStyle(
                        context,
                        PersonalizationTypography.smDefault,
                        colors.textSecondary,
                      ).copyWith(decoration: TextDecoration.lineThrough),
                    ),
                ],
              ),
              const SizedBox(width: PersonalizationSpacing.xl),
              Expanded(
                child: PersonalizationButton(
                  label: shopAddToCartText,
                  onPressed: onAddToCart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
