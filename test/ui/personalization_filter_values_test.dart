import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/ui/widgets/personalization_results_screen_base.dart'
    show facetValueLabel, jsonValueTitle;

/// A value that is an object with a title, as stickers come in a feed.
const String _sticker =
    '{"slug": "super_price", "title": "Суперцена", "text_color": "#ffffff", '
    '"background_color": "#f48012", "priority": 1}';

/// One page answer of search and category alike: brands with counts, colours and
/// sizes (search only) and shop facets, one of them with object values.
Map<String, Object> _answer() => <String, Object>{
  'products': <Object>[
    <String, Object>{'id': '1', 'name': 'Item', 'price': 1},
  ],
  'products_total': 1,
  'brands': <Object>[
    <String, Object>{'name': 'Bosch', 'count': 3},
    // A bare name, as iOS sends the brands of a full search: no count.
    'Philips',
  ],
  'industrial_filters': <String, Object>{
    'colors': <Object>[
      <String, Object>{'color': 'red', 'count': 4},
      <String, Object>{'color': 'blue'},
    ],
    'fashion_sizes': <Object>[
      <String, Object>{'size': '42', 'count': 2},
    ],
  },
  'filters': <String, Object>{
    'stickers': <String, Object>{
      'count': 9,
      'values': <String, int>{_sticker: 5, 'new': 4},
    },
    'product_type': <String, Object>{
      'count': 8,
      'values': <String, int>{'regular': 6, 'digital': 2},
    },
  },
};

class _FakeHostApi extends pigeon.PersonalizationHostApi {
  /// The filters JSON of each request.
  final List<Map<String, dynamic>> params = <Map<String, dynamic>>[];

  @override
  Future<String> searchFull(
    String query,
    String? paramsJson,
    String? shopId,
  ) async {
    params.add(jsonDecode(paramsJson!) as Map<String, dynamic>);
    return jsonEncode(_answer());
  }

  @override
  Future<String> getCategory(
    String category,
    int? limit,
    int? page,
    String? paramsJson,
    String? shopId,
  ) async {
    params.add(
      paramsJson == null
          ? <String, dynamic>{}
          : jsonDecode(paramsJson) as Map<String, dynamic>,
    );
    return jsonEncode(_answer());
  }

  @override
  Future<void> trackSearch(
    String query,
    List<String>? results,
    String? shopId,
  ) async {}

  @override
  Future<void> trackCategoryView(String categoryId, String? shopId) async {}
}

Widget _host(Widget screen) =>
    MaterialApp(home: SizedBox(width: 400, height: 600, child: screen));

/// Opens the filters and returns the labels of each options section by its id.
Future<Map<String, List<String>>> _labels(WidgetTester tester) async {
  tester
      .widget<PersonalizationSearchResultsTitle>(
        find.byType(PersonalizationSearchResultsTitle),
      )
      .onFilters!();
  await tester.pump();
  return <String, List<String>>{
    for (final section
        in tester
            .widget<PersonalizationFilters>(find.byType(PersonalizationFilters))
            .sections)
      if (section is PersonalizationFilterOptions)
        section.id: <String>[
          for (final option in section.options) option.label,
        ],
  };
}

