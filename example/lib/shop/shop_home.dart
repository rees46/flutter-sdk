import 'package:flutter/material.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

import '../demo_app.dart';
import 'shop.dart';
import 'shop_category.dart';
import 'shop_product.dart';
import 'shop_products.dart';
import 'shop_search_field.dart';

/// "Shop" — a demo shop built from the kit and the public SDK methods: the way a
/// host would integrate them. It is the home of the "Shop" tab (see `DemoTabs`) and
/// the whole app of `main_shop.dart`.
/// Home has its header with the popups menu and the search button, the stories bar,
/// the recommender block and the top-level categories; the search button turns home
/// into the instant search. From there the category, product and search screens go on
/// the tab's own navigator, so they open under the tab bar and back walks them in
/// reverse. No screen of the shop has an app bar: each starts under the status bar.
/// "Add to cart" sends the cart event and shows a toast — there is no cart screen.
///
/// The Android, iOS and React Native demos build the same shop.
class ShopPane extends StatefulWidget {
  const ShopPane({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopPane> createState() => _ShopPaneState();
}

/// Height of a row of the categories group.
const double _categoryRowHeight = 52;

class _ShopPaneState extends State<ShopPane> {
  /// Top-level categories; `null` while they load.
  List<ProductCategory>? _categories;
  Object? _categoriesError;

  /// Products of the recommender block: hidden, it takes no room, so its gap goes too.
  int _popularCount = 0;

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
    final colors = PersonalizationTheme.of(context).colors;
    final safe = MediaQuery.paddingOf(context);
    return ShopScaffold(
      // Search mode puts the field in place of the header and the panel under it.
      body: ShopSearchField(
        shopId: widget.shopId,
        builder: (context, field, searching, search) => SingleChildScrollView(
          padding: EdgeInsets.only(
            top: safe.top + PersonalizationSpacing.md,
            bottom: safe.bottom + PersonalizationSpacing.xl4,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PersonalizationSpacing.paddingX,
                ),
                child: searching
                    ? field
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Shop',
                              style: shopTextStyle(
                                context,
                                PersonalizationTypography.xl3Emphasized,
                                colors.textPrimary,
                              ),
                            ),
                          ),
                          _ShopPopupsMenu(shopId: widget.shopId),
                          const SizedBox(width: PersonalizationSpacing.md),
                          ShopRoundButton(
                            icon: PersonalizationIcons.magnifier,
                            label: 'Search',
                            onPressed: search,
                          ),
                        ],
                      ),
              ),
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
    const side = EdgeInsets.symmetric(
      horizontal: PersonalizationSpacing.paddingX,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: PersonalizationSpacing.lg),
        // Collapses when the block is empty or fails. The bar runs edge to edge, its
        // covers start at the page's margin. A product of a story closes the viewer
        // and opens here. Over API v3: slides with a link have "Share", and the link
        // goes out in the demo scheme, which opens the campaign in the app. A button's
        // link to the game opens the game here.
        PersonalizationStories(
          code: shopStoriesCode,
          shopId: shopId,
          padding: side,
          promoCopiedText: shopPromoCopiedText,
          onLinkClick: demoStoriesLinkClick(shopId),
          onProductClick: (product) =>
              ShopProductScreen.open(context, shopId, product.id),
          iconBuilder: shopIcon,
          apiV3Domain: demoStoriesApiV3Domain,
          shareUrlTransform: demoShareUrl,
        ),
        if (_popularCount > 0)
          const SizedBox(height: PersonalizationSpacing.xl3),
        // Title from the response; hidden until its products arrive. The card button
        // remembers the block as the source before the cart event goes out.
        Padding(
          padding: side,
          child: PersonalizationRecommenderBlock(
            code: shopRecommenderCode,
            shopId: shopId,
            actionText: shopAddToCartText,
            onLoaded: (count) {
              if (mounted && _popularCount != count) {
                setState(() => _popularCount = count);
              }
            },
            onProductTap: (product) =>
                ShopProductScreen.open(context, shopId, product.id),
            onProductAction: (product) =>
                addToShopCart(context, shopId, product.id),
            iconBuilder: shopIcon,
          ),
        ),
        Padding(padding: side, child: _categoriesSection(context)),
      ],
    );
  }

  /// "Categories": the kit's title over a group of rows. Hidden whole while there
  /// are none; a failure shows the shop's retry in place of the group.
  Widget _categoriesSection(BuildContext context) {
    final categories = _categories;
    final Widget content;
    if (_categoriesError != null) {
      content = ShopRetry(onRetry: _retryCategories);
    } else if (categories == null) {
      content = const Center(child: PersonalizationLoader());
    } else if (categories.isEmpty) {
      return const SizedBox.shrink();
    } else {
      content = _ShopCategoryGroup(
        shopId: widget.shopId,
        categories: categories,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: PersonalizationSpacing.xl3),
        // The same title as the recommender block's.
        const PersonalizationTitle(title: 'Categories'),
        const SizedBox(height: PersonalizationSpacing.lg),
        content,
      ],
    );
  }
}

