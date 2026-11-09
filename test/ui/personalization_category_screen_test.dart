import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

/// Host API that answers `getCategory` from memory: [total] products, a page of the
/// requested limit at a time, with the facets the API sends with a category.
class _FakeHostApi extends pigeon.PersonalizationHostApi {
  int total = 200;

  /// Products there really are, when fewer than [total] claims.
  int? available;

  final List<String> categories = <String>[];
  final List<int> pages = <int>[];

  /// The filters JSON of each request, `null` — none.
  final List<Map<String, dynamic>?> params = <Map<String, dynamic>?>[];
  Completer<void>? hold;

  /// Pages that fail while listed here.
  final Set<int> failing = <int>{};

  final List<String> categoryViews = <String>[];
  int sources = 0;

  /// Shop facets of the answer: name → its product count and values.
  Map<String, Object> filters = <String, Object>{
    'Мощность': <String, Object>{
      'count': 40,
      'values': <String, int>{'1000': 20, '2000': 20},
    },
    'Материал': <String, Object>{
      'count': 90,
      'values': <String, int>{'Металл': 50, 'Пластик': 40},
    },
    // One value: nothing to choose from.
    'Страна': <String, Object>{
      'count': 200,
      'values': <String, int>{'Китай': 200},
    },
  };

  @override
  Future<String> getCategory(
    String category,
    int? limit,
    int? page,
    String? paramsJson,
    String? shopId,
  ) async {
    categories.add(category);
    pages.add(page!);
    params.add(
      paramsJson == null
          ? null
          : jsonDecode(paramsJson) as Map<String, dynamic>,
    );
    await hold?.future;
    if (failing.contains(page)) throw StateError('offline');
    final from = (page - 1) * limit!;
    return jsonEncode(<String, Object>{
      'products': <Map<String, Object>>[
        for (int i = from; i < from + limit && i < (available ?? total); i++)
          <String, Object>{'id': '$i', 'name': 'Item $i', 'price': i},
      ],
      'products_total': total,
      'brands': <Map<String, Object>>[
        <String, Object>{'name': 'Bosch', 'count': 3},
        <String, Object>{'name': 'Philips', 'count': 2},
      ],
      'price_range': <String, num>{'min': 10, 'max': 900},
      'filters': filters,
    });
  }

  @override
  Future<void> trackCategoryView(String categoryId, String? shopId) async {
    categoryViews.add(categoryId);
  }

  @override
  Future<void> trackSetSource(
    pigeon.TrackingSourceWire source,
    String? shopId,
  ) async {
    sources++;
  }
}

Widget _host(Widget screen) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 400, height: 600, child: screen),
  ),
);

PersonalizationCatalog _catalog(WidgetTester tester) =>
    tester.widget<PersonalizationCatalog>(find.byType(PersonalizationCatalog));

PersonalizationSearchResultsTitle _title(WidgetTester tester) =>
    tester.widget<PersonalizationSearchResultsTitle>(
      find.byType(PersonalizationSearchResultsTitle),
    );

/// Opens the filters screen from the title and returns its sections.
Future<List<PersonalizationFilterSection>> _openFilters(
  WidgetTester tester,
) async {
  _title(tester).onFilters!();
  await tester.pump();
  return tester
      .widget<PersonalizationFilters>(find.byType(PersonalizationFilters))
      .sections;
}

/// [sections] with [ids] checked in the options section [sectionId].
List<PersonalizationFilterSection> _check(
  List<PersonalizationFilterSection> sections,
  String sectionId,
  Set<String> ids,
) => <PersonalizationFilterSection>[
  for (final section in sections)
    if (section is PersonalizationFilterOptions && section.id == sectionId)
      section.copyWith(
        options: <PersonalizationFilterOption>[
          for (final option in section.options)
            option.copyWith(checked: ids.contains(option.id)),
        ],
      )
    else
      section,
];

