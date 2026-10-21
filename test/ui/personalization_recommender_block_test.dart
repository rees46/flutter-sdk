import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/ui/personalization_ui.dart';
import 'package:rees46_sdk/src/ui/widgets/personalization_request_cache.dart';

const String _code = 'e6249bb15043644bf25b135006149962';

/// A live answer from test/fixtures without its pictures: images do not load in
/// widget tests.
Map<String, dynamic> _fixture(String name, String list) {
  final json =
      jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
          as Map<String, dynamic>;
  for (final product in json[list] as List<dynamic>) {
    (product as Map<String, dynamic>)
      ..remove('picture')
      ..remove('image_url')
      ..remove('image_url_resized');
  }
  return json;
}

/// Host API that answers recommendations (title «Популярные», two products, the
/// first discounted) and collections from the fixtures. While [hold] is set,
/// answers wait for it; while [failure] is set, they fail with it.
class _FakeHostApi extends pigeon.PersonalizationHostApi {
  Map<String, dynamic> recommendation = _fixture(
    'recommend_extended',
    'recommends',
  );
  Map<String, dynamic> collection = _fixture('products', 'products');

  /// `paramsJson` of every recommendation request, in order.
  final List<String?> recommendations = <String?>[];
  final List<String> collections = <String>[];
  final List<pigeon.TrackingSourceWire> sources = <pigeon.TrackingSourceWire>[];
  Completer<void>? hold;
  Object? failure;

  @override
  Future<String> getRecommendation(
    String code,
    String? paramsJson,
    String? shopId,
  ) async {
    recommendations.add(paramsJson);
    await hold?.future;
    if (failure != null) throw failure!;
    return jsonEncode(recommendation);
  }

  @override
  Future<String> getCollection(String collectionId, String? shopId) async {
    collections.add(collectionId);
    await hold?.future;
    if (failure != null) throw failure!;
    return jsonEncode(collection);
  }

  @override
  Future<void> trackSetSource(
    pigeon.TrackingSourceWire source,
    String? shopId,
  ) async {
    sources.add(source);
  }
}

Widget _host(Widget block) => MaterialApp(
  home: SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(key: Key('above'), height: 10),
        block,
        const SizedBox(key: Key('below'), height: 10),
      ],
    ),
  ),
);

/// Cards of a list take the screen's width: the test font draws every glyph a
/// square, and the live prices do not fit a carousel card in it.
const PersonalizationProductsLayout _list = PersonalizationProductsLayout.list;

final Finder _block = find.byType(PersonalizationProductsBlock);
final Finder _cards = find.byType(PersonalizationProductCard);

/// The answer arrives, and the block fades in.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

/// Opacity of the block's fade-in.
double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.ancestor(of: _block, matching: find.byType(FadeTransition)).first,
    )
    .opacity
    .value;

/// Space the block takes between its neighbours.
double _gap(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const Key('below'))).dy -
    tester.getBottomLeft(find.byKey(const Key('above'))).dy;