/// "Show popup" of the header: a menu of the demo's popups v3 ([demoManualPopups]) on
/// the kit's floating surface, under the button and level with its right edge. The
/// picked one is shown by hand — no trigger, screens or frequency, and with the
/// automatic presentation off too.
class _ShopPopupsMenu extends StatelessWidget {
  const _ShopPopupsMenu({required this.shopId});

  final String shopId;

  /// The menu's surface over the page.
  static const double _elevation = 8;

  Future<void> _open(BuildContext context) async {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final left = button.localToGlobal(Offset.zero, ancestor: overlay).dx;
    final top =
        button
            .localToGlobal(
              button.size.bottomLeft(Offset.zero),
              ancestor: overlay,
            )
            .dy +
        PersonalizationSpacing.md;
    // A line under the button: the menu opens below it, on the side with more room.
    final under = Rect.fromLTWH(left, top, button.size.width, 0);
    final id = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(under, Offset.zero & overlay.size),
      color: colors.backgroundFloat,
      shadowColor: colors.shadowHeavy,
      elevation: _elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radius.xl2),
      ),
      items: [
        for (final popup in demoManualPopups)
          PopupMenuItem<int>(
            value: popup.id,
            child: Text(
              popup.label,
              style: shopTextStyle(
                context,
                PersonalizationTypography.baseDefault,
                colors.textPrimary,
              ),
            ),
          ),
      ],
    );
    if (id == null) return;
    try {
      await REES46.getInstance(shopId).popups.show(id);
    } catch (error) {
      debugPrint('Shop: popup $id not shown — $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShopRoundButton(
      icon: PersonalizationIcons.rosette,
      label: 'Show popup',
      onPressed: () => _open(context),
    );
  }
}

/// Categories as one group on the kit's card: the kit's category rows, a hairline
/// between them, the whole row opens its category.
class _ShopCategoryGroup extends StatelessWidget {
  const _ShopCategoryGroup({required this.shopId, required this.categories});

  final String shopId;
  final List<ProductCategory> categories;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.radius.card),
      child: ColoredBox(
        color: colors.backgroundCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, category) in categories.indexed) ...[
              if (index > 0)
                SizedBox(
                  height: 1,
                  child: ColoredBox(color: colors.lineGenericSubtle),
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ShopCategoryScreen.open(
                  context,
                  shopId,
                  category.id,
                  category.name,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: _categoryRowHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PersonalizationSpacing.paddingX,
                    ),
                    child: Center(
                      child: PersonalizationSuggestionRow(
                        kind: PersonalizationSuggestionKind.category,
                        title: category.name,
                        iconBuilder: shopIcon,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens a stories "Share" link over the shop, as its home stories would: over API v3,
/// a story's product opens on the product page, a button's link to the game the game.
/// `false` — not a stories link.
bool openShopStoriesLink(BuildContext context, String url, String shopId) =>
    PersonalizationStories.handleLink(
      context,
      url,
      shopId: shopId,
      promoCopiedText: shopPromoCopiedText,
      onLinkClick: demoStoriesLinkClick(shopId),
      onProductClick: (product) =>
          ShopProductScreen.open(context, shopId, product.id),
      onError: (error) =>
          PersonalizationToast.show(context, 'Stories link error: $error'),
      iconBuilder: shopIcon,
      apiV3Domain: demoStoriesApiV3Domain,
      shareUrlTransform: demoShareUrl,
    );
