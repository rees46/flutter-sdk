import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../multi_instance/rees46.dart';
import '../../personalization_sdk.dart';
import '../../search/search_response.dart' show SearchFilter;
import '../components/personalization_catalog.dart';
import '../components/personalization_filters.dart';
import '../components/personalization_product.dart';
import '../components/personalization_product_image.dart';
import '../components/personalization_products_list.dart';
import '../components/personalization_search_results_title.dart';
import '../personalization_theme.dart';

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

/// Применённые фильтры параметрами запроса. Внутреннее: не экспортируется из кита.
extension PersonalizationAppliedParams on PersonalizationSearchApplied {
  /// Бренды через запятую, `null` — не выбраны.
  String? get brandsParam => brands.isEmpty ? null : brands.join(',');

  /// Границы цены числом; не число — без границы.
  double? get priceMinParam => double.tryParse((priceMin ?? '').trim());
  double? get priceMaxParam => double.tryParse((priceMax ?? '').trim());

  /// Отмеченные значения фасетов по имени, без фасетов, где ничего не отмечено.
  Map<String, List<String>> get facetsParam => <String, List<String>>{
    for (final entry in facets.entries)
      if (entry.value.isNotEmpty) entry.key: entry.value.toList(),
  };
}

/// Страница выдачи в общем для экранов виде: ответ поиска или категории. Фасеты
/// читаются только из первой страницы. Внутреннее: не экспортируется из кита.
@immutable
class PersonalizationResultsPage<P> {
  const PersonalizationResultsPage({
    required this.products,
    required this.total,
    this.priceRange,
    this.brands = const <String>[],
    this.brandCounts = const <String, int>{},
    this.colors = const <String>[],
    this.colorCounts = const <String, int>{},
    this.sizes = const <String>[],
    this.sizeCounts = const <String, int>{},
    this.filters = const <String, SearchFilter>{},
  });

  final List<P> products;
  final int total;

  /// Границы цен в выдаче, `null` — сервер их не прислал.
  final ({double min, double max})? priceRange;
  final List<String> brands;

  /// Число товаров по значению, где оно есть в ответе.
  final Map<String, int> brandCounts;

  /// Цвета и размеры (`industrial_filters`); у категории их нет.
  final List<String> colors;
  final Map<String, int> colorCounts;
  final List<String> sizes;
  final Map<String, int> sizeCounts;

  /// Произвольные фасеты магазина по имени.
  final Map<String, SearchFilter> filters;
}

/// Какие произвольные фасеты показать на экране фильтров и в каком порядке.
///
/// Явный список [wanted] главнее: те его фасеты, что есть в ответе, в порядке хоста.
/// Без него — фасеты с более чем одним значением по убыванию `count` (сколько товаров
/// их имеют; при равенстве — по имени), первые [maxFacets]; `null` или 0 — все.
/// Приоритета у фасетов в ответе нет, а их бывают сотни.
///
/// Фасет с отмеченными значениями ([checked]) виден всегда, иначе его не снять: не
/// попавшие в выборку идут следом в том же порядке.
List<String> visibleFacets(
  Map<String, SearchFilter> filters, {
  Set<String>? wanted,
  int? maxFacets,
  Set<String> checked = const <String>{},
}) {
  int byCount(String a, String b) {
    final count = (filters[b]?.count ?? 0).compareTo(filters[a]?.count ?? 0);
    return count != 0 ? count : a.compareTo(b);
  }

  final List<String> shown;
  if (wanted != null) {
    shown = <String>[
      for (final name in wanted)
        if (filters.containsKey(name)) name,
    ];
  } else {
    final ranked = <String>[
      for (final entry in filters.entries)
        if (entry.value.values.length > 1) entry.key,
    ]..sort(byCount);
    final limit = maxFacets ?? 0;
    shown = limit > 0 && ranked.length > limit
        ? ranked.sublist(0, limit)
        : ranked;
  }
  final rest = <String>[
    for (final name in checked)
      if (!shown.contains(name)) name,
  ]..sort(byCount);
  return <String>[...shown, ...rest];
}