void main() {
  group('jsonValueTitle', () {
    test('an object with a title is labelled by the title', () {
      expect(jsonValueTitle(_sticker), 'Суперцена');
      expect(jsonValueTitle('  {"title": "Hit"}  '), 'Hit');
    });

    test('anything else is shown as it is', () {
      for (final value in <String>[
        'regular',
        '{"title": "Hit"',
        '{"slug": "hit"}',
        '{"title": 1}',
        '{"title": "  "}',
        '["title"]',
        '',
      ]) {
        expect(jsonValueTitle(value), isNull, reason: value);
      }
    });
  });

  test('a label from the host comes first, then the title, then the value', () {
    String? host(String facet, String value) =>
        facet == 'product_type' && value == 'digital' ? 'Цифровой' : null;

    expect(facetValueLabel('product_type', 'digital', host), 'Цифровой');
    expect(facetValueLabel('product_type', 'regular', host), 'regular');
    expect(facetValueLabel('stickers', _sticker, host), 'Суперцена');
    expect(facetValueLabel('stickers', _sticker, (_, _) => ''), 'Суперцена');
    expect(facetValueLabel('stickers', _sticker, (_, _) => 'Mine'), 'Mine');
    expect(facetValueLabel('stickers', 'new', null), 'new');
  });

  late _FakeHostApi api;
  late PersonalizationSdk sdk;

  setUp(() {
    api = _FakeHostApi();
    sdk = PersonalizationSdk(api: api);
  });

  testWidgets('search: titles of object values and product counts next to '
      'brands, colours, sizes and facet values', (tester) async {
    await tester.pumpWidget(
      _host(PersonalizationSearchResultsScreen(sdk: sdk, query: 'q')),
    );
    await tester.pump();

    final labels = await _labels(tester);
    expect(labels['brands'], <String>['Bosch (3)', 'Philips']);
    expect(labels['colors'], <String>['red (4)', 'blue']);
    expect(labels['sizes'], <String>['42 (2)']);
    expect(labels['facet:stickers'], <String>['new (4)', 'Суперцена (5)']);
    expect(labels['facet:product_type'], <String>[
      'digital (2)',
      'regular (6)',
    ]);
  });

  testWidgets('showValueCounts off leaves the counts out', (tester) async {
    await tester.pumpWidget(
      _host(
        PersonalizationSearchResultsScreen(
          sdk: sdk,
          query: 'q',
          showValueCounts: false,
        ),
      ),
    );
    await tester.pump();

    final labels = await _labels(tester);
    expect(labels['brands'], <String>['Bosch', 'Philips']);
    expect(labels['colors'], <String>['red', 'blue']);
    expect(labels['facet:stickers'], <String>['new', 'Суперцена']);
  });

  testWidgets('category: the request carries the original value, the tag its '
      'title without a count', (tester) async {
    await tester.pumpWidget(
      _host(
        PersonalizationCategoryScreen(
          sdk: sdk,
          categoryId: 'c',
          titleText: 'C',
        ),
      ),
    );
    await tester.pump();

    final labels = await _labels(tester);
    expect(labels['brands'], <String>['Bosch (3)', 'Philips']);
    expect(labels['facet:stickers'], <String>['new (4)', 'Суперцена (5)']);

    final filters = tester.widget<PersonalizationFilters>(
      find.byType(PersonalizationFilters),
    );
    filters.onApply!(<PersonalizationFilterSection>[
      for (final section in filters.sections)
        if (section is PersonalizationFilterOptions &&
            section.id == 'facet:stickers')
          section.copyWith(
            options: <PersonalizationFilterOption>[
              for (final option in section.options)
                option.copyWith(checked: option.id == _sticker),
            ],
          )
        else
          section,
    ]);
    await tester.pump();

    expect(api.params.last['filters'], <String, Object>{
      'stickers': <String>[_sticker],
    });
    final tags = tester
        .widget<PersonalizationSearchResultsTitle>(
          find.byType(PersonalizationSearchResultsTitle),
        )
        .filters;
    expect(tags.map((tag) => tag.label), <String>['Суперцена']);
  });

  testWidgets('labels from the host win over titles; facet titles fall back '
      'to the kit', (tester) async {
    await tester.pumpWidget(
      _host(
        PersonalizationCategoryScreen(
          sdk: sdk,
          categoryId: 'c',
          facetTitle: (name) => name == 'stickers' ? 'Стикеры' : null,
          facetValueTitle: (facet, value) => switch ((facet, value)) {
            ('product_type', 'regular') => 'Обычный',
            ('product_type', 'digital') => 'Цифровой',
            ('stickers', _sticker) => 'Акция',
            _ => null,
          },
        ),
      ),
    );
    await tester.pump();

    final labels = await _labels(tester);
    expect(labels['facet:product_type'], <String>[
      'Обычный (6)',
      'Цифровой (2)',
    ]);
    expect(labels['facet:stickers'], <String>['new (4)', 'Акция (5)']);
    final titles = <String, String>{
      for (final section
          in tester
              .widget<PersonalizationFilters>(
                find.byType(PersonalizationFilters),
              )
              .sections)
        section.id: section.title,
    };
    expect(titles['facet:stickers'], 'Стикеры');
    expect(titles['facet:product_type'], 'Product type');
  });
}
