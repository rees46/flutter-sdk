import 'package:flutter/widgets.dart';

import '../../multi_instance/rees46.dart';
import '../../personalization_sdk.dart';
import '../../search/search_params.dart';
import '../../search/search_response.dart';
import '../../tracking/tracking_models.dart';
import '../components/personalization_catalog.dart';
import '../components/personalization_filters.dart';
import '../components/personalization_product.dart';
import '../components/personalization_product_image.dart';
import '../components/personalization_products_list.dart';
import '../components/personalization_search_results_title.dart';
import '../personalization_theme.dart';
import 'search_support.dart';

/// Значения фильтров, ушедшие в запрос.
@immutable
class PersonalizationSearchApplied {
  const PersonalizationSearchApplied({
    this.brands = const <String>{},
    this.priceMin,
    this.priceMax,
    this.colors = const <String>{},
    this.sizes = const <String>{},
    this.facets = const <String, Set<String>>{},
  });

  final Set<String> brands;
  final String? priceMin;
  final String? priceMax;
  final Set<String> colors;
  final Set<String> sizes;
  final Map<String, Set<String>> facets;

  bool get isEmpty =>
      brands.isEmpty &&
      (priceMin ?? '').isEmpty &&
      (priceMax ?? '').isEmpty &&
      colors.isEmpty &&
      sizes.isEmpty &&
      facets.values.every((values) => values.isEmpty);

  PersonalizationSearchApplied copyWith({
    Set<String>? brands,
    String? Function()? priceMin,
    String? Function()? priceMax,
    Set<String>? colors,
    Set<String>? sizes,
    Map<String, Set<String>>? facets,
  }) => PersonalizationSearchApplied(
    brands: brands ?? this.brands,
    priceMin: priceMin == null ? this.priceMin : priceMin(),
    priceMax: priceMax == null ? this.priceMax : priceMax(),
    colors: colors ?? this.colors,
    sizes: sizes ?? this.sizes,
    facets: facets ?? this.facets,
  );
}

/// Экран полной выдачи с данными SDK: заголовок с числом найденного, плитка ⇄ список,
/// теги применённых фильтров, счётчик, «загрузить ещё» или бесконечная прокрутка,
/// пустое состояние и экран фильтров — виджет сам ходит в `searchFull` и держит состояние.
///
/// Паттерн SearchResultsScreen из Figma (страница 1:30), источник — `searchFull(query)`.
/// Визуальный слой — [PersonalizationSearchResultsTitle] в заголовке
/// [PersonalizationCatalog]; фильтры — [PersonalizationFilters] поверх выдачи внутри этого
/// же виджета, так что экран занимает весь отведённый ему экран хоста.
///
/// Инстанс SDK: [sdk] явно, иначе [shopId] или единственный зарегистрированный
/// (`REES46.getInstance`).
///
/// Фасеты строятся из ответа: диапазон цены (`price_range`), бренды, цвета и размеры
/// (`industrial_filters`) и произвольные фасеты магазина (`filters`), из которых
/// показываются только те, где больше одного значения. Применённые значения идут тегами в
/// заголовок и параметрами в следующий запрос. Заголовок произвольного фасета — его имя
/// через [facetTitle].
///
/// Сортировки: кнопка в заголовке отдаёт [onSortTap] хосту (пикер в макете не нарисован),
/// выбранное хост кладёт в [sortBy] / [sortDir]. Каждый новый запрос трекается событием
/// `search`; нажатие на карточку запоминает источник `full_search` и отдаёт товар через
/// [onProductTap], кнопка карточки — через [onProductAction].
class PersonalizationSearchResultsScreen extends StatefulWidget {
  const PersonalizationSearchResultsScreen({
    super.key,
    this.sdk,
    this.shopId,
    required this.query,
    this.titleText,
    this.pageSize = 20,
    this.sortBy,
    this.sortDir,
    this.locations,
    this.infiniteScroll = false,
    this.showFilters = true,
    this.showSort = true,
    this.facets,
    this.productActionText,
    this.layout = PersonalizationProductsLayout.grid,
    this.imageAspect = PersonalizationProductImageAspect.square,
    this.onBack,
    this.onSortTap,
    this.onProductTap,
    this.onProductAction,
    this.onError,
    this.foundPrefix = 'Found',
    this.foundSuffix = 'products',
    this.countPrefix = 'Showing',
    this.countSeparator = 'of',
    this.loadMoreText = 'Load more',
    this.emptyText = 'No results for your request.',
    this.filtersTitle = 'Filters',
    this.resetText = 'Reset',
    this.applyText = 'Apply',
    this.showMoreText = 'Show more',
    this.showLessText = 'Show less',
    this.priceTitle = 'Price',
    this.fromLabel = 'From',
    this.toLabel = 'to',
    this.brandsTitle = 'Brand',
    this.colorsTitle = 'Color',
    this.sizesTitle = 'Size',
    this.facetTitle,
    this.iconBuilder,
  });

