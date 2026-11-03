import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
// ignore: implementation_imports
import 'package:rees46_sdk/src/ui/personalization_ui.dart';
import 'package:rees46_sdk_example/demo_app.dart';
import 'package:rees46_sdk_example/main_shop.dart';

void main() {
  testWidgets('the shop-only demo opens the shop, without the tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const ShopApp());

    expect(find.widgetWithText(AppBar, 'Shop'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('REES46 SDK init demo'), findsNothing);
    expect(REES46.isInitialized(demoShopId), isTrue);
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

/// Drops the shop and runs out the timeouts of its requests, which have no host here.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 1));
}
