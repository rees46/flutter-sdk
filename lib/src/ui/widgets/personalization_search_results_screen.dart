import 'package:flutter/widgets.dart';

import '../../personalization_sdk.dart';
import '../../search/search_params.dart';
import '../../search/search_response.dart';
import '../../tracking/tracking_models.dart';
import '../components/personalization_catalog.dart';
import '../components/personalization_filters.dart';
import '../components/personalization_product.dart';
import '../components/personalization_search_results_title.dart';
import 'personalization_results_screen_base.dart';
import 'product_mapping.dart';

export 'personalization_results_screen_base.dart'
    show PersonalizationSearchApplied;

/// Экран полной выдачи с данными SDK: заголовок с числом найденного, плитка ⇄ список,
/// теги применённых фильтров, счётчик, «загрузить ещё» или бесконечная прокрутка,
/// пустое состояние и экран фильтров — виджет сам ходит в `searchFull` и держит состояние.
///
/// Паттерн SearchResultsScreen из Figma (страница 1:30), источник — `searchFull(query)`.
/// Визуальный слой — [PersonalizationSearchResultsTitle] в заголовке
/// [PersonalizationCatalog]; фильтры — [PersonalizationFilters] поверх выдачи внутри этого
/// же виджета, так что экран занимает весь отведённый ему экран хоста. Ядро общее с
/// экраном категории (`PersonalizationCategoryScreen`).
///
/// Инстанс SDK: [sdk] явно, иначе [shopId] или единственный зарегистрированный
/// (`REES46.getInstance`).
///
/// Фасеты строятся из ответа: диапазон цены (`price_range`), бренды, цвета и размеры
/// (`industrial_filters`) и произвольные фасеты магазина (`filters`). Из произвольных
/// показываются те, где больше одного значения, самые частые (`count`) первыми и не
/// больше [maxFacets]; явный список [facets] главнее. Применённые значения идут тегами
/// в заголовок и параметрами в следующий запрос. Заголовок произвольного фасета — его
/// имя через [facetTitle]. Подпись значения — [facetValueTitle] хоста, иначе `title`
/// значения-объекта (JSON), иначе само значение; рядом число товаров из ответа
/// ([showValueCounts]), в тегах — без числа.
///
/// Сортировки: кнопка в заголовке отдаёт [onSortTap] хосту (пикер в макете не нарисован),
/// выбранное хост кладёт в [sortBy] / [sortDir]. Каждый новый запрос трекается событием
/// `search`; нажатие на карточку запоминает источник `full_search` и отдаёт товар через
/// [onProductTap], кнопка карточки — через [onProductAction].
///
/// Ошибка запроса уходит в [onError] и видна на экране: не загрузилась первая страница —
/// вместо выдачи [errorText] и кнопка [retryText]; не загрузилась следующая — кнопка
/// «загрузить ещё» становится [retryText]. Повтор запрашивает ту же страницу.
class PersonalizationSearchResultsScreen
    extends PersonalizationResultsScreenBase<SearchProduct> {
  const PersonalizationSearchResultsScreen({
    super.key,
    super.sdk,
    super.shopId,
    required this.query,
    super.titleText,
    super.pageSize,
    super.sortBy,
    super.sortDir,
    super.locations,
    super.infiniteScroll,
    super.showFilters,
    super.showSort,
    super.facets,
    super.maxFacets,
    super.productActionText,
    super.showRating,
    super.layout,
    super.imageAspect,
    super.onBack,
    super.onSortTap,
    super.onProductTap,
    super.onProductAction,
    super.onError,
    super.foundPrefix = 'Found',
    super.foundSuffix = 'products',
    super.countPrefix,
    super.countSeparator,
    super.loadMoreText,
    super.emptyText = 'No results for your request.',
    super.errorText,
    super.retryText,
    super.filtersTitle,
    super.resetText,
    super.applyText,
    super.showMoreText,
    super.showLessText,
    super.priceTitle,
    super.fromLabel,
    super.toLabel,
    super.brandsTitle,
    super.colorsTitle,
    super.sizesTitle,
    super.facetTitle,
    super.facetValueTitle,
    super.showValueCounts,
    super.iconBuilder,
  });

  /// Поисковая фраза; смена перезапрашивает первую страницу. Она же заголовок, когда
  /// [titleText] не задан.
  final String query;

  static const String defaultErrorText =
      PersonalizationResultsScreenBase.defaultErrorText;
  static const String defaultRetryText =
      PersonalizationResultsScreenBase.defaultRetryText;

  @override
  State<PersonalizationSearchResultsScreen> createState() =>
      _PersonalizationSearchResultsScreenState();
}

class _PersonalizationSearchResultsScreenState
    extends
        PersonalizationResultsScreenState<
          SearchProduct,
          PersonalizationSearchResultsScreen
        > {
  String get _text => widget.query.trim();

  @override
  String get screenName => 'PersonalizationSearchResultsScreen';

  @override
  bool get hasSource => _text.isNotEmpty;

  @override
  bool sourceChanged(PersonalizationSearchResultsScreen oldWidget) =>
      oldWidget.query != widget.query;

  @override
  String get defaultTitle => widget.query;

  /// Каждая новая выдача — новый поиск: фраза, фильтры, сортировка.
  @override
  void onNewResults(PersonalizationSdk sdk) {
    sdk.tracking.search(_text);
  }

  @override
  Future<PersonalizationResultsPage<SearchProduct>> fetch(
    PersonalizationSdk sdk,
    int page,
    PersonalizationSearchApplied applied,
  ) async {
    final response = await sdk.searchFull(
      _text,
      params: SearchParams(
        page: page,
        limit: widget.pageSize,
        sortBy: widget.sortBy,
        sortDir: widget.sortDir,
        locations: widget.locations,
        brands: applied.brandsParam,
        priceMin: applied.priceMinParam,
        priceMax: applied.priceMaxParam,
        colors: applied.colors.isEmpty ? null : applied.colors.toList(),
        fashionSizes: applied.sizes.isEmpty ? null : applied.sizes.toList(),
        filters: applied.facetsParam,
      ),
    );
    final range = response.priceRange;
    final industrial = response.industrialFilters;
    return PersonalizationResultsPage<SearchProduct>(
      products: response.products,
      total: response.productsTotal,
      priceRange: range == null ? null : (min: range.min, max: range.max),
      brands: response.brands,
      brandCounts: response.brandCounts,
      colors: industrial?.colors ?? const <String>[],
      colorCounts: industrial?.colorCounts ?? const <String, int>{},
      sizes: industrial?.fashionSizes ?? const <String>[],
      sizeCounts: industrial?.fashionSizeCounts ?? const <String, int>{},
      filters: response.filters,
    );
  }

  @override
  void productTapped(SearchProduct product) {
    if (_text.isNotEmpty) {
      sdk?.tracking.setSource(
        TrackingSource(type: TrackingSourceType.fullSearch, code: _text),
      );
    }
    super.productTapped(product);
  }

  @override
  PersonalizationProduct card(SearchProduct product) =>
      productFromSearch(product, actionText: widget.productActionText);

  @override
  String idOf(SearchProduct product) => product.id;
}