  final PersonalizationSdk? sdk;
  final String? shopId;

  /// Поисковая фраза; смена перезапрашивает первую страницу.
  final String query;

  /// Заголовок экрана; `null` — сама фраза.
  final String? titleText;
  final int pageSize;

  /// `popular`, `price`, `discount`, `sales_rate`, `date`; `null` — релевантность.
  final String? sortBy;

  /// `asc` / `desc`.
  final String? sortDir;

  /// Список id локаций через запятую.
  final String? locations;

  /// Бесконечная прокрутка вместо кнопки «загрузить ещё».
  final bool infiniteScroll;
  final bool showFilters;
  final bool showSort;

  /// Какие фасеты из `filters` показывать; `null` — все с более чем одним значением.
  final Set<String>? facets;

  /// Подпись кнопки на карточке; `null` — без кнопки.
  final String? productActionText;
  final PersonalizationProductsLayout layout;
  final PersonalizationProductImageAspect imageAspect;

  final VoidCallback? onBack;
  final VoidCallback? onSortTap;
  final ValueChanged<SearchProduct>? onProductTap;
  final ValueChanged<SearchProduct>? onProductAction;
  final ValueChanged<Object>? onError;

  final String foundPrefix;
  final String foundSuffix;
  final String countPrefix;
  final String countSeparator;
  final String? loadMoreText;
  final String? emptyText;
  final String filtersTitle;
  final String? resetText;
  final String? applyText;
  final String? showMoreText;
  final String? showLessText;
  final String priceTitle;
  final String fromLabel;
  final String toLabel;
  final String brandsTitle;
  final String colorsTitle;
  final String sizesTitle;

  /// Заголовок произвольного фасета по его имени в ответе.
  final String Function(String name)? facetTitle;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  @override
  State<PersonalizationSearchResultsScreen> createState() =>
      _PersonalizationSearchResultsScreenState();
}