/// Подпись значения-объекта: строка, которая после trim начинается с `{`, разбирается
/// как JSON-объект и несёт непустую строку `title`, подписывается этим `title`. Иначе —
/// `null`: значение показывается как есть. Только по формату — ни имён фасетов, ни языка.
String? jsonValueTitle(String value) {
  final trimmed = value.trim();
  if (!trimmed.startsWith('{')) return null;
  try {
    final decoded = jsonDecode(trimmed);
    final title = decoded is Map ? decoded['title'] : null;
    if (title is String && title.trim().isNotEmpty) return title.trim();
  } on FormatException {
    // Битый JSON — обычная строка.
  }
  return null;
}

/// Подпись значения [value] фасета [facet] без числа товаров: подпись хоста ([custom]),
/// если она не пустая, иначе `title` значения-объекта ([jsonValueTitle]), иначе само
/// значение. В запрос всегда уходит исходное значение.
String facetValueLabel(
  String facet,
  String value,
  String? Function(String facet, String value)? custom,
) {
  final fromHost = custom?.call(facet, value);
  if (fromHost != null && fromHost.trim().isNotEmpty) return fromHost;
  return jsonValueTitle(value) ?? value;
}

/// Общее ядро экранов выдачи кита — [PersonalizationSearchResultsScreen] и
/// [PersonalizationCategoryScreen]: инстанс SDK, страницы, «загрузить ещё» или
/// бесконечная прокрутка, фильтры с тегами, сортировка, пустое состояние, ошибка с
/// повтором и всё визуальное. Экраны отличаются источником выдачи, заголовком и
/// трекингом. Внутреннее: сам класс не экспортируется из кита, его поля видны через
/// экраны.
abstract class PersonalizationResultsScreenBase<P> extends StatefulWidget {
  const PersonalizationResultsScreenBase({
    super.key,
    this.sdk,
    this.shopId,
    this.titleText,
    this.pageSize = 20,
    this.sortBy,
    this.sortDir,
    this.locations,
    this.infiniteScroll = false,
    this.showFilters = true,
    this.showSort = true,
    this.facets,
    this.maxFacets = 10,
    this.productActionText,
    this.showRating = false,
    this.layout = PersonalizationProductsLayout.grid,
    this.imageAspect = PersonalizationProductImageAspect.square,
    this.onBack,
    this.onSortTap,
    this.onProductTap,
    this.onProductAction,
    this.onError,
    required this.foundPrefix,
    required this.foundSuffix,
    this.countPrefix = 'Showing',
    this.countSeparator = 'of',
    this.loadMoreText = 'Load more',
    required this.emptyText,
    this.errorText = defaultErrorText,
    this.retryText = defaultRetryText,
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
    this.facetValueTitle,
    this.showValueCounts = true,
    this.iconBuilder,
  });

  final PersonalizationSdk? sdk;
  final String? shopId;

  /// Заголовок экрана; `null` — свой у каждого экрана.
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

  /// Какие фасеты из `filters` показывать, в этом порядке; `null` — фасеты с более
  /// чем одним значением, самые частые первыми, не больше [maxFacets].
  final Set<String>? facets;

  /// Сколько фасетов показывать без явного [facets]; `null` или 0 — все.
  final int? maxFacets;

  /// Подпись кнопки на карточке; `null` — без кнопки.
  final String? productActionText;

  /// Рисовать ли рейтинг на карточках. В ответах API рейтинга нет, поэтому по
  /// умолчанию выключено.
  final bool showRating;
  final PersonalizationProductsLayout layout;
  final PersonalizationProductImageAspect imageAspect;

  final VoidCallback? onBack;
  final VoidCallback? onSortTap;
  final ValueChanged<P>? onProductTap;
  final ValueChanged<P>? onProductAction;
  final ValueChanged<Object>? onError;

  /// Счётчик в заголовке: «[foundPrefix] N [foundSuffix]»; пустой префикс не рисуется.
  final String foundPrefix;
  final String foundSuffix;
  final String countPrefix;
  final String countSeparator;
  final String? loadMoreText;
  final String? emptyText;

