import 'package:flutter/widgets.dart';

import '../../category/category_params.dart';
import '../../category/category_response.dart';
import '../../personalization_sdk.dart';
import '../components/personalization_product.dart';
import 'personalization_results_screen_base.dart';
import 'personalization_search_results_screen.dart';
import 'product_mapping.dart';

/// Экран категории с данными SDK — сестра [PersonalizationSearchResultsScreen] на том же
/// ядре: заголовок с названием категории и числом товаров, плитка ⇄ список, фильтры и
/// их теги, сортировка, счётчик, «загрузить ещё» или бесконечная прокрутка, пустое
/// состояние, ошибка с повтором. Виджет сам ходит в `getCategory` и держит состояние.
///
/// Источник — [categoryId]. Названия категории в ответе нет: заголовок задаёт хост через
/// [titleText], назад — [onBack]. Счётчик под заголовком — «N products»
/// ([foundPrefix] / [foundSuffix]).
///
/// Инстанс SDK: [sdk] явно, иначе [shopId] или единственный зарегистрированный
/// (`REES46.getInstance`).
///
/// Фасеты — как у поиска: бренды, диапазон цены и произвольные фасеты магазина
/// (`filters`) по тому же правилу [facets] / [maxFacets], с теми же подписями значений
/// ([facetValueTitle], `title` значений-объектов) и числами товаров. Цветов и размеров
/// (`industrial_filters`) у категории нет, их секций тоже. На iOS выпущенный нативный SDK
/// отдаёт из ответа категории только бренды.
///
/// Цена и сортировка: API категории их понимает, а нативные SDK, против которых собран
/// плагин, пока нет. До их релиза секции цены и кнопки сортировки на экране нет, а
/// [sortBy] / [sortDir] уходят в запрос без эффекта.
///
/// Трекинг: просмотр категории (`categoryView`) — один раз на категорию, а не на
/// страницы, фильтры, сортировку и повторы. Нажатие на карточку источник не ставит и
/// отдаёт товар через [onProductTap], кнопка карточки — через [onProductAction].
///
/// Ошибки — как у поиска: [onError], на первой странице [errorText] с кнопкой
/// [retryText], на следующей — повтор на месте «загрузить ещё».
class PersonalizationCategoryScreen
    extends PersonalizationResultsScreenBase<Product> {
  const PersonalizationCategoryScreen({
    super.key,
    super.sdk,
    super.shopId,
    required this.categoryId,
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
    super.foundPrefix = '',
    super.foundSuffix = 'products',
    super.countPrefix,
    super.countSeparator,
    super.loadMoreText,
    super.emptyText = 'No products in this category yet.',
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

  /// Id категории (слаг, как в `getCategory`); смена перезапрашивает первую страницу.
  final String categoryId;

  static const String defaultErrorText =
      PersonalizationResultsScreenBase.defaultErrorText;
  static const String defaultRetryText =
      PersonalizationResultsScreenBase.defaultRetryText;

  @override
  State<PersonalizationCategoryScreen> createState() =>
      _PersonalizationCategoryScreenState();
}

class _PersonalizationCategoryScreenState
    extends
        PersonalizationResultsScreenState<
          Product,
          PersonalizationCategoryScreen
        > {
  /// Инстанс и категория, чей просмотр уже ушёл: просмотр — один на категорию.
  (PersonalizationSdk, String)? _tracked;

  String get _id => widget.categoryId.trim();

  @override
  String get screenName => 'PersonalizationCategoryScreen';

  @override
  bool get hasSource => _id.isNotEmpty;

  @override
  bool sourceChanged(PersonalizationCategoryScreen oldWidget) =>
      oldWidget.categoryId != widget.categoryId;

  @override
  String get defaultTitle => '';

  @override
  bool get appliesPriceAndSort => categoryPriceAndSortApplied;

  @override
  void onNewResults(PersonalizationSdk sdk) {
    final key = (sdk, _id);
    if (_tracked == key) return;
    _tracked = key;
    sdk.tracking.categoryView(_id).catchError((Object error) {
      debugPrint('$screenName: category view not tracked — $error');
    });
  }

  @override
  Future<PersonalizationResultsPage<Product>> fetch(
    PersonalizationSdk sdk,
    int page,
    PersonalizationSearchApplied applied,
  ) async {
    final response = await sdk.getCategory(
      _id,
      limit: widget.pageSize,
      page: page,
      brands: applied.brandsParam,
      locations: widget.locations,
      filters: applied.facetsParam,
      priceMin: applied.priceMinParam,
      priceMax: applied.priceMaxParam,
      sortBy: widget.sortBy,
      sortDir: widget.sortDir,
    );
    final range = response.priceRange;
    return PersonalizationResultsPage<Product>(
      products: response.products,
      total: response.productsTotal,
      priceRange: range == null ? null : (min: range.min, max: range.max),
      brands: response.brands,
      brandCounts: response.brandCounts,
      filters: response.filters,
    );
  }

  @override
  PersonalizationProduct card(Product product) =>
      productFromCatalog(product, actionText: widget.productActionText);

  @override
  String idOf(Product product) => product.id;
}
