import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_theme_mode.dart';
// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

/// "UI Kit" screen — the design system, one exhibit per component.
///
/// "Components" walks through the primitives in every size, view and state the
/// design file defines; "Blocks" shows the compositions built from them
/// (product cards, recommender layouts, instant search, the catalogue, the filters screen,
/// in-app popups, the toast, the loyalty card);
/// "Search" runs the two data-bound search widgets against the demo shop: the
/// instant search field, and the results screen it opens on submit;
/// "Stories" shows the Stories V2 components one by one, a sample viewer that runs
/// offline and the live stories block of the demo shop.
/// Mirror of the Android `UiKitPane` / iOS `UIKitShowcaseViewController` /
/// React Native `UiKitPane`.
///
/// The kit does not draw SVG itself: every icon comes back through an
/// `iconBuilder`, rendered here with flutter_svg. Product data is static and
/// images are plain [ImageProvider]s — the kit does not fetch or format
/// anything.
class UiKitPane extends StatelessWidget {
  const UiKitPane({super.key, required this.shopId});

  /// Shop the Search and Stories tabs' widgets resolve their SDK instance by.
  final String shopId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('UI Kit'),
          actions: const <Widget>[_AppearanceSwitch()],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Components'),
              Tab(text: 'Blocks'),
              Tab(text: 'Search'),
              Tab(text: 'Stories'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Showcase(exhibits: _componentExhibits),
            _Showcase(exhibits: _blockExhibits),
            _SearchFlow(shopId: shopId),
            _Showcase(exhibits: _storyExhibits(shopId)),
          ],
        ),
      ),
    );
  }
}

/// Switch cycling the app between the system scheme, light and dark.
///
/// It writes to [appThemeMode], which [MaterialApp] listens to, so the whole
/// demo repaints — the kit's components included, since their palette comes
/// from the theme extension attached to each [ThemeData].
class _AppearanceSwitch extends StatelessWidget {
  const _AppearanceSwitch();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => TextButton(
        onPressed: () => appThemeMode.value = nextThemeMode(mode),
        child: Text(themeModeLabel(mode)),
      ),
    );
  }
}

/// The search flow as a host would wire it: the instant search field resolves the SDK by
/// shopId and searches on its own; submitting a phrase swaps it for the results screen,
/// whose back button returns. Taps on products and categories only show a snackbar —
/// navigation is the host's.
class _SearchFlow extends StatefulWidget {
  const _SearchFlow({required this.shopId});

  final String shopId;

  @override
  State<_SearchFlow> createState() => _SearchFlowState();
}

class _SearchFlowState extends State<_SearchFlow> {
  String? _query;
  String? _sortBy;
  String? _sortDir;