  /// Текст вместо выдачи, когда первая страница не загрузилась. `null` или пустая
  /// строка — [defaultErrorText]: экран ошибки без текста не остаётся.
  final String? errorText;

  /// Кнопка повтора под [errorText] и на месте «загрузить ещё», когда не загрузилась
  /// следующая страница. `null` или пустая строка — [defaultRetryText]: без кнопки
  /// после ошибки не восстановиться, бесконечная прокрутка ждёт её.
  final String? retryText;

  static const String defaultErrorText =
      'Something went wrong. Check your connection and try again.';
  static const String defaultRetryText = 'Retry';
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

  /// Заголовок произвольного фасета по его имени в ответе; `null` или пустая строка —
  /// заголовок кита по умолчанию (имя с пробелами вместо `_` и заглавной буквой).
  final String? Function(String name)? facetTitle;

  /// Подпись значения произвольного фасета (`filters`) — на чекбоксе и в теге. `null` или
  /// пустая строка — `title` значения-объекта (JSON с непустым `title`), иначе само
  /// значение. В запрос уходит исходное значение. Брендов, цветов и размеров не касается.
  final String? Function(String facet, String value)? facetValueTitle;

  /// Число товаров рядом со значением фильтра — «Значение (N)», где ответ его несёт.
  /// В тегах применённых фильтров числа нет.
  final bool showValueCounts;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;
}

/// Состояние экрана выдачи: вся логика ядра. Экран задаёт источник ([fetch]), заголовок
/// по умолчанию, трекинг ([onNewResults], [productTapped]) и карточку товара.
abstract class PersonalizationResultsScreenState<
  P,
  W extends PersonalizationResultsScreenBase<P>