void main() {
  late _FakeHostApi api;
  late PersonalizationSdk sdk;

  setUp(() {
    PersonalizationRequestCache.shared.clear();
    api = _FakeHostApi();
    sdk = PersonalizationSdk(api: api);
  });

  group('title', () {
    testWidgets('comes from the answer', (tester) async {
      await tester.pumpWidget(
        _host(
          PersonalizationRecommenderBlock(code: _code, layout: _list, sdk: sdk),
        ),
      );
      await _settle(tester);
      expect(find.text('Популярные'), findsOneWidget);
      expect(_cards, findsNWidgets(2));
    });

    testWidgets('of the host wins over the answer', (tester) async {
      await tester.pumpWidget(
        _host(
          PersonalizationRecommenderBlock(
            code: _code,
            layout: _list,
            sdk: sdk,
            title: 'For you',
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('For you'), findsOneWidget);
      expect(find.text('Популярные'), findsNothing);
    });

    testWidgets('empty — no title row', (tester) async {
      await tester.pumpWidget(
        _host(
          PersonalizationRecommenderBlock(
            code: _code,
            layout: _list,
            sdk: sdk,
            title: '',
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(PersonalizationTitle), findsNothing);
      expect(_cards, findsNWidgets(2));
    });
  });

  group('hidden', () {
    testWidgets('while loading: no block and no space', (tester) async {
      api.hold = Completer<void>();
      await tester.pumpWidget(
        _host(
          PersonalizationRecommenderBlock(code: _code, layout: _list, sdk: sdk),
        ),
      );
      await tester.pump();
      expect(_block, findsNothing);
      expect(_gap(tester), 0);

      // The answer is in: the block takes its place and fades in.
      api.hold!.complete();
      await tester.pump();
      await tester.pump();
      expect(_block, findsOneWidget);
      expect(_gap(tester), greaterThan(0));
      expect(_opacity(tester), lessThan(1));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_opacity(tester), 1);
    });

    testWidgets('fewer products than minProducts — onLoaded(0)', (
      tester,
    ) async {
      final loaded = <int>[];
      await tester.pumpWidget(
        _host(
          PersonalizationRecommenderBlock(
            code: _code,
            layout: _list,
            sdk: sdk,
            minProducts: 3,
            onLoaded: loaded.add,
          ),
        ),
      );
      await _settle(tester);
      expect(_block, findsNothing);
      expect(_gap(tester), 0);
      expect(loaded, <int>[0]);
    });

    testWidgets('an empty answer — onLoaded(0)', (tester) async {
      api.recommendation = <String, dynamic>{
        'title': 'Популярные',
        'recommends': <Object>[],
      };
      final loaded = <int>[];
      await tester.pumpWidget(
        _host(
          PersonalizationRecommenderBlock(
            code: _code,
            layout: _list,
            sdk: sdk,
            minProducts: 0,
            onLoaded: loaded.add,
          ),
        ),
      );
      await _settle(tester);
      expect(_block, findsNothing);
      expect(loaded, <int>[0]);
    });

    testWidgets('an error — onError, no onLoaded', (tester) async {
      api.failure = StateError('offline');
      final errors = <Object>[];
      final loaded = <int>[];
      await tester.pumpWidget(
        _host(
          PersonalizationRecommenderBlock(
            code: _code,
            layout: _list,
            sdk: sdk,
            onLoaded: loaded.add,
            onError: errors.add,
          ),
        ),
      );
      await _settle(tester);
      expect(_block, findsNothing);
      expect(_gap(tester), 0);
      expect(errors.single, isStateError);
      expect(loaded, isEmpty);
    });

    testWidgets('an unknown shop — onError', (tester) async {
      final errors = <Object>[];
      await tester.pumpWidget(
        _host(
          PersonalizationRecommenderBlock(
            code: _code,
            layout: _list,
            shopId: 'no-such-shop',
            onError: errors.add,
          ),
        ),
      );
      await _settle(tester);
      expect(_block, findsNothing);
      expect(errors.single, isA<UnknownShopIdException>());
    });
  });

  testWidgets('limit cuts the answer on the client', (tester) async {
    final loaded = <int>[];
    await tester.pumpWidget(
      _host(
        PersonalizationRecommenderBlock(
          code: _code,
          layout: _list,
          sdk: sdk,
          limit: 1,
          onLoaded: loaded.add,
        ),
      ),
    );
    await _settle(tester);
    expect(_cards, findsOneWidget);
    expect(loaded, <int>[1]);
  });

  testWidgets('a second block with the same parameters shows the cached '
      'answer in its first frame, without a request', (tester) async {
    await tester.pumpWidget(
      _host(
        PersonalizationRecommenderBlock(code: _code, layout: _list, sdk: sdk),
      ),
    );
    await _settle(tester);
    expect(api.recommendations, hasLength(1));

    // The feed recreated the cell: a new state, same parameters.
    final loaded = <int>[];
    await tester.pumpWidget(
      _host(
        PersonalizationRecommenderBlock(
          key: const Key('again'),
          code: _code,
          layout: _list,
          sdk: sdk,
          onLoaded: loaded.add,
        ),
      ),
    );
    expect(_cards, findsNWidgets(2));
    expect(_opacity(tester), 1);
    await _settle(tester);
    expect(api.recommendations, hasLength(1));
    expect(loaded, <int>[2]);
  });

  testWidgets(
    'reload goes past the cache and keeps the block until the answer',
    (tester) async {
      final controller = PersonalizationRecommenderBlockController();
      final loaded = <int>[];
      await tester.pumpWidget(
        _host(
          PersonalizationRecommenderBlock(
            code: _code,
            layout: _list,
            sdk: sdk,
            controller: controller,
            onLoaded: loaded.add,
          ),
        ),
      );
      await _settle(tester);

      api.hold = Completer<void>();
      var done = false;
      unawaited(controller.reload().then((_) => done = true));
      await tester.pump();
      expect(api.recommendations, hasLength(2));
      expect(_cards, findsNWidgets(2));
      expect(done, isFalse);

      api.recommendation['recommends'] = <Object?>[
        (api.recommendation['recommends'] as List<dynamic>).first,
      ];
      api.hold!.complete();
      await _settle(tester);
      expect(done, isTrue);
      expect(_cards, findsOneWidget);
      expect(loaded, <int>[2, 1]);
    },
  );

  testWidgets('new parameters load again', (tester) async {
    Widget block(String itemId) => _host(
      PersonalizationRecommenderBlock(
        code: _code,
        layout: _list,
        sdk: sdk,
        itemId: itemId,
      ),
    );
    await tester.pumpWidget(block('1'));
    await _settle(tester);
    await tester.pumpWidget(block('2'));
    await _settle(tester);
    expect(
      api.recommendations.map(
        (params) => (jsonDecode(params!) as Map<String, dynamic>)['item_id'],
      ),
      <String>['1', '2'],
    );
  });

  testWidgets('a tap sets the dynamic source with the code, then calls the '
      'host with the mapped product', (tester) async {
    final tapped = <PersonalizationProduct>[];
    await tester.pumpWidget(
      _host(
        PersonalizationRecommenderBlock(
          code: _code,
          layout: _list,
          sdk: sdk,
          onProductTap: (product) {
            // The source is asked for before the host hears of the tap.
            expect(api.sources, hasLength(1));
            tapped.add(product);
          },
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(_cards.first);
    await tester.pump();

    expect(api.sources.single.type, 'dynamic');
    expect(api.sources.single.code, _code);
    final product = tapped.single;
    expect(product.id, '52173');
    expect(product.price, '164 990 ₽');
    expect(product.oldPrice, '174 990 ₽');
    expect(product.discount, '-6%');
    expect(
      product.deeplink,
      'https://www.technodom.kz/p/holodilnik-beko-rdsk-mw-52173',
    );
    expect(product.url, startsWith('https://www.technodom.kz/p/holodilnik'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a collection: no title of its own, no source on a tap', (
    tester,
  ) async {
    final tapped = <PersonalizationProduct>[];
    await tester.pumpWidget(
      _host(
        PersonalizationRecommenderBlock.collection(
          collectionId: '42',
          layout: _list,
          sdk: sdk,
          actionText: 'Buy',
          onProductTap: tapped.add,
        ),
      ),
    );
    await _settle(tester);
    expect(api.collections, <String>['42']);
    expect(api.recommendations, isEmpty);
    expect(find.byType(PersonalizationTitle), findsNothing);
    expect(_cards, findsNWidgets(2));
    expect(find.text('Buy'), findsNWidgets(2));

    await tester.tap(_cards.first);
    await tester.pump();
    expect(tapped.single.id, '300252');
    expect(api.sources, isEmpty);
  });
}