  void _say(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final query = _query;
    if (query == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: PersonalizationInstantSearchField(
          shopId: widget.shopId,
          placeholder: 'Search',
          cancelText: 'Cancel',
          recentLabel: 'Recent searches',
          clearText: 'Clear',
          moreText: 'more',
          categoriesLabel: 'Categories',
          productsLabel: 'Products',
          onSubmit: (text) => setState(() => _query = text),
          onProductTap: (product) => _say('Product: ${product.name}'),
          onCategoryTap: (category) => _say('Category: ${category.name}'),
          onError: (error) => _say('Search error: $error'),
          iconBuilder: _icon,
        ),
      );
    }
    return PersonalizationSearchResultsScreen(
      shopId: widget.shopId,
      query: query,
      sortBy: _sortBy,
      sortDir: _sortDir,
      productActionText: 'Add to cart',
      onBack: () => setState(() => _query = null),
      onProductTap: (product) => _say('Product: ${product.name}'),
      onProductAction: (product) => _say('Add to cart: ${product.name}'),
      // No sort picker in the design file: cycle relevance → price ↑ → price ↓ on tap.
      onSortTap: () => setState(() {
        if (_sortBy == null) {
          _sortBy = 'price';
          _sortDir = 'asc';
        } else if (_sortDir == 'asc') {
          _sortDir = 'desc';
        } else {
          _sortBy = null;
          _sortDir = null;
        }
      }),
      onError: (error) => _say('Search error: $error'),
      iconBuilder: _icon,
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
  _Exhibit('Link — text action next to a field or a label', (context) {
    return _Row(
      children: [
        PersonalizationLink(label: 'Cancel', onTap: () {}),
        PersonalizationLink(label: 'Clear', onTap: () {}),
      ],
    );
  }),
  _Exhibit(
    'Search Results Title',
    (context) => const _SearchResultsTitleExhibit(),
  ),
  _Exhibit('Accordion — collapsed with count, expanded', (context) {
    return _Column(
      children: [
        PersonalizationAccordion(label: 'Brand', count: 12, iconBuilder: _icon),
        PersonalizationAccordion(
          label: 'Size',
          expanded: true,
          iconBuilder: _icon,
        ),
      ],
    );
  }),
  _Exhibit(
    'List Label',
    (context) => const PersonalizationListLabel(label: 'Popular categories'),
  ),
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
        PersonalizationTag(
          label: 'Nike',
          onRemove: () {},
          removeIconBuilder: _removeIcon,
        ),
        PersonalizationTag(
          label: 'Size 42',
          view: PersonalizationTagView.secondary,
          onRemove: () {},
          removeIconBuilder: _removeIcon,
        ),
        const PersonalizationTag(
          label: 'Running',
          view: PersonalizationTagView.secondary,
        ),
      ],
    );
  }),
  _Exhibit(
    'Checkbox — unchecked, checked, indeterminate, disabled; with label',
    (context) {
      return const _Column(
        children: [
          _Row(
            children: [
              PersonalizationCheckbox(
                state: PersonalizationCheckboxState.unchecked,
              ),
              PersonalizationCheckbox(
                state: PersonalizationCheckboxState.checked,
              ),
              PersonalizationCheckbox(
                state: PersonalizationCheckboxState.indeterminate,
              ),
              PersonalizationCheckbox(
                state: PersonalizationCheckboxState.checked,
                disabled: true,
              ),
            ],
          ),
          PersonalizationCheckboxWithLabel(
            label: 'In stock only',
            state: PersonalizationCheckboxState.checked,
          ),
        ],
      );
    },
  ),
  _Exhibit('Dots, Count, Rating', (context) {
    return _Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PersonalizationDots(count: 5, selectedIndex: 1),
        const PersonalizationCount(
          prefix: 'Showing',
          shown: 12,
          separator: 'of',
          total: 128,
        ),
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
        for (final (index, aspect)
            in PersonalizationProductImageAspect.values.indexed)
          SizedBox(
            width: 104,
            child: PersonalizationProductImage(
              aspect: aspect,
              image: _products[index].image,
            ),
          ),
      ],
    );
  }),
  _Exhibit(
    'Empty State',
    (context) => const PersonalizationEmptyState(
      message: 'No results for your request.',
    ),
  ),
  _Exhibit('Barcode — Code 128', (context) {
    // The barcode brings no background of its own: scanners want white in
    // either theme, so it sits on a white box, as it does on the loyalty card.
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(PersonalizationRadius.lg),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: PersonalizationBarcode(code: _loyaltyCardNumber),
        ),
      ),
    );
  }),
  _Exhibit('Icons — the full set, 24 dp', (context) {
    final color = PersonalizationTheme.of(context).colors.textPrimary;
    return _ScrollRow(
      children: [
        for (final asset in PersonalizationIcons.all)
          _icon(context, asset, 24, color),
      ],
    );
  }),
];

