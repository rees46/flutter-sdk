import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/ui/personalization_ui.dart';
import 'package:rees46_sdk/src/ui/widgets/personalization_results_screen_base.dart'
    show visibleFacets;

/// Facet `f<i>` carried by `i` products, with two values; `single` has one value and
/// the most products.
Map<String, SearchFilter> _facets(int count) => <String, SearchFilter>{
  for (int i = 1; i <= count; i++)
    'f$i': SearchFilter(count: i, values: const <String, int>{'a': 1, 'b': 1}),
  'single': const SearchFilter(count: 1000, values: <String, int>{'a': 1000}),
};

/// Full search with [facets] count of facets shaped as [_facets].
class _FakeHostApi extends pigeon.PersonalizationHostApi {
  _FakeHostApi(this.facets);

  final int facets;

  @override
  Future<String> searchFull(
    String query,
    String? paramsJson,
    String? shopId,
  ) async => jsonEncode(<String, Object>{
    'products': <Object>[
      <String, Object>{'id': '1', 'name': 'Item', 'price': 1},
    ],
    'products_total': 1,
    'filters': <String, Object>{
      for (final entry in _facets(facets).entries)
        entry.key: <String, Object>{
          'count': entry.value.count,
          'values': entry.value.values,
        },
    },
  });

  @override
  Future<void> trackSearch(
    String query,
    List<String>? results,
    String? shopId,
  ) async {}
}

void main() {
  group('visibleFacets', () {
    test(
      'facets with more than one value, commonest first, ten by default',
      () {
        expect(visibleFacets(_facets(12), maxFacets: 10), <String>[
          for (int i = 12; i >= 3; i--) 'f$i',
        ]);
      },
    );

    test('null or zero maxFacets shows all of them', () {
      final all = <String>[for (int i = 12; i >= 1; i--) 'f$i'];
      expect(visibleFacets(_facets(12)), all);
      expect(visibleFacets(_facets(12), maxFacets: 0), all);
    });

    test('equal counts go by name', () {
      const two = SearchFilter(count: 5, values: <String, int>{'a': 1, 'b': 1});
      expect(
        visibleFacets(const <String, SearchFilter>{'b': two, 'a': two}),
        <String>['a', 'b'],
      );
    });

    test('the host list wins, in its order, without the limit', () {
      expect(
        visibleFacets(
          _facets(12),
          wanted: <String>{'f1', 'single', 'missing', 'f7'},
          maxFacets: 2,
        ),
        <String>['f1', 'single', 'f7'],
      );
    });

    test('a facet with checked values stays, after the chosen ones', () {
      expect(
        visibleFacets(
          _facets(12),
          maxFacets: 2,
          checked: <String>{'f1', 'f12'},
        ),
        <String>['f12', 'f11', 'f1'],
      );
    });
  });

  testWidgets('the search filters screen shows the ten commonest facets', (
    tester,
  ) async {
    Future<List<String>> sectionIds(Widget screen) async {
      await tester.pumpWidget(
        MaterialApp(home: SizedBox(width: 400, height: 600, child: screen)),
      );
      await tester.pump();
      tester
          .widget<PersonalizationSearchResultsTitle>(
            find.byType(PersonalizationSearchResultsTitle),
          )
          .onFilters!();
      await tester.pump();
      return tester
          .widget<PersonalizationFilters>(find.byType(PersonalizationFilters))
          .sections
          .map((section) => section.id)
          .toList();
    }

    final sdk = PersonalizationSdk(api: _FakeHostApi(30));
    expect(
      await sectionIds(
        PersonalizationSearchResultsScreen(sdk: sdk, query: 'q'),
      ),
      <String>[for (int i = 30; i >= 21; i--) 'facet:f$i'],
    );
    expect(
      await sectionIds(
        PersonalizationSearchResultsScreen(
          key: const ValueKey<String>('all'),
          sdk: sdk,
          query: 'q',
          maxFacets: null,
        ),
      ),
      hasLength(30),
    );
    expect(
      await sectionIds(
        PersonalizationSearchResultsScreen(
          key: const ValueKey<String>('host'),
          sdk: sdk,
          query: 'q',
          facets: const <String>{'f2', 'f1'},
        ),
      ),
      <String>['facet:f2', 'facet:f1'],
    );
  });
}
