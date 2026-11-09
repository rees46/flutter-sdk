import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

/// The recommender block the demo shop serves (api.rees46.ru) that has products:
/// "Популярные" on home and under a product.
const String shopRecommenderCode = 'e6249bb15043644bf25b135006149962';

/// Product page blocks driven by the product (`itemId`): "Похожие" and
/// "С этим товаром также покупают".
const String shopSimilarCode = '007b87897f244b2a2a123567b3242a4b';
const String shopAlsoBoughtCode = 'fa6e8cd83434273dd8d47293329e00dd';

/// The Stories V2 block the demo shop serves (API v3): one campaign with a poll of every
/// kind on its slides.
const String shopStoriesCode = '272dd914ea13824a0abb6ef4e776ddaa';

/// Label of every "add to cart" button of the shop.
const String shopAddToCartText = 'Add to cart';

/// Shown in place of data that did not load, above a Retry button.
const String shopErrorText =
    'Something went wrong. Check your connection and try again.';

const String shopRetryText = 'Retry';

/// Toast of a promo code a story copied.
const String shopPromoCopiedText = 'Code copied';

/// "Add to cart" of the demo shop. There is no cart screen: the kit's toast confirms
/// the tap and the event goes to tracking, whose failure only reaches the log — as in
/// the native demos. A recommender block has already remembered itself as the source
/// when its button was pressed, so the event is attributed to the block.
Future<void> addToShopCart(
  BuildContext context,
  String shopId,
  String itemId, {
  double? price,
}) async {
  PersonalizationToast.show(context, 'Added to cart');
  try {
    await REES46
        .getInstance(shopId)
        .tracking
        .addToCart(TrackingItem(id: itemId, price: price));
  } catch (error) {
    debugPrint('Shop: add to cart not tracked — $error');
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

/// A screen of the shop: the kit's generic background and no app bar — the content
/// starts under the status bar, whose icons follow the kit's scheme: dark on the light
/// one, light on the dark one. What scrolls up goes under a shade of the background
/// behind the status bar instead of under its icons.
class ShopScaffold extends StatelessWidget {
  const ShopScaffold({super.key, required this.body, this.shadeStatusBar});

  final Widget body;

  /// When the shade is on; `null` — always. The product page turns it on only once
  /// its photo's card is gone from under the status bar.
  final ValueListenable<bool>? shadeStatusBar;

  static const Duration _shadeFade = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    final dark = PersonalizationTheme.brightnessOf(context) == Brightness.dark;
    final shade = ColoredBox(color: colors.backgroundGeneric);
    final toggle = shadeStatusBar;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.backgroundTransparent,
        // iOS takes the brightness of what is under the bar, Android of its icons.
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundGeneric,
        body: Stack(
          children: [
            Positioned.fill(child: body),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top,
              child: IgnorePointer(
                child: toggle == null
                    ? shade
                    : ValueListenableBuilder<bool>(
                        valueListenable: toggle,
                        builder: (context, on, child) => AnimatedOpacity(
                          opacity: on ? 1 : 0,
                          duration: _shadeFade,
                          child: child,
                        ),
                        child: shade,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A kit results screen (category, search) as a screen of the shop: its title 8 under
/// the status bar, where the shop's own screens start. The screen's feed pads itself
/// by 16, so the screen goes up by the difference; the bottom keeps clear of the home
/// indicator.
class ShopResultsPage extends StatelessWidget {
  const ShopResultsPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(
        top: math.max(
          0,
          top + PersonalizationSpacing.md - PersonalizationSpacing.xl,
        ),
      ),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}

/// A round icon button of the shop's screens without a bar: one of the kit's icons on
/// [background] — the kit's card unless given.
class ShopRoundButton extends StatelessWidget {
  const ShopRoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.background,
    this.mirrored = false,
  });

  /// The kit's icon asset ([PersonalizationIcons]).
  final String icon;

  /// What a screen reader calls the button.
  final String label;

  final VoidCallback onPressed;
  final Color? background;

  /// Flipped left to right: the kit draws its chevron to the right only.
  final bool mirrored;

  /// A touch target of the platforms' minimum.
  static const double size = 44;

  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background ?? colors.backgroundCard,
            shape: BoxShape.circle,
          ),
          child: Transform.flip(
            flipX: mirrored,
            child: shopIcon(context, icon, _iconSize, colors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Back of a screen without a bar: the round button on the kit's generic background
/// with the kit's chevron turned to the left.
class ShopBackButton extends StatelessWidget {
  const ShopBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShopRoundButton(
      icon: PersonalizationIcons.angleLargeRight,
      mirrored: true,
      label: 'Back',
      background: PersonalizationTheme.of(context).colors.backgroundGeneric,
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