final List<_Exhibit> _blockExhibits = [
  _Exhibit('Product Card — carousel, grid, list', (context) {
    return _Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 220,
          child: _card(PersonalizationProductCardType.carousel, _products[0]),
        ),
        SizedBox(
          width: 161,
          child: _card(PersonalizationProductCardType.grid, _products[1]),
        ),
        _card(PersonalizationProductCardType.list, _products[2]),
      ],
    );
  }),
  _Exhibit('Product Card — image 4:3, 1:1, 3:4 (carousel and list)', (context) {
    const aspects = [
      PersonalizationProductImageAspect.landscape,
      PersonalizationProductImageAspect.square,
      PersonalizationProductImageAspect.portrait,
    ];
    return _Column(
      children: [
        _ScrollRow(
          children: [
            for (final (index, aspect) in aspects.indexed)
              SizedBox(
                width: 220,
                child: _card(
                  PersonalizationProductCardType.carousel,
                  _products[index + 3],
                  aspect: aspect,
                ),
              ),
          ],
        ),
        for (final (index, aspect) in aspects.indexed)
          _card(
            PersonalizationProductCardType.list,
            _products[index + 3],
            aspect: aspect,
          ),
      ],
    );
  }),
  _Exhibit('Recommender Block — carousel', (context) {
    return _recommender(
      PersonalizationProductsLayout.carousel,
      'Recommended for you',
      _products,
    );
  }),
  _Exhibit('Recommender Block — grid', (context) {
    return _recommender(
      PersonalizationProductsLayout.grid,
      'Similar products',
      _products.take(4).toList(),
    );
  }),
  _Exhibit('Recommender Block — list', (context) {
    return _recommender(
      PersonalizationProductsLayout.list,
      'Recently viewed',
      _products.take(3).toList(),
    );
  }),
  _Exhibit(
    'Instant Search — recent searches',
    (context) => const _InstantSearchExhibit(),
  ),
  _Exhibit(
    'Instant Search — typing, matches in bold',
    (context) => const _InstantSearchExhibit(typing: true),
  ),
  _Exhibit(
    'Instant Search — with images',
    (context) => const _InstantSearchExhibit(images: true),
  ),
  _Exhibit(
    'Catalog — header, grid ⇄ list, count, load more',
    (context) => const _CatalogExhibit(),
  ),
  _Exhibit(
    'Catalog — empty state',
    (context) => const PersonalizationCatalog(
      header: _SearchResultsTitleExhibit(count: 0),
      products: [],
      emptyText: 'No results for your request.',
      iconBuilder: _icon,
      // Inside the showcase's scroll: laid out whole, no scrolling of its own.
      scrollable: false,
    ),
  ),
  _Exhibit(
    'Filters — range, checkbox lists with show more, reset / apply',
    (context) => _filters(),
  ),
  _Exhibit(
    'In App Popup — image, one button',
    (context) => _inAppPopup(context, PersonalizationInAppPopupView.image),
  ),
  _Exhibit(
    'In App Popup — image background, both buttons',
    (context) => _inAppPopup(
      context,
      PersonalizationInAppPopupView.imageBackground,
      closeText: 'Not now',
    ),
  ),
  _Exhibit(
    'In App Popup — text only, close button with text',
    (context) => _inAppPopup(
      context,
      PersonalizationInAppPopupView.text,
      closeText: 'Maybe later',
    ),
  ),
  _Exhibit(
    'In App Popup — icon, no buttons (cross only)',
    (context) => _inAppPopup(
      context,
      PersonalizationInAppPopupView.icon,
      actionText: null,
    ),
  ),
  _Exhibit(
    'In App Popup, fullscreen — image',
    (context) => _inAppPopup(
      context,
      PersonalizationInAppPopupView.image,
      fullscreen: true,
    ),
  ),
  _Exhibit(
    'In App Popup, fullscreen — image background, both buttons',
    (context) => _inAppPopup(
      context,
      PersonalizationInAppPopupView.imageBackground,
      closeText: 'Not now',
      fullscreen: true,
    ),
  ),
  _Exhibit(
    'In App Popup, fullscreen — text only',
    (context) => _inAppPopup(
      context,
      PersonalizationInAppPopupView.text,
      fullscreen: true,
    ),
  ),
  _Exhibit(
    'In App Popup, fullscreen — icon',
    (context) => _inAppPopup(
      context,
      PersonalizationInAppPopupView.icon,
      fullscreen: true,
    ),
  ),
  _Exhibit('Toast — top and bottom', (context) {
    return _Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PersonalizationToast(text: 'Copied'),
        _ScrollRow(
          children: [
            PersonalizationButton(
              label: 'Show at the bottom',
              size: PersonalizationButtonSize.md,
              view: PersonalizationButtonView.secondary,
              onPressed: () => PersonalizationToast.show(context, 'Copied'),
            ),
            PersonalizationButton(
              label: 'Show at the top',
              size: PersonalizationButtonSize.md,
              view: PersonalizationButtonView.secondary,
              onPressed: () => PersonalizationToast.show(
                context,
                'Code copied to clipboard',
                position: PersonalizationToastPosition.top,
              ),
            ),
          ],
        ),
      ],
    );
  }),
  _Exhibit(
    'Loyalty Card — light, stamps 0 of 5',
    (context) => _loyaltyCard(context, stamps: 0),
  ),
  _Exhibit(
    'Loyalty Card — brand colour, stamps 4 of 5',
    (context) => _loyaltyCard(context, stamps: 4, brand: true),
  ),
];

/// The Stories V2 block the demo shop serves (api.rees46.ru).
const String _storiesCode = '115bd0b67cf5989a1b60c841790b2af6';

/// End of the timer exhibits: fixed on first use, so a rebuild does not restart them.
final DateTime _timerEnd = DateTime.now().add(
  const Duration(days: 2, hours: 18, minutes: 33, seconds: 24),
);

