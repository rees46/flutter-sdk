import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

/// Host API that answers `searchFull` from memory: [total] products, a page of the
/// requested limit at a time. While [hold] is set, answers wait for it.
class _FakeHostApi extends pigeon.PersonalizationHostApi {
  static const int total = 200;

  /// Pages asked for, in order.
  final List<int> pages = <int>[];
  Completer<void>? hold;

  @override
  Future<String> searchFull(
    String query,
    String? paramsJson,
    String? shopId,
  ) async {
    final params = jsonDecode(paramsJson!) as Map<String, dynamic>;
    final page = params['page'] as int;
    final limit = params['limit'] as int;
    pages.add(page);
    await hold?.future;
    final from = (page - 1) * limit;
    return jsonEncode(<String, Object>{
      'products': <Map<String, Object>>[
        for (int i = from; i < from + limit && i < total; i++)
          <String, Object>{'id': '$i', 'name': 'Item $i', 'price': i},
      ],
      'products_total': total,
    });
  }

  @override
  Future<void> trackSearch(
    String query,
    List<String>? results,
    String? shopId,
  ) async {}
}

Widget _host(Widget screen) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 400, height: 600, child: screen),
  ),
);

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(PersonalizationCatalog),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

/// Physics that do not pull an emptied list back into range by themselves, as the
/// platform defaults do: the jump to the top has to come from the screen.
class _PlainScrollBehavior extends ScrollBehavior {
  const _PlainScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

/// Every card that exists, on screen or in the cache area around it.
int _cards() => find
    .byType(PersonalizationProductCard, skipOffstage: false)
    .evaluate()
    .length;

void main() {
  late _FakeHostApi api;
  late PersonalizationSdk sdk;

  setUp(() {
    api = _FakeHostApi();
    sdk = PersonalizationSdk(api: api);
  });

  testWidgets('infinite scroll asks for the next page half a screen before '
      'the end, once', (tester) async {
    await tester.pumpWidget(
      _host(
        PersonalizationSearchResultsScreen(
          sdk: sdk,
          query: 'jacket',
          infiniteScroll: true,
        ),
      ),
    );
    await tester.pump();
    expect(api.pages, <int>[1]);

    final position = _position(tester);
    position.jumpTo(100);
    await tester.pump();
    expect(api.pages, <int>[1]);

    api.hold = Completer<void>();
    position.jumpTo(
      position.maxScrollExtent - position.viewportDimension / 2 + 1,
    );
    await tester.pump();
    expect(api.pages, <int>[1, 2]);

    // The page is still in flight: scrolling on does not ask for it again.
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(api.pages, <int>[1, 2]);

    // Once it is in, the next approach to the end asks for the one after.
    api.hold!.complete();
    api.hold = null;
    await tester.pump();
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(api.pages, <int>[1, 2, 3]);
  });

  testWidgets('ten loaded pages keep a screenful of cards, not two hundred', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PersonalizationSearchResultsScreen(
          sdk: sdk,
          query: 'jacket',
          infiniteScroll: true,
        ),
      ),
    );
    await tester.pump();

    for (int i = 0; i < 100 && api.pages.length < 10; i++) {
      final position = _position(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
    }
    expect(api.pages, <int>[for (int page = 1; page <= 10; page++) page]);
    // Settle at the real end: the extent of a lazy list is an estimate.
    for (int i = 0; i < 50; i++) {
      final position = _position(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      if (position.pixels == position.maxScrollExtent) break;
    }

    expect(find.text('Item 199'), findsOneWidget);
    expect(_cards(), inInclusiveRange(1, 30));
  });

  testWidgets('a new query starts from the top', (tester) async {
    Widget screen(String query) => _host(
      ScrollConfiguration(
        behavior: const _PlainScrollBehavior(),
        child: PersonalizationSearchResultsScreen(sdk: sdk, query: query),
      ),
    );
    await tester.pumpWidget(screen('jacket'));
    await tester.pump();
    _position(tester).jumpTo(1000);
    await tester.pump();
    expect(_position(tester).pixels, 1000);

    await tester.pumpWidget(screen('coat'));
    await tester.pump();

    expect(_position(tester).pixels, 0);
    expect(api.pages, <int>[1, 1]);
  });
}