>
    extends State<W> {
  static const String _sectionPrice = 'price';
  static const String _sectionBrands = 'brands';
  static const String _sectionColors = 'colors';
  static const String _sectionSizes = 'sizes';
  static const String _sectionFacet = 'facet:';

  PersonalizationSdk? _sdk;
  late PersonalizationProductsLayout _layout = widget.layout;
  List<P> _products = <P>[];
  int _total = 0;
  int _page = 0;
  bool _loading = false;

  /// Первая страница текущего источника пришла: только тогда пустая выдача — «ничего
  /// не найдено», а не загрузка, пустой источник или ошибка.
  bool _answered = false;

  /// Следующая страница пришла пустой: выдача кончилась, что бы ни говорил `total`.
  bool _ended = false;

  /// Страница, запрос которой упал, `null` — ошибки нет. Первая — экран ошибки, следующая —
  /// повтор на месте «загрузить ещё»; пока она не повторена, лента дальше не грузится.
  int? _failedPage;
  PersonalizationResultsPage<P>? _facetSource;
  PersonalizationSearchApplied _applied = const PersonalizationSearchApplied();

  /// Секции открытого экрана фильтров, `null` — закрыт. Собираются на открытии и на новых
  /// фасетах, а не в каждом build: новый список сбрасывает в [PersonalizationFilters]
  /// несохранённые галочки и введённые цены.
  List<PersonalizationFilterSection>? _filterSections;
  int _seq = 0;
  final ScrollController _scroll = ScrollController();

  // --- Что задаёт экран ---------------------------------------------------------------------

  /// Имя экрана в логе.
  String get screenName;

  /// Источник выдачи задан (у поиска — непустая фраза); без него запросов нет.
  bool get hasSource;

  /// Источник сменился — выдача с первой страницы.
  bool sourceChanged(W oldWidget);

  /// Заголовок, когда [PersonalizationResultsScreenBase.titleText] не задан.
  String get defaultTitle;

  /// Запрос применяет цену и сортировку; нет — секции цены и кнопки сортировки нет.
  bool get appliesPriceAndSort => true;

  /// Страница [page] выдачи с фильтрами [applied].
  Future<PersonalizationResultsPage<P>> fetch(
    PersonalizationSdk sdk,
    int page,
    PersonalizationSearchApplied applied,
  );

  /// Новая выдача уходит в запрос: первая страница заново, не повтор и не следующая.
  void onNewResults(PersonalizationSdk sdk) {}

  /// Нажатие на карточку; по умолчанию сразу уходит хосту.
  void productTapped(P product) => widget.onProductTap?.call(product);

  PersonalizationProduct card(P product);
  String idOf(P product);

  /// Инстанс SDK экрана, `null` — не нашёлся.
  PersonalizationSdk? get sdk => _sdk;

  // --- Жизненный цикл и запросы -------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _resolve();
  }

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sdk != widget.sdk || oldWidget.shopId != widget.shopId) {
      _resolve();
    } else if (sourceChanged(oldWidget) ||
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
          '$screenName: cannot resolve an SDK for '
          'shopId=${widget.shopId} — $error',
        );
        widget.onError?.call(error);
      }
    }
    _sdk = sdk;
    _reload();
  }

  /// Первая страница заново.
  void _reload() {
    // Ответ запроса в полёте отбросится по _seq и флаг не снимет — снимаем здесь, иначе
    // на пустом источнике лоадер крутится вечно, а loadMore заблокирован.
    setState(() {
      _products = <P>[];
      _total = 0;
      _page = 0;
      _loading = false;
      _answered = false;
      _ended = false;
      _failedPage = null;
    });
    _toTop();
    final sdk = _sdk;
    if (sdk == null || !hasSource) {
      _seq++;
      return;
    }
    onNewResults(sdk);
    _request(sdk, 1);
  }

  /// Новая выдача — с начала ленты, а не с места, где пользователь бросил прошлую.
  /// После кадра: перезапрос приходит и из didUpdateWidget, посреди сборки.
  void _toTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  /// Следующая страница, если она есть и запрос не в полёте.
  void _loadMore() {
    final sdk = _sdk;
    if (sdk == null ||
        !hasSource ||
        _loading ||
        _ended ||
        _failedPage != null ||
        _products.length >= _total) {
      return;
    }
    _request(sdk, _page + 1);
  }

  /// Повтор упавшей страницы.
  void _retry() {
    final sdk = _sdk;
    final page = _failedPage;
    if (sdk == null || page == null || !hasSource || _loading) return;
    setState(() => _failedPage = null);
    _request(sdk, page);
  }

  /// Бесконечная прокрутка: следующая страница — за полэкрана до конца ленты. Запрос в
  /// полёте повторно не уходит, это держит [_loadMore].
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
    try {
      final response = await fetch(sdk, nextPage, _applied);
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _failedPage = null;
        _page = nextPage;
        _total = response.total;
        _ended = response.products.isEmpty;
        _products = nextPage == 1
            ? response.products
            : <P>[..._products, ...response.products];
        if (nextPage == 1) {
          _answered = true;
          _facetSource = response;
          // Фасеты сменились под открытым экраном фильтров — секции из нового ответа.
          if (_filterSections != null) _filterSections = _buildSections();
        }
      });
    } catch (error) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _failedPage = nextPage;
      });
      widget.onError?.call(error);
    }
  }

  void _apply(PersonalizationSearchApplied next) {
    setState(() {
      _applied = next;
      _filterSections = null;
    });
    _reload();
  }

  P? _find(String id) {
    for (final product in _products) {
      if (idOf(product) == id) return product;
    }
    return null;
  }

  // --- Фасеты ⇄ секции экрана фильтров ------------------------------------------------------

  String _facetTitle(String name) {
    final custom = widget.facetTitle?.call(name);
    if (custom != null && custom.isNotEmpty) return custom;
    final spaced = name.replaceAll('_', ' ');
    return spaced.isEmpty
        ? spaced
        : spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// Подпись значения произвольного фасета, см. [facetValueLabel].
  String _valueLabel(String facet, String value) =>
      facetValueLabel(facet, value, widget.facetValueTitle);

  /// Чекбоксы значений: id — исходное значение, подпись — [label] и число товаров из
  /// [counts], если оно есть и [PersonalizationResultsScreenBase.showValueCounts].
  List<PersonalizationFilterOption> _options(
    Iterable<String> values,
    Set<String> checked, {
    String Function(String value)? label,
    Map<String, int>? counts,
  }) {
    final seen = <String>{};
    return <PersonalizationFilterOption>[
      for (final value in <String>[...values, ...checked])
        if (seen.add(value))
          PersonalizationFilterOption(
            id: value,
            label: _counted(label?.call(value) ?? value, counts?[value]),
            checked: checked.contains(value),
          ),
    ];
  }

  String _counted(String label, int? count) =>
      widget.showValueCounts && count != null ? '$label ($count)' : label;

  PersonalizationFilterOptions _optionsSection(
    String id,
    String title,
    Iterable<String> values,
    Set<String> checked, {
    String Function(String value)? label,
    Map<String, int>? counts,
  }) => PersonalizationFilterOptions(
    id: id,
    title: title,
    options: _options(values, checked, label: label, counts: counts),
    showMoreText: widget.showMoreText,
    showLessText: widget.showLessText,
  );

  List<PersonalizationFilterSection> _buildSections() {
    final source = _facetSource;
    final applied = _applied;
    final sections = <PersonalizationFilterSection>[];
    if (appliesPriceAndSort &&
        (source?.priceRange != null ||
            applied.priceMin != null ||
            applied.priceMax != null)) {
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
    void options(
      String id,
      String title,
      List<String>? values,
      Map<String, int>? counts,
      Set<String> checked,
    ) {
      final listed = values ?? const <String>[];
      if (listed.isEmpty && checked.isEmpty) return;
      sections.add(_optionsSection(id, title, listed, checked, counts: counts));
    }

    options(
      _sectionBrands,
      widget.brandsTitle,
      source?.brands,
      source?.brandCounts,
      applied.brands,
    );
    options(
      _sectionColors,
      widget.colorsTitle,
      source?.colors,
      source?.colorCounts,
      applied.colors,
    );
    options(
      _sectionSizes,
      widget.sizesTitle,
      source?.sizes,
      source?.sizeCounts,
      applied.sizes,
    );
    final filters = source?.filters ?? const <String, SearchFilter>{};
    final names = visibleFacets(
      filters,
      wanted: widget.facets,
      maxFacets: widget.maxFacets,
      checked: <String>{
        for (final entry in applied.facets.entries)
          if (entry.value.isNotEmpty) entry.key,
      },
    );
    for (final name in names) {
      final counts = filters[name]?.values ?? const <String, int>{};
      String label(String value) => _valueLabel(name, value);
      // По подписи, а не по исходному значению: у значений-объектов это JSON.
      final values = counts.keys.toList()
        ..sort((a, b) => label(a).compareTo(label(b)));
      sections.add(
        _optionsSection(
          '$_sectionFacet$name',
          _facetTitle(name),
          values,
          applied.facets[name] ?? const <String>{},
          label: label,
          counts: counts,
        ),
      );
    }
    return sections;
  }

  static String _orDefault(String? text, String fallback) =>
      (text ?? '').isEmpty ? fallback : text!;

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
    void tag(String label, PersonalizationSearchApplied without) => tags.add(
      PersonalizationSearchFilter(
        label: label,
        onRemove: () => _apply(without),
      ),
    );

    for (final brand in applied.brands.toList()..sort()) {
      tag(brand, applied.copyWith(brands: applied.brands.difference({brand})));
    }
    final priceMin = (applied.priceMin ?? '').trim();
    final priceMax = (applied.priceMax ?? '').trim();
    if (priceMin.isNotEmpty || priceMax.isNotEmpty) {
      final label = [priceMin, priceMax].where((v) => v.isNotEmpty).join(' – ');
      tag(
        '${widget.priceTitle} $label',
        applied.copyWith(priceMin: () => null, priceMax: () => null),
      );
    }
    for (final color in applied.colors.toList()..sort()) {
      tag(color, applied.copyWith(colors: applied.colors.difference({color})));
    }
    for (final size in applied.sizes.toList()..sort()) {
      tag(size, applied.copyWith(sizes: applied.sizes.difference({size})));
    }
    for (final name in applied.facets.keys.toList()..sort()) {
      String label(String value) => _valueLabel(name, value);
      final values = applied.facets[name]!.toList()
        ..sort((a, b) => label(a).compareTo(label(b)));
      // Подпись — как на чекбоксе, но без числа товаров.
      for (final value in values) {
        tag(
          label(value),
          applied.copyWith(
            facets: <String, Set<String>>{
              ...applied.facets,
              name: applied.facets[name]!.difference({value}),
            },
          ),
        );
      }
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    final hasMore =
        _products.isNotEmpty && !_ended && _products.length < _total;
    final firstPageFailed = _failedPage == 1;
    final nextPageFailed = (_failedPage ?? 0) > 1;
    final errorText = _orDefault(
      widget.errorText,
      PersonalizationResultsScreenBase.defaultErrorText,
    );
    final retryText = _orDefault(
      widget.retryText,
      PersonalizationResultsScreenBase.defaultRetryText,
    );

    final header = PersonalizationSearchResultsTitle(
      title: widget.titleText ?? defaultTitle,
      selectedViewIndex: _layout == PersonalizationProductsLayout.grid ? 0 : 1,
      onViewChanged: (index) => setState(() {
        _layout = index == 0
            ? PersonalizationProductsLayout.grid
            : PersonalizationProductsLayout.list;
      }),
      onBack: widget.onBack,
      onFilters: () => setState(() => _filterSections = _buildSections()),
      onSort: widget.onSortTap,
      showFiltersButton: widget.showFilters,
      showSortButton: widget.showSort && appliesPriceAndSort,
      // Число — только когда первая страница нынешнего запроса ответила: «Найдено 0» на
      // лоадере, после новых фильтров или сортировки и над ошибкой вводило бы в заблуждение.
      // Кнопки фильтров и сортировки остаются на месте.
      results: PersonalizationSearchResults(
        prefix: widget.foundPrefix,
        count: _answered ? _total : null,
        suffix: widget.foundSuffix,
      ),
      filters: _appliedTags(),
      iconBuilder: widget.iconBuilder,
    );

    final catalog = PersonalizationCatalog(
      controller: _scroll,
      // Поля экрана — поля ленты: карточки прокручиваются под ними.
      padding: const EdgeInsets.all(16),
      header: header,
      layout: _layout,
      products: <PersonalizationProduct>[
        for (final product in _products) card(product),
      ],
      imageAspect: widget.imageAspect,
      showRating: widget.showRating,
      emptyText: firstPageFailed
          ? errorText
          : (_answered ? widget.emptyText : null),
      emptyActionText: firstPageFailed ? retryText : null,
      onEmptyAction: _retry,
      loading: _loading,
      count: _products.isEmpty
          ? null
          : PersonalizationCatalogCount(
              prefix: widget.countPrefix,
              shown: _products.length,
              separator: widget.countSeparator,
              total: _total,
            ),
      loadMoreText: nextPageFailed
          ? retryText
          : (hasMore && !widget.infiniteScroll ? widget.loadMoreText : null),
      onLoadMore: nextPageFailed ? _retry : _loadMore,
      onProductTap: (card) {
        final product = _find(card.id);
        if (product != null) productTapped(product);
      },
      onProductAction: (card) {
        final product = _find(card.id);
        if (product != null) widget.onProductAction?.call(product);
      },
      iconBuilder: widget.iconBuilder,
    );

    final filterSections = _filterSections;
    return ColoredBox(
      color: colors.backgroundGeneric,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Каталог прокручивается сам, а не во внешнем скролле: там его лента
          // раскладывалась бы целиком, и каждая догруженная страница оставалась бы
          // построенной всеми карточками.
          catalog,
          if (filterSections != null)
            ColoredBox(
              color: colors.backgroundGeneric,
              // Экран фильтров на всю высоту: заголовок и кнопки на месте, прокручиваются секции.
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PersonalizationFilters(
                  title: widget.filtersTitle,
                  sections: filterSections,
                  resetText: widget.resetText,
                  applyText: widget.applyText,
                  onClose: () => setState(() => _filterSections = null),
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