List<_Exhibit> _storyExhibits(String shopId) => [
  _Exhibit(
    'Stories — live block $_storiesCode (demo shop); '
    'links open in the system browser',
    (context) => PersonalizationStories(
      code: _storiesCode,
      shopId: shopId,
      padding: EdgeInsets.zero,
      promoCopiedText: 'Code copied to clipboard',
      onProductClick: (product) =>
          PersonalizationToast.show(context, 'Product: ${product.name}'),
      onError: (error) => _snack(context, 'Stories error: $error'),
      iconBuilder: _icon,
    ),
  ),
  _Exhibit(
    'Story Viewer — sample slides: price, promo code, discount, text blocks, '
    'used products (offline)',
    (context) => Align(
      alignment: Alignment.centerLeft,
      child: PersonalizationButton(
        label: 'Open sample stories',
        size: PersonalizationButtonSize.md,
        onPressed: () => _openSampleStories(context),
      ),
    ),
  ),
  _Exhibit('Story Cover — default, pinned, viewed, skeleton', (context) {
    return _ScrollRow(
      children: [
        PersonalizationStoryCover(image: _image('jacket')),
        PersonalizationStoryCover(
          image: _image('jacket'),
          pinned: true,
          iconBuilder: _icon,
        ),
        PersonalizationStoryCover(
          image: _image('jacket'),
          state: PersonalizationStoryCoverState.viewed,
        ),
        const PersonalizationStoryCover(
          state: PersonalizationStoryCoverState.skeleton,
        ),
      ],
    );
  }),
  _Exhibit('Story Cover — segments: 5 slides, 2 seen', (context) {
    return _ScrollRow(
      children: [
        PersonalizationStoryCover(
          image: _image('sneakers'),
          segments: 5,
          seenSegments: const {0, 1},
        ),
        PersonalizationStoryCover(
          image: _image('sneakers'),
          pinned: true,
          segments: 5,
          seenSegments: const {0, 1},
          iconBuilder: _icon,
        ),
        PersonalizationStoryCover(
          image: _image('sneakers'),
          state: PersonalizationStoryCoverState.viewed,
          segments: 5,
          seenSegments: const {0, 1, 2, 3, 4},
        ),
      ],
    );
  }),
  _Exhibit('Story Preview and Stories Bar — pinned, default, viewed', (
    context,
  ) {
    return PersonalizationStoriesBar(
      padding: EdgeInsets.zero,
      items: [
        PersonalizationStoryItem(
          id: '1',
          label: 'Pinned',
          image: _image('watch'),
          pinned: true,
          segments: 3,
        ),
        PersonalizationStoryItem(
          id: '2',
          label: 'Default',
          image: _image('headphones'),
          segments: 4,
          seenSegments: const {0},
        ),
        PersonalizationStoryItem(
          id: '3',
          label: 'Viewed',
          image: _image('backpack'),
          viewed: true,
        ),
        PersonalizationStoryItem(
          id: '4',
          label: 'A label too long for one line',
          image: _image('bottle'),
        ),
      ],
      onItemTap: (item) => _snack(context, 'Story: ${item.label}'),
      iconBuilder: _icon,
    );
  }),
  _Exhibit(
    'Stories Bar — loading',
    (context) => const PersonalizationStoriesBar(
      loading: true,
      padding: EdgeInsets.zero,
    ),
  ),
  _Exhibit(
    'Story Progress — 5 slides, the second at 40%',
    (context) =>
        const PersonalizationStoryProgress(count: 5, current: 1, progress: 0.4),
  ),
  _Exhibit('Story Navigation — progress and the cross', (context) {
    return PersonalizationStoryNavigation(
      count: 5,
      current: 1,
      progress: 0.4,
      onClose: () => _snack(context, 'Close'),
      iconBuilder: _icon,
    );
  }),
  _Exhibit('Story Price — price, discount, promo code, long promo code', (
    context,
  ) {
    return _Column(
      children: [
        const PersonalizationStoryPrice(
          price: '1 190 900 ₽',
          oldPrice: '245 000 ₽',
        ),
        const PersonalizationStoryPrice(
          type: PersonalizationStoryPriceType.discount,
          price: '1 190 900 ₽',
          oldPrice: '245 000 ₽',
          discount: '10%',
        ),
        PersonalizationStoryPrice(
          type: PersonalizationStoryPriceType.promoCode,
          price: '1 190 900 ₽',
          oldPrice: '245 000 ₽',
          promoCode: 'PROMO',
          iconBuilder: _icon,
        ),
        PersonalizationStoryPrice(
          type: PersonalizationStoryPriceType.promoCode,
          price: '1 190 900 ₽',
          oldPrice: '245 000 ₽',
          promoCode: 'YAGODA-MALINA',
          copiedText: 'Code copied to clipboard',
          onPromoCopied: (code) => _snack(context, 'Copied: $code'),
          iconBuilder: _icon,
        ),
      ],
    );
  }),
  _Exhibit('Story Timer — merged and separate', (context) {
    return _Column(
      children: [
        PersonalizationStoryTimer(endTime: _timerEnd),
        PersonalizationStoryTimer(
          endTime: _timerEnd,
          view: PersonalizationStoryTimerView.separate,
        ),
      ],
    );
  }),
  _Exhibit(
    'Story Text Block — solid large / medium / small, transparent; '
    'on a media slide (dark tokens)',
    (context) => _OnMediaSlide(
      child: _Column(
        children: [
          const PersonalizationStoryTextBlock(
            text: 'Open eat dear winding belonging.',
            size: PersonalizationStoryTextSize.large,
            background: Color(0xFF16AE13),
          ),
          PersonalizationStoryTextBlock(
            text: 'Open eat dear winding belonging though differed stand left.',
            background: PersonalizationColors.light.semanticWarning,
          ),
          PersonalizationStoryTextBlock(
            text: 'Open eat dear winding belonging though differed stand left.',
            size: PersonalizationStoryTextSize.small,
            background: PersonalizationColors.light.semanticInfo,
          ),
          const PersonalizationStoryTextBlock(
            text: 'Open eat dear winding belonging.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  ),
  _Exhibit(
    'Story Used Products — collapsed with the sound button, expanded',
    (context) => _OnMediaSlide(
      padding: EdgeInsets.zero,
      child: _Column(
        children: [
          const _SoundedUsedProducts(),
          PersonalizationStoryUsedProducts(
            products: _products.take(4).toList(),
            showText: 'Used products',
            hideText: 'Hide products',
            initiallyExpanded: true,
            onProductTap: (product) =>
                _snack(context, 'Product: ${product.name}'),
            iconBuilder: _icon,
          ),
        ],
      ),
    ),
  ),
  _Exhibit('Badge "Sale!" — LG warning, as on the Action slides', (context) {
    return const _Row(children: [PersonalizationBadge(label: 'Sale!')]);
  }),
];

/// A stand-in for a media slide: a photo under the kit's dark tokens, the way the
/// viewer renders image and video slides.
class _OnMediaSlide extends StatelessWidget {
  const _OnMediaSlide({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(extensions: [PersonalizationTheme.dark]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PersonalizationRadius.xl2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: _image('jacket'),
              fit: BoxFit.cover,
              colorFilter: const ColorFilter.mode(
                Color(0x66000000),
                BlendMode.darken,
              ),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Collapsed used products with a working mute toggle at the start of the row.
class _SoundedUsedProducts extends StatefulWidget {
  const _SoundedUsedProducts();

  @override
  State<_SoundedUsedProducts> createState() => _SoundedUsedProductsState();
}

class _SoundedUsedProductsState extends State<_SoundedUsedProducts> {
  bool _muted = true;

  @override
  Widget build(BuildContext context) {
    return PersonalizationStoryUsedProducts(
      products: _products.take(4).toList(),
      showText: 'Used products',
      hideText: 'Hide products',
      leading: PersonalizationStorySoundButton(
        muted: _muted,
        onPressed: () => setState(() => _muted = !_muted),
        iconBuilder: _icon,
      ),
      iconBuilder: _icon,
    );
  }
}

/// Photos of the sample stories ship with the app: `asset:<name>` stands for
/// `assets/uikit/<name>.jpg`, anything else loads from the network.
ImageProvider _sampleImage(String url) => url.startsWith('asset:')
    ? _image(url.substring('asset:'.length))
    : NetworkImage(url);

Map<String, dynamic> _sampleProductSlide(
  String id,
  Map<String, dynamic> product,
) => {
  'id': id,
  'duration': 6,
  'type': '',
  'elements': [
    {'type': 'button', 'title': 'More info', 'link': 'https://example.com'},
    {'type': 'product', 'item': product},
  ],
};

/// Stories in the server's shape, so the sample runs through the same parsing as
/// the live block: product slides of every price kind, and a media slide with text
/// blocks, a button and used products.
final List<Story> _sampleStories = StoriesBlock.fromJson({
  'id': 'sample',
  'stories': [
    {
      'id': 'products',
      'name': 'Products',
      'avatar': 'asset:headphones',
      'slides': [
        _sampleProductSlide('price', {
          'id': 'h1',
          'brand': 'Sony',
          'name': 'Wireless over-ear headphones, noise cancelling',
          'picture': 'asset:headphones',
          'price': 299,
          'price_formatted': r'299 $',
          'oldprice': 349,
          'oldprice_formatted': r'349 $',
          'url': 'https://example.com/headphones',
        }),
        _sampleProductSlide('promo', {
          'id': 'w1',
          'brand': 'Garmin',
          'name': 'GPS running watch',
          'picture': 'asset:watch',
          'price': 449,
          'price_formatted': r'449 $',
          'oldprice': 499,
          'oldprice_formatted': r'499 $',
          'promocode': 'YAGODA-MALINA',
          'price_with_promocode_formatted': r'399 $',
          'url': 'https://example.com/watch',
        }),
        _sampleProductSlide('discount', {
          'id': 's1',
          'brand': 'Nike',
          'name': 'Air Zoom Pegasus 41 running shoes',
          'picture': 'asset:pegasus',
          'price': 140,
          'price_formatted': r'140 $',
          'oldprice': 165,
          'oldprice_formatted': r'165 $',
          'discount_percent': 15,
          'url': 'https://example.com/pegasus',
        }),
      ],
    },
    {
      'id': 'media',
      'name': 'Media',
      'avatar': 'asset:jacket',
      'slides': [
        {
          'id': 'text',
          'duration': 8,
          'type': 'image',
          'background': 'asset:jacket',
          'elements': [
            {
              'type': 'text_block',
              'text_input': 'Open eat dear winding belonging.',
              'font_size': 36,
              'text_background_color': '#16AE13',
              'text_background_color_opacity': '100%',
              'y_offset': 9,
            },
            {
              'type': 'text_block',
              'text_input': 'Tap to copy the code SALE10',
              'font_size': 20,
              'text_align': 'center',
              'text_background_color': '#0087E8',
              'text_background_color_opacity': '100%',
              'y_offset': 30,
              'promocode': 'SALE10',
            },
            {
              'type': 'text_block',
              'text_input': 'Open eat dear winding belonging though differed.',
              'font_size': 24,
              'y_offset': 45,
            },
            {
              'type': 'button',
              'title': 'Go shopping',
              'link': 'https://example.com',
            },
            {
              'type': 'products',
              'labels': {
                'show_carousel': 'Used products',
                'hide_carousel': 'Hide products',
              },
              'products': [
                for (final (index, name) in [
                  'backpack',
                  'bottle',
                  'sunglasses',
                ].indexed)
                  {
                    'id': 'm$index',
                    'brand': 'Brand',
                    'name': 'Product ${index + 1}',
                    'picture': 'asset:$name',
                    'price': 99,
                    'price_formatted': r'99 $',
                    'oldprice': 120,
                    'oldprice_formatted': r'120 $',
                    'discount_percent': 18,
                  },
              ],
            },
          ],
        },
      ],
    },
  ],
}).stories;

void _openSampleStories(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PersonalizationStoryViewer.route(
      PersonalizationStoryViewer(
        stories: _sampleStories,
        // No SDK: the sample does not track; links and products come back here.
        onLinkClick: (url) => PersonalizationToast.show(context, 'Link: $url'),
        onProductClick: (product) =>
            PersonalizationToast.show(context, 'Product: ${product.name}'),
        promoCopiedText: 'Code copied to clipboard',
        imageProvider: _sampleImage,
        iconBuilder: _icon,
      ),
    ),
  );
}

void _snack(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

/// The popup as the SDK will hand it over: the host supplies the image and wires the
/// two callbacks. Fixed height here only because the showcase is a scrolling column —
/// on screen the popup is sized by whoever presents it.
Widget _inAppPopup(
  BuildContext context,
  PersonalizationInAppPopupView view, {
  String? actionText = 'Action',
  String? closeText,
  bool fullscreen = false,
}) {
  return SizedBox(
    // Полноэкранному нужно больше места: отступы и кегли там на ступень крупнее.
    height: fullscreen ? 620 : 460,
    child: PersonalizationInAppPopup(
      view: view,
      presentation: fullscreen
          ? PersonalizationInAppPopupPresentation.fullscreen
          : PersonalizationInAppPopupPresentation.modal,
      title: 'Pizza ipsum dolor meat lovers',
      text: 'Cheese ranch Philly roll pepperoni hand thin garlic bacon.',
      actionText: actionText,
      closeText: closeText,
      image:
          view == PersonalizationInAppPopupView.text ||
              view == PersonalizationInAppPopupView.icon
          ? null
          : _image('jacket'),
      icon: const Icon(
        Icons.verified_user,
        size: 100,
        color: Color(0xFF16AE13),
      ),
      iconBuilder: _icon,
      onAction: () => _snack(context, 'Popup action'),
      onClose: () => _snack(context, 'Popup closed'),
    ),
  );
}

/// The card number the loyalty exhibits encode.
const String _loyaltyCardNumber = '2000012345678';

/// The loyalty card as a host fills it. The SDK's loyalty status carries only
/// membership and the level, so the balance, the stamps and the card number
/// are the host's own data; the logo, stripe and emblem are demo art bundled
/// with the example — brand art does not ship in the SDK.
Widget _loyaltyCard(
  BuildContext context, {
  required int stamps,
  bool brand = false,
}) {
  // Semantic/Info, as in the design file's dark example.
  final brandBlue = PersonalizationTheme.of(context).colors.semanticInfo;
  const white = Color(0xFFFFFFFF);
  // The kit never tints the host's logo, so the demo tints it itself to the
  // content colour: Text/Primary by default, white on the brand card.
  final content = brand
      ? white
      : PersonalizationTheme.of(context).colors.textPrimary;
  return PersonalizationLoyaltyCard(
    logo: Image.asset('assets/uikit/loyalty_logo.png', color: content),
    balanceLabel: 'Бонусы',
    balanceValue: '50 550',
    stripe: const AssetImage('assets/uikit/loyalty_stripe.jpg'),
    emblem: const AssetImage('assets/uikit/loyalty_emblem.png'),
    stamps: stamps,
    stampsTotal: 5,
    fields: const [
      PersonalizationLoyaltyCardField(label: 'Владелец', value: 'Олег'),
      PersonalizationLoyaltyCardField(label: 'Уровень', value: 'Базовый'),
    ],
    code: _loyaltyCardNumber,
    cardColor: brand ? brandBlue : null,
    contentColor: brand ? white : null,
    iconBuilder: _icon,
  );
}

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
  const _SearchResultsTitleExhibit({this.count = 128});

  final int count;

  @override
  State<_SearchResultsTitleExhibit> createState() =>
      _SearchResultsTitleExhibitState();
}

class _SearchResultsTitleExhibitState
    extends State<_SearchResultsTitleExhibit> {
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    return PersonalizationSearchResultsTitle(
      title: 'Sneakers',
      selectedViewIndex: _view,
      onViewChanged: (index) => setState(() => _view = index),
      onBack: () {},
      onFilters: () {},
      onSort: () {},
      results: PersonalizationSearchResults(
        prefix: 'Found',
        count: widget.count,
        suffix: 'products',
      ),
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
/// Instant search in its three states: recent searches before typing, suggestions with the
/// query highlighted while typing, and rows with images. The host owns the data; the kit only
/// renders what it is given and reports the taps.
class _InstantSearchExhibit extends StatefulWidget {
  const _InstantSearchExhibit({this.typing = false, this.images = false});

  final bool typing;
  final bool images;

  @override
  State<_InstantSearchExhibit> createState() => _InstantSearchExhibitState();
}

class _InstantSearchExhibitState extends State<_InstantSearchExhibit> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.typing ? 'boots' : '',
  );
  List<String> _recent = [
    'mens winter boots',
    'kids shoes',
    'bag',
    'accessories',
    'black boots',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typing = widget.typing;
    return PersonalizationInstantSearch(
      controller: _controller,
      placeholder: 'want to buy...',
      cancelText: 'Cancel',
      onCancel: () {},
      showImages: widget.images,
      recentLabel: typing ? null : 'Recent searches',
      clearText: 'Clear',
      onClearRecent: () => setState(() => _recent = []),
      recentSearches: typing ? const [] : _recent,
      moreText: 'more',
      onMoreRecent: () {},
      onRecentRemove: (item) =>
          setState(() => _recent = _recent.where((it) => it != item).toList()),
      suggestions: typing
          ? const [
              'winter',
              'mens',
              'kids',
              'for outdoor',
              'womens',
              'low',
              'black',
              'orange',
            ]
          : const [],
      categoriesLabel: typing ? 'Category' : 'Popular category',
      categories: typing
          ? const [
              PersonalizationSuggestion(id: 'c1', title: 'Womens boots'),
              PersonalizationSuggestion(id: 'c2', title: 'Mens boots'),
              PersonalizationSuggestion(id: 'c3', title: 'Kids boots'),
            ]
          : [
              // The design gives categories pictures too. Photos other than the
              // three products below, so the two sections do not repeat each other.
              PersonalizationSuggestion(
                id: 'c1',
                title: 'Running shoes',
                subtitle: 'Shoes',
                image: _image('sneakers'),
              ),
              PersonalizationSuggestion(
                id: 'c2',
                title: 'Running apparel',
                subtitle: 'Clothing',
                image: _image('jacket'),
              ),
              PersonalizationSuggestion(
                id: 'c3',
                title: 'Trail gear',
                subtitle: 'Outdoor',
                image: _image('watch'),
              ),
            ],
      productsLabel: typing ? 'Products' : 'Frequently searched',
      products: typing
          ? const [
              PersonalizationSuggestion(id: 'p1', title: 'winter womens boots'),
              PersonalizationSuggestion(id: 'p2', title: 'boots for mens'),
              PersonalizationSuggestion(
                id: 'p3',
                title: 'winter boots for mens',
              ),
              PersonalizationSuggestion(id: 'p4', title: 'kids winter boots'),
            ]
          : [
              for (final p in _products.take(widget.images ? 3 : 5))
                PersonalizationSuggestion(
                  id: p.id,
                  title: p.name,
                  subtitle: p.price,
                  image: p.image,
                ),
            ],
      onCategoryTap: (_) {},
      onProductTap: (_) {},
      iconBuilder: _icon,
    );
  }
}

class _CatalogExhibit extends StatefulWidget {
  const _CatalogExhibit();

  @override
  State<_CatalogExhibit> createState() => _CatalogExhibitState();
}

/// The catalogue as a host would wire it: the category title (title + view switch, as on
/// the CatalogGrid page) sits in the header slot and drives the grid/list switch. The
/// search results title with back, filters and sort belongs to the search flow.
class _CatalogExhibitState extends State<_CatalogExhibit> {
  PersonalizationProductsLayout _layout = PersonalizationProductsLayout.grid;
  int _view = 0;
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
      header: PersonalizationTitle(
        title: 'Sneakers',
        trailing: PersonalizationButtonGroup(
          size: PersonalizationButtonGroupSize.md,
          selectedIndex: _view,
          onSelected: (index) => setState(() {
            _view = index;
            _layout = index == 0
                ? PersonalizationProductsLayout.grid
                : PersonalizationProductsLayout.list;
          }),
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
        ),
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
      // Inside the showcase's scroll: laid out whole, no scrolling of its own.
      scrollable: false,
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
  const _Column({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

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
  return _icon(
    context,
    asset,
    16,
    PersonalizationTheme.of(context).colors.textPrimary,
  );
}

/// The filters screen with the sections from the design file; toggles and ranges update its own state.
Widget _filters() {
  const colors = [
    'All',
    'Black',
    'White',
    'Red',
    'Light blue',
    'Green',
    'Yellow',
    'Brown',
    'Grey',
    'Pink',
  ];
  const ratings = ['All', '5 stars', '4+ stars', '3+ stars'];
  return PersonalizationFilters(
    title: 'Filters',
    onClose: () {},
    resetText: 'Reset',
    applyText: 'Apply',
    onReset: () {},
    onApply: (_) {},
    sections: [
      const PersonalizationFilterRange(
        id: 'size',
        title: 'Size',
        fromLabel: 'From',
        toLabel: 'to',
        from: '42',
        to: '43',
        select: true,
      ),
      PersonalizationFilterOptions(
        id: 'colors',
        title: 'Colors',
        options: [
          for (final (index, label) in colors.indexed)
            PersonalizationFilterOption(
              id: label.toLowerCase(),
              label: label,
              checked: index == 1,
            ),
        ],
        showMoreText: 'Show more',
        showLessText: 'Show less',
      ),
      const PersonalizationFilterRange(
        id: 'price',
        title: 'Price (USD)',
        fromLabel: 'From',
        toLabel: 'to',
        from: '50',
        to: '500',
      ),
      PersonalizationFilterOptions(
        id: 'rating',
        title: 'Rating',
        options: [
          for (final (index, label) in ratings.indexed)
            PersonalizationFilterOption(
              id: label,
              label: label,
              checked: index == 1,
            ),
        ],
      ),
    ],
    iconBuilder: _icon,
  );
}

Widget _card(
  PersonalizationProductCardType type,
  PersonalizationProduct product, {
  PersonalizationProductImageAspect aspect =
      PersonalizationProductImageAspect.square,
}) {
  return PersonalizationProductCard(
    type: type,
    image: product.image,
    imageAspect: aspect,
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

Widget _recommender(
  PersonalizationProductsLayout layout,
  String title,
  List<PersonalizationProduct> products,
) {
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

/// Photos ship with the app: the showcase must not depend on the network.
ImageProvider _image(String seed) => AssetImage('assets/uikit/$seed.jpg');

/// Static products for the exhibits. Strings arrive formatted — that is the kit's contract.
final List<PersonalizationProduct> _products = [
  PersonalizationProduct(
    id: '1',
    name: 'Air Zoom Pegasus 41 running shoes',
    price: r'$140',
    image: _image('pegasus'),
    brand: 'Nike',
    rating: const PersonalizationProductRating(value: '4.7', reviews: 128),
    oldPrice: r'$165',
    discount: '-15%',
    actionText: 'Add to cart',
  ),
  PersonalizationProduct(
    id: '2',
    name: 'Wireless over-ear headphones',
    price: r'$299',
    image: _image('headphones'),
    brand: 'Sony',
    rating: const PersonalizationProductRating(value: '4.8', reviews: 2140),
    actionText: 'Add to cart',
  ),
  PersonalizationProduct(
    id: '3',
    name: 'Everyday backpack 20 L',
    price: r'$89',
    image: _image('backpack'),
    brand: 'Peak Design',
    rating: const PersonalizationProductRating(value: '4.6', reviews: 412),
    oldPrice: r'$110',
    discount: '-19%',
    actionText: 'Add to cart',
  ),
  PersonalizationProduct(
    id: '4',
    name: 'Trail running jacket',
    price: r'$175',
    image: _image('jacket'),
    brand: 'Salomon',
    rating: const PersonalizationProductRating(value: '4.5', reviews: 77),
    actionText: 'Add to cart',
  ),
  PersonalizationProduct(
    id: '5',
    name: 'Polarized sunglasses',
    price: r'$120',
    image: _image('sunglasses'),
    brand: 'Oakley',
    rating: const PersonalizationProductRating(value: '4.4', reviews: 305),
    oldPrice: r'$150',
    discount: '-20%',
    actionText: 'Add to cart',
  ),
  PersonalizationProduct(
    id: '6',
    name: 'Insulated bottle 750 ml',
    price: r'$35',
    image: _image('bottle'),
    brand: 'Hydro Flask',
    rating: const PersonalizationProductRating(value: '4.9', reviews: 980),
    actionText: 'Add to cart',
  ),
  PersonalizationProduct(
    id: '7',
    name: 'GPS running watch',
    price: r'$449',
    image: _image('watch'),
    brand: 'Garmin',
    rating: const PersonalizationProductRating(value: '4.7', reviews: 1532),
    actionText: 'Add to cart',
  ),
  PersonalizationProduct(
    id: '8',
    name: 'Court sneakers',
    price: r'$95',
    image: _image('sneakers'),
    brand: 'Adidas',
    rating: const PersonalizationProductRating(value: '4.3', reviews: 64),
    oldPrice: r'$120',
    discount: '-21%',
    actionText: 'Add to cart',
  ),
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