class _PersonalizationSearchResultsScreenState
    extends State<PersonalizationSearchResultsScreen> {
  static const String _sectionPrice = 'price';
  static const String _sectionBrands = 'brands';
  static const String _sectionColors = 'colors';
  static const String _sectionSizes = 'sizes';
  static const String _sectionFacet = 'facet:';

  PersonalizationSdk? _sdk;
  late PersonalizationProductsLayout _layout = widget.layout;
  List<SearchProduct> _products = const <SearchProduct>[];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  SearchFullResponse? _facetSource;
  PersonalizationSearchApplied _applied = const PersonalizationSearchApplied();
  bool _filtersOpen = false;
  int _seq = 0;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _resolve();
  }

  @override
  void didUpdateWidget(PersonalizationSearchResultsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sdk != widget.sdk || oldWidget.shopId != widget.shopId) {
      _resolve();
    } else if (oldWidget.query != widget.query ||
        oldWidget.sortBy != widget.sortBy ||
        oldWidget.sortDir != widget.sortDir) {
      _reload();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _resolve() {
    PersonalizationSdk? sdk = widget.sdk;
    if (sdk == null) {
      try {
        sdk = REES46.getInstance(widget.shopId);
      } catch (error) {
        debugPrint(
          'PersonalizationSearchResultsScreen: cannot resolve an SDK for '
          'shopId=${widget.shopId} — $error',
        );
        widget.onError?.call(error);
      }
    }
    _sdk = sdk;
    _reload();
  }

  String get _text => widget.query.trim();

  /// Первая страница заново.
  void _reload() {
    setState(() {
      _products = const <SearchProduct>[];
      _total = 0;
      _page = 0;
    });
    final sdk = _sdk;
    if (sdk == null || _text.isEmpty) {
      _seq++;
      return;
    }
    sdk.tracking.search(_text);
    _request(sdk, 1);
  }

  /// Следующая страница, если она есть и запрос не в полёте.
  void _loadMore() {
    final sdk = _sdk;
    if (sdk == null ||
        _text.isEmpty ||
        _loading ||
        _products.length >= _total) {
      return;
    }
    _request(sdk, _page + 1);
  }

  void _onScroll() {
    if (!widget.infiniteScroll || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >=
        position.maxScrollExtent - position.viewportDimension / 2) {
      _loadMore();
    }
  }

  Future<void> _request(PersonalizationSdk sdk, int nextPage) async {
    final seq = ++_seq;
    setState(() => _loading = true);
    final applied = _applied;
    final params = SearchParams(
      page: nextPage,
      limit: widget.pageSize,
      sortBy: widget.sortBy,
      sortDir: widget.sortDir,
      locations: widget.locations,
      brands: applied.brands.isEmpty ? null : applied.brands.join(','),
      priceMin: double.tryParse((applied.priceMin ?? '').trim()),
      priceMax: double.tryParse((applied.priceMax ?? '').trim()),
      colors: applied.colors.isEmpty ? null : applied.colors.toList(),
      fashionSizes: applied.sizes.isEmpty ? null : applied.sizes.toList(),
      filters: <String, List<String>>{
        for (final entry in applied.facets.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
      },
    );
    try {
      final response = await sdk.searchFull(_text, params: params);
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _page = nextPage;
        _total = response.productsTotal;
        _products = nextPage == 1
            ? response.products
            : <SearchProduct>[..._products, ...response.products];
        if (nextPage == 1) _facetSource = response;
      });
    } catch (error) {
      if (!mounted || seq != _seq) return;
      setState(() => _loading = false);
      widget.onError?.call(error);
    }
  }

  void _apply(PersonalizationSearchApplied next) {
    setState(() {
      _applied = next;
      _filtersOpen = false;
    });
    _reload();
  }

  void _productTapped(SearchProduct product) {
    if (_text.isNotEmpty) {
      _sdk?.tracking.setSource(
        TrackingSource(type: TrackingSourceType.fullSearch, code: _text),
      );
    }
    widget.onProductTap?.call(product);
  }

  SearchProduct? _find(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  // --- Фасеты ⇄ секции экрана фильтров ------------------------------------------------------

  String _facetTitle(String name) {
    final custom = widget.facetTitle;
    if (custom != null) return custom(name);
    final spaced = name.replaceAll('_', ' ');
    return spaced.isEmpty
        ? spaced
        : spaced[0].toUpperCase() + spaced.substring(1);
  }

  List<PersonalizationFilterOption> _options(
    Iterable<String> values,
    Set<String> checked,
  ) {
    final seen = <String>{};
    return <PersonalizationFilterOption>[
      for (final value in <String>[...values, ...checked])
        if (seen.add(value))
          PersonalizationFilterOption(
            id: value,
            label: value,
            checked: checked.contains(value),
          ),
    ];
  }

  List<PersonalizationFilterSection> _buildSections() {
    final source = _facetSource;
    final applied = _applied;
    final sections = <PersonalizationFilterSection>[];
    if (source?.priceRange != null ||
        applied.priceMin != null ||
        applied.priceMax != null) {
      // Границы диапазона — подсказками: в запрос уходит только то, что ввёл пользователь.
      final range = source?.priceRange;
      sections.add(
        PersonalizationFilterRange(
          id: _sectionPrice,
          title: widget.priceTitle,
          fromLabel: widget.fromLabel,
          toLabel: widget.toLabel,
          from: applied.priceMin,
          to: applied.priceMax,
          fromPlaceholder: range == null ? null : _bound(range.min),
          toPlaceholder: range == null ? null : _bound(range.max),
        ),
      );
    }
    final brands = source?.brands ?? const <String>[];
    if (brands.isNotEmpty || applied.brands.isNotEmpty) {
      sections.add(
        PersonalizationFilterOptions(
          id: _sectionBrands,
          title: widget.brandsTitle,
          options: _options(brands, applied.brands),
          showMoreText: widget.showMoreText,
          showLessText: widget.showLessText,
        ),
      );
    }
    final colors = source?.industrialFilters?.colors ?? const <String>[];
    if (colors.isNotEmpty || applied.colors.isNotEmpty) {
      sections.add(
        PersonalizationFilterOptions(
          id: _sectionColors,
          title: widget.colorsTitle,
          options: _options(colors, applied.colors),
          showMoreText: widget.showMoreText,
          showLessText: widget.showLessText,
        ),
      );
    }
    final sizes = source?.industrialFilters?.fashionSizes ?? const <String>[];
    if (sizes.isNotEmpty || applied.sizes.isNotEmpty) {
      sections.add(
        PersonalizationFilterOptions(
          id: _sectionSizes,
          title: widget.sizesTitle,
          options: _options(sizes, applied.sizes),
          showMoreText: widget.showMoreText,
          showLessText: widget.showLessText,
        ),
      );
    }
    final wanted = widget.facets;
    final filters = source?.filters ?? const <String, SearchFilter>{};
    for (final name in filters.keys.toList()..sort()) {
      final values = filters[name]!.values.keys.toList()..sort();
      final checked = applied.facets[name] ?? const <String>{};
      final visible = wanted == null
          ? values.length > 1
          : wanted.contains(name);
      if (!visible && checked.isEmpty) continue;
      sections.add(
        PersonalizationFilterOptions(
          id: '$_sectionFacet$name',
          title: _facetTitle(name),
          options: _options(values, checked),
          showMoreText: widget.showMoreText,
          showLessText: widget.showLessText,
        ),
      );
    }
    return sections;
  }

  /// Граница цены без хвоста «.0»: сервер отдаёт число, форматированной строки у него нет.
  static String _bound(double value) => value == value.floorToDouble()
      ? value.toInt().toString()
      : value.toString();

  PersonalizationSearchApplied _fromSections(
    List<PersonalizationFilterSection> sections,
  ) {
    var next = const PersonalizationSearchApplied();
    final facets = <String, Set<String>>{};
    for (final section in sections) {
      switch (section) {
        case PersonalizationFilterRange():
          if (section.id != _sectionPrice) break;
          String? clean(String? value) {
            final trimmed = (value ?? '').trim();
            return trimmed.isEmpty ? null : trimmed;
          }
          next = next.copyWith(
            priceMin: () => clean(section.from),
            priceMax: () => clean(section.to),
          );
        case PersonalizationFilterOptions():
          final checked = <String>{
            for (final option in section.options)
              if (option.checked) option.id,
          };
          if (section.id == _sectionBrands) {
            next = next.copyWith(brands: checked);
          } else if (section.id == _sectionColors) {
            next = next.copyWith(colors: checked);
          } else if (section.id == _sectionSizes) {
            next = next.copyWith(sizes: checked);
          } else if (section.id.startsWith(_sectionFacet)) {
            facets[section.id.substring(_sectionFacet.length)] = checked;
          }
      }
    }
    return next.copyWith(facets: facets);
  }

  List<PersonalizationSearchFilter> _appliedTags() {
    final applied = _applied;
    final tags = <PersonalizationSearchFilter>[];
    for (final brand in applied.brands.toList()..sort()) {
      tags.add(
        PersonalizationSearchFilter(
          label: brand,
          onRemove: () => _apply(
            applied.copyWith(brands: applied.brands.difference({brand})),
          ),
        ),
      );
    }
    final priceMin = (applied.priceMin ?? '').trim();
    final priceMax = (applied.priceMax ?? '').trim();
    if (priceMin.isNotEmpty || priceMax.isNotEmpty) {
      final label = [priceMin, priceMax].where((v) => v.isNotEmpty).join(' – ');
      tags.add(
        PersonalizationSearchFilter(
          label: '${widget.priceTitle} $label',
          onRemove: () => _apply(
            applied.copyWith(priceMin: () => null, priceMax: () => null),
          ),
        ),
      );
    }
    for (final color in applied.colors.toList()..sort()) {
      tags.add(
        PersonalizationSearchFilter(
          label: color,
          onRemove: () => _apply(
            applied.copyWith(colors: applied.colors.difference({color})),
          ),
        ),
      );
    }
    for (final size in applied.sizes.toList()..sort()) {
      tags.add(
        PersonalizationSearchFilter(
          label: size,
          onRemove: () =>
              _apply(applied.copyWith(sizes: applied.sizes.difference({size}))),
        ),
      );
    }
    for (final name in applied.facets.keys.toList()..sort()) {
      for (final value in applied.facets[name]!.toList()..sort()) {
        tags.add(
          PersonalizationSearchFilter(
            label: value,
            onRemove: () => _apply(
              applied.copyWith(
                facets: <String, Set<String>>{
                  ...applied.facets,
                  name: applied.facets[name]!.difference({value}),
                },
              ),
            ),
          ),
        );
      }
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    final hasMore = _products.isNotEmpty && _products.length < _total;

    final header = PersonalizationSearchResultsTitle(
      title: widget.titleText ?? widget.query,
      selectedViewIndex: _layout == PersonalizationProductsLayout.grid ? 0 : 1,
      onViewChanged: (index) => setState(() {
        _layout = index == 0
            ? PersonalizationProductsLayout.grid
            : PersonalizationProductsLayout.list;
      }),
      onBack: widget.onBack,
      onFilters: () => setState(() => _filtersOpen = true),
      onSort: widget.onSortTap,
      showFiltersButton: widget.showFilters,
      showSortButton: widget.showSort,
      results: PersonalizationSearchResults(
        prefix: widget.foundPrefix,
        count: _total,
        suffix: widget.foundSuffix,
      ),
      filters: _appliedTags(),
      iconBuilder: widget.iconBuilder,
    );

    final catalog = PersonalizationCatalog(
      header: header,
      layout: _layout,
      products: <PersonalizationProduct>[
        for (final product in _products)
          toCardProduct(product, widget.productActionText),
      ],
      imageAspect: widget.imageAspect,
      emptyText: widget.emptyText,
      loading: _loading,
      count: _products.isEmpty
          ? null
          : PersonalizationCatalogCount(
              prefix: widget.countPrefix,
              shown: _products.length,
              separator: widget.countSeparator,
              total: _total,
            ),
      loadMoreText: hasMore && !widget.infiniteScroll
          ? widget.loadMoreText
          : null,
      onLoadMore: _loadMore,
      onProductTap: (card) {
        final product = _find(card.id);
        if (product != null) _productTapped(product);
      },
      onProductAction: (card) {
        final product = _find(card.id);
        if (product != null) widget.onProductAction?.call(product);
      },
      iconBuilder: widget.iconBuilder,
    );

    return ColoredBox(
      color: colors.backgroundGeneric,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            child: catalog,
          ),
          if (_filtersOpen)
            ColoredBox(
              color: colors.backgroundGeneric,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: PersonalizationFilters(
                  title: widget.filtersTitle,
                  sections: _buildSections(),
                  resetText: widget.resetText,
                  applyText: widget.applyText,
                  onClose: () => setState(() => _filtersOpen = false),
                  onReset: () => _apply(const PersonalizationSearchApplied()),
                  onApply: (sections) => _apply(_fromSections(sections)),
                  iconBuilder: widget.iconBuilder,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
