import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';
import 'package:rees46_sdk_example/demo_app.dart';
import 'package:rees46_sdk_example/main_shop.dart';
import 'package:rees46_sdk_example/shop/shop.dart';

void main() {
  testWidgets('the shop-only demo opens the shop, without the tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const ShopApp());

    // No app bar: the home's own heading starts under the status bar.
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('REES46 SDK init demo'), findsNothing);
    expect(REES46.isInitialized(demoShopId), isTrue);
    await _unmount(tester);
  });

  testWidgets('home searches behind the button of its header', (tester) async {
    await tester.pumpWidget(const ShopApp());
    expect(find.byType(PersonalizationInstantSearchField), findsNothing);

    await tester.tap(_round('Search'));
    await tester.pump();
    await tester.pump();
    // The field takes the header's place, focused, and the rest of home steps aside.
    expect(find.text('Shop'), findsNothing);
    expect(find.byType(PersonalizationInstantSearchField), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(find.byType(PersonalizationStories).hitTestable(), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Shop'), findsOneWidget);
    expect(find.byType(PersonalizationInstantSearchField), findsNothing);

    // Back closes the search, not the screen.
    await tester.tap(_round('Search'));
    await tester.pump();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(find.text('Shop'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('the popups menu of the header lists the demo popups', (
    tester,
  ) async {
    await tester.pumpWidget(const ShopApp());

    // The home's loaders keep animating: pumps of a set length, not until it settles.
    await tester.tap(_round('Show popup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    for (final popup in demoManualPopups) {
      expect(find.text(popup.label), findsOneWidget);
    }

    // A pick closes the menu; the popup itself comes from the server.
    await tester.tap(find.text(demoManualPopups.first.label));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(demoManualPopups.first.label), findsNothing);
    await _unmount(tester);
  });

  testWidgets('the shop home stories share over API v3 in the demo scheme', (
    tester,
  ) async {
    await tester.pumpWidget(const ShopApp());

    final stories = tester.widget<PersonalizationStories>(
      find.byType(PersonalizationStories),
    );
    expect(stories.ownApiV3Domain, demoStoriesApiV3Domain);
    expect(
      stories.shareUrlTransform!(
        'https://demo.rees46.ru/?r46_stories=c&r46_story=40&r46_slide=37',
      ),
      'rees46flutter://demo.rees46.ru/?r46_stories=c&r46_story=40&r46_slide=37',
    );
    await _unmount(tester);
  });
}

/// The round button of the shop's header called [label].
Finder _round(String label) => find.byWidgetPredicate(
  (widget) => widget is ShopRoundButton && widget.label == label,
);

/// Drops the shop and runs out the timeouts of its requests, which have no host here.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 1));
}
