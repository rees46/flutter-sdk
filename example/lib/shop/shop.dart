import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

// The kit stays out of the package barrel until its release; the example reaches
// it directly, which the analyzer flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

/// The recommender block the demo shop serves (api.rees46.ru): the home block and,
/// with the product as `itemId`, the similar products under a product.
const String shopRecommenderCode = 'e6249bb15043644bf25b135006149962';

/// The Stories V2 block the demo shop serves.
const String shopStoriesCode = '115bd0b67cf5989a1b60c841790b2af6';

/// Label of every "add to cart" button of the shop.
const String shopAddToCartText = 'Add to cart';

/// Shown in place of data that did not load, above a Retry button.
const String shopErrorText =
    'Something went wrong. Check your connection and try again.';

const String shopRetryText = 'Retry';

/// "Add to cart" of the demo shop. There is no cart screen: the event goes to
/// tracking and the kit's toast confirms it. A recommender block has already
/// remembered itself as the source when its button was pressed, so the event is
/// attributed to the block.
Future<void> addToShopCart(
  BuildContext context,
  String shopId,
  String itemId, {
  double? price,
}) async {
  try {
    await REES46
        .getInstance(shopId)
        .tracking
        .addToCart(TrackingItem(id: itemId, price: price));
    if (!context.mounted) return;
    PersonalizationToast.show(context, 'Added to cart');
  } catch (error) {
    if (!context.mounted) return;
    PersonalizationToast.show(context, 'Not added to cart: $error');
  }
}

/// Text style of the kit: a step of its scale in a colour of its palette, with the
/// font family the kit's theme sets for that weight.
TextStyle shopTextStyle(BuildContext context, TextStyle step, Color color) {
  final family = PersonalizationTheme.of(context).fontFamily;
  return step.copyWith(
    color: color,
    fontFamily: family.familyFor(step.fontWeight ?? FontWeight.w400),
    package: family.package,
  );
}

/// The kit's ghost back button, as the search results title draws it.
class ShopBackButton extends StatelessWidget {
  const ShopBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PersonalizationButton(
      size: PersonalizationButtonSize.md,
      view: PersonalizationButtonView.ghost,
      iconStart: PersonalizationIcons.arrowLeft,
      iconBuilder: shopIcon,
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

/// Data that did not load: the kit's empty state with [shopErrorText] and a Retry
/// button under it — the way the kit's catalog shows a failed first page.
class ShopRetry extends StatelessWidget {
  const ShopRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PersonalizationEmptyState(message: shopErrorText),
        PersonalizationButton(
          label: shopRetryText,
          size: PersonalizationButtonSize.md,
          view: PersonalizationButtonView.secondary,
          iconStart: PersonalizationIcons.arrowRotateCw,
          iconBuilder: shopIcon,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

/// The kit hands over the asset and the colour it wants; the host picks the renderer.
Widget shopIcon(BuildContext context, String asset, double size, Color color) {
  return SvgPicture.asset(
    asset,
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}