void main() {
  late _FakeHostApi api;
  late PersonalizationSdk sdk;

  setUp(() {
    api = _FakeHostApi();
    sdk = PersonalizationSdk(api: api);
  });

  Widget screen({
    String categoryId = 'tehnika-dlja-kuhni',
    String? sortBy,
    String? sortDir,
    ValueChanged<Product>? onProductTap,
  }) => _host(
    PersonalizationCategoryScreen(
      sdk: sdk,
      categoryId: categoryId,
      titleText: 'Техника для кухни',
      sortBy: sortBy,
      sortDir: sortDir,
      onProductTap: onProductTap,
    ),
  );

  testWidgets('asks for the category page by page under its title', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.pump();

    expect(api.categories, <String>['tehnika-dlja-kuhni']);
    expect(api.pages, <int>[1]);
    // No filter set: the request carries none.
    expect(api.params, <Object?>[null]);
    expect(find.text('Техника для кухни'), findsOneWidget);
    // "200 products": no prefix in front of the count.
    expect(find.text('200'), findsOneWidget);
    expect(find.text('products'), findsOneWidget);
    expect(find.text('Found'), findsNothing);
    expect(find.text('Item 0'), findsOneWidget);

    _catalog(tester).onLoadMore!();
    await tester.pump();
    expect(api.pages, <int>[1, 2]);
    expect(_catalog(tester).count!.shown, 40);
  });

  testWidgets('tracks the category view once: not per page, filter, sort or '
      'retry', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pump();
    expect(api.categoryViews, <String>['tehnika-dlja-kuhni']);

    _catalog(tester).onLoadMore!();
    await tester.pump();

    final sections = await _openFilters(tester);
    tester
        .widget<PersonalizationFilters>(find.byType(PersonalizationFilters))
        .onApply!(_check(sections, 'brands', <String>{'Bosch'}));
    await tester.pump();

    await tester.pumpWidget(screen(sortBy: 'price', sortDir: 'asc'));
    await tester.pump();

    api.failing.add(2);
    _catalog(tester).onLoadMore!();
    await tester.pump();
    api.failing.clear();
    _catalog(tester).onLoadMore!();
    await tester.pump();

    expect(api.pages, <int>[1, 2, 1, 1, 2, 2]);
    expect(api.categoryViews, <String>['tehnika-dlja-kuhni']);

    // Another category is another view.
    await tester.pumpWidget(screen(categoryId: 'pylesosy'));
    await tester.pump();
    expect(api.categoryViews, <String>['tehnika-dlja-kuhni', 'pylesosy']);
  });

  testWidgets('applied brands and facets, and the sort, go into the request', (
    tester,
  ) async {
    await tester.pumpWidget(screen(sortBy: 'discount', sortDir: 'desc'));
    await tester.pump();
    expect(api.params.single, <String, Object>{
      'sort_by': 'discount',
      'sort_dir': 'desc',
    });

    var sections = await _openFilters(tester);
    sections = _check(sections, 'brands', <String>{'Bosch', 'Philips'});
    sections = _check(sections, 'facet:Материал', <String>{'Металл'});
    tester
        .widget<PersonalizationFilters>(find.byType(PersonalizationFilters))
        .onApply!(sections);
    await tester.pump();

    expect(api.pages, <int>[1, 1]);
    expect(api.params.last, <String, Object>{
      'brands': 'Bosch,Philips',
      'filters': <String, Object>{
        'Материал': <String>['Металл'],
      },
      'sort_by': 'discount',
      'sort_dir': 'desc',
    });
    // The applied values are tags under the title.
    expect(_title(tester).filters.map((tag) => tag.label), <String>[
      'Bosch',
      'Philips',
      'Металл',
    ]);

    _title(tester).filters.first.onRemove();
    await tester.pump();
    expect(api.params.last!['brands'], 'Philips');
  });

  testWidgets('filter sections come from the category answer, with the price '
      'range and the sort button', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pump();

    expect(_title(tester).showSortButton, isTrue);
    expect(_title(tester).showFiltersButton, isTrue);

    final sections = await _openFilters(tester);
    // The price range, then brands and the facets with more than one value, the
    // commonest first. No colour or size: a category has no industrial_filters.
    expect(sections.map((section) => section.id), <String>[
      'price',
      'brands',
      'facet:Материал',
      'facet:Мощность',
    ]);
    final brands = sections[1] as PersonalizationFilterOptions;
    // With the product count of each brand from the answer.
    expect(brands.options.map((option) => option.label), <String>[
      'Bosch (3)',
      'Philips (2)',
    ]);
  });

  testWidgets('a failed first page shows the error and retries it', (
    tester,
  ) async {
    final errors = <Object>[];
    api.failing.add(1);
    await tester.pumpWidget(
      _host(
        PersonalizationCategoryScreen(
          sdk: sdk,
          categoryId: 'tehnika-dlja-kuhni',
          onError: errors.add,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(PersonalizationCategoryScreen.defaultErrorText),
      findsOneWidget,
    );
    expect(find.widgetWithText(PersonalizationButton, 'Retry'), findsOneWidget);
    expect(find.text('products'), findsNothing);
    expect(errors, hasLength(1));

    api.failing.clear();
    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(api.pages, <int>[1, 1]);
    expect(find.text('Item 0'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(api.categoryViews, hasLength(1));
  });

  testWidgets('a failed next page turns load more into retry', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pump();

    api.failing.add(2);
    _catalog(tester).onLoadMore!();
    await tester.pump();
    expect(_catalog(tester).loadMoreText, 'Retry');
    expect(find.text('Item 0'), findsOneWidget);

    api.failing.clear();
    _catalog(tester).onLoadMore!();
    await tester.pump();
    expect(api.pages, <int>[1, 2, 2]);
    expect(_catalog(tester).loadMoreText, 'Load more');
    expect(_catalog(tester).count!.shown, 40);
  });

  testWidgets('an empty category says so', (tester) async {
    api.total = 0;
    await tester.pumpWidget(screen());
    await tester.pump();

    expect(find.text('No products in this category yet.'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(_catalog(tester).loadMoreText, isNull);
  });

  testWidgets('a page that comes back empty ends the feed, whatever the total '
      'says', (tester) async {
    api.available = 20;
    await tester.pumpWidget(screen());
    await tester.pump();
    expect(_catalog(tester).loadMoreText, 'Load more');
    _catalog(tester).onLoadMore!();
    await tester.pump();

    expect(api.pages, <int>[1, 2]);
    expect(_catalog(tester).loadMoreText, isNull);
    _catalog(tester).onLoadMore!();
    await tester.pump();
    expect(api.pages, <int>[1, 2]);
  });

  testWidgets('a product tap goes to the host with no tracking source', (
    tester,
  ) async {
    final tapped = <Product>[];
    await tester.pumpWidget(screen(onProductTap: tapped.add));
    await tester.pump();

    _catalog(tester).onProductTap!(_catalog(tester).products.first);
    expect(tapped.single.id, '0');
    expect(api.sources, 0);
  });

  testWidgets('without a category nothing is asked or tracked', (tester) async {
    await tester.pumpWidget(screen(categoryId: ' '));
    await tester.pump();

    expect(api.pages, isEmpty);
    expect(api.categoryViews, isEmpty);
    expect(_catalog(tester).loading, isFalse);
  });
}
