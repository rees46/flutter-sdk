import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../collection/collection_response.dart';
import '../../multi_instance/rees46.dart';
import '../../personalization_sdk.dart';
import '../../recommendation/recommendation_params.dart';
import '../../recommendation/recommendation_response.dart';
import '../../tracking/tracking_models.dart';
import '../components/personalization_product.dart';
import '../components/personalization_product_image.dart';
import '../components/personalization_products_block.dart';
import '../components/personalization_products_list.dart';
import 'personalization_load_state.dart';
import 'personalization_request_cache.dart';
import 'product_mapping.dart';

/// Управление [PersonalizationRecommenderBlock] снаружи.
class PersonalizationRecommenderBlockController {
  _PersonalizationRecommenderBlockState? _block;

  /// Загрузить блок заново — мимо кэша и мимо запроса в полёте. Показанный блок до
  /// ответа остаётся на экране: новые товары его заменят, пустой ответ или ошибка
  /// скроют. Завершается, когда ответ пришёл; блока в дереве нет — сразу.
  Future<void> reload() => _block?._start(force: true) ?? Future<void>.value();
}

/// Блок рекомендаций с данными SDK: сам грузит товары и показывает их
/// [PersonalizationProductsBlock] — заголовок, карусель, плитка или список.
///
/// Паттерн Recommender из Figma (Card — Recommender/Carousel 90:655, Recommender/Grid
/// 126:1944, Recommender/List 126:2551). Источник — ровно один: блок рекомендаций [code]
/// (`getRecommendation`; для «похожих» и «с этим покупают» — [itemId] и [categoryId],
/// ещё [locations]) или коллекция [collectionId]
/// ([PersonalizationRecommenderBlock.collection], `getCollection`).
///
/// Инстанс SDK: [sdk] явно, иначе [shopId] или единственный зарегистрированный
/// (`REES46.getInstance`).
///
/// Пока ответа нет, блока нет: он не занимает места и заглушек не рисует. Пришли
/// товары — блок проявляется за 150 мс. Товаров меньше [minProducts], ответ пуст или
/// запрос не удался — блок остаётся скрытым, ошибка уходит в [onError]. [onLoaded] после
/// каждого ответа получает число показанных товаров, у скрытого блока — 0.
///
/// Ответы общие на процесс и живут в кэше 10 минут: второй блок с теми же параметрами
/// (лента пересоздала ячейку) показывает товары в первом же кадре, без запроса.
/// [PersonalizationRecommenderBlockController.reload] грузит мимо кэша. Смена источника,
/// его параметров, [sdk] или [shopId] — новая загрузка.
///
/// Нажатие на товар блока [code] и на кнопку карточки (есть, если задан [actionText])
/// запоминают источник `dynamic` с кодом блока (`tracking.setSource`), потом отдают
/// товар в [onProductTap] и [onProductAction]: «в корзину» прямо из блока — главный
/// случай атрибуции. У коллекции источник не ставится.
class PersonalizationRecommenderBlock extends StatefulWidget {
  /// Блок рекомендаций [code].
  const PersonalizationRecommenderBlock({
    super.key,
    required String this.code,
    this.itemId,
    this.categoryId,
    this.locations,
    this.sdk,
    this.shopId,
    this.controller,
    this.layout = PersonalizationProductsLayout.carousel,
    this.title,
    this.limit,
    this.minProducts = 1,
    this.imageAspect = PersonalizationProductImageAspect.square,
    this.actionText,
    this.showAllText,
    this.onShowAll,
    this.showDots = true,
    this.showRating = false,
    this.onProductTap,
    this.onProductAction,
    this.onLoaded,
    this.onError,
    this.iconBuilder,
  }) : collectionId = null,
       assert(limit == null || limit > 0);

  /// Товары коллекции [collectionId]. Своего заголовка у коллекции нет: строка
  /// заголовка — только если задан [title].
  const PersonalizationRecommenderBlock.collection({
    super.key,
    required String this.collectionId,
    this.sdk,
    this.shopId,
    this.controller,
    this.layout = PersonalizationProductsLayout.carousel,
    this.title,
    this.limit,
    this.minProducts = 1,
    this.imageAspect = PersonalizationProductImageAspect.square,
    this.actionText,
    this.showAllText,
    this.onShowAll,
    this.showDots = true,
    this.showRating = false,
    this.onProductTap,
    this.onProductAction,
    this.onLoaded,
    this.onError,
    this.iconBuilder,
  }) : code = null,
       itemId = null,
       categoryId = null,
       locations = null,
       assert(limit == null || limit > 0);

  /// Код блока рекомендаций; у коллекции — `null`.
  final String? code;

  /// Товар, который сейчас смотрит пользователь, — для «похожих» и «с этим покупают».
  final String? itemId;

  /// Категория, которую сейчас смотрит пользователь.
  final String? categoryId;

  /// Список id локаций через запятую.
  final String? locations;

  /// Id коллекции; у блока рекомендаций — `null`.
  final String? collectionId;

  final PersonalizationSdk? sdk;
  final String? shopId;
  final PersonalizationRecommenderBlockController? controller;
  final PersonalizationProductsLayout layout;

  /// Заголовок блока. `null` — из ответа (у коллекции — без заголовка), пустая строка —
  /// без строки заголовка.
  final String? title;

  /// Сколько товаров показать, не больше; `null` — все из ответа.
  final int? limit;

  /// Сколько товаров нужно блоку: меньше — блок скрыт. Пустой блок не показывается и
  /// при значении меньше 1.
  final int minProducts;

  /// Пропорция картинок карточек, см. [PersonalizationProductsBlock.imageAspect].
  final PersonalizationProductImageAspect imageAspect;

  /// Подпись кнопки на карточке; `null` — без кнопки.
  final String? actionText;

  /// Подпись кнопки «показать все» у карусели; `null` — без кнопки.
  final String? showAllText;
  final VoidCallback? onShowAll;

  /// У карусели точки под лентой.
  final bool showDots;

  /// Рисовать ли рейтинг. В ответах API рейтинга нет, поэтому по умолчанию выключено.
  final bool showRating;

  /// Нажатие на карточку: товар с [PersonalizationProduct.url] и
  /// [PersonalizationProduct.deeplink] своей платформы.
  final ValueChanged<PersonalizationProduct>? onProductTap;
  final ValueChanged<PersonalizationProduct>? onProductAction;

  /// Ответ пришёл: сколько товаров показано, 0 — блок скрыт.
  final ValueChanged<int>? onLoaded;
  final ValueChanged<Object>? onError;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  @override
  State<PersonalizationRecommenderBlock> createState() =>
      _PersonalizationRecommenderBlockState();
}

class _PersonalizationRecommenderBlockState
    extends State<PersonalizationRecommenderBlock>
    with SingleTickerProviderStateMixin {
  /// Ответ — сырой ответ SDK: [RecommendationResponse] или [CollectionResponse].
  final PersonalizationLoadController<Object> _load =
      PersonalizationLoadController<Object>(isEmpty: _noProducts);
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  PersonalizationSdk? _sdk;
  PersonalizationCacheSubscription? _subscription;
  Completer<Object>? _pending;

  /// Что видно, пока грузится следующий ответ: свежий ответ из кэша у нового источника,
  /// прежний — у [PersonalizationRecommenderBlockController.reload]. `null` — блока нет.
  Object? _stale;

  /// Карточки ответа [_mappedFrom] с кнопкой [_mappedAction] — не собирать их в каждом
  /// build.
  Object? _mappedFrom;
  String? _mappedAction;
  List<PersonalizationProduct> _cards = const <PersonalizationProduct>[];

  @override
  void initState() {
    super.initState();
    widget.controller?._block = this;
    _load.addListener(_changed);
    _start();
  }

  @override
  void didUpdateWidget(PersonalizationRecommenderBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.controller;
    if (previous != widget.controller) {
      if (previous?._block == this) previous?._block = null;
      widget.controller?._block = this;
    }
    if (oldWidget.sdk != widget.sdk ||
        oldWidget.shopId != widget.shopId ||
        oldWidget.code != widget.code ||
        oldWidget.collectionId != widget.collectionId ||
        oldWidget.itemId != widget.itemId ||
        oldWidget.categoryId != widget.categoryId ||
        oldWidget.locations != widget.locations) {
      _start();
    }
  }

  @override
  void dispose() {
    if (widget.controller?._block == this) widget.controller?._block = null;
    _cancel();
    _load
      ..removeListener(_changed)
      ..dispose();
    _fade.dispose();
    super.dispose();
  }

  /// Ответ на экране: пришедший или тот, что виден, пока грузится следующий.
  Object? get _shown => switch (_load.value) {
    PersonalizationLoadContent<Object>(:final data) => data,
    PersonalizationLoadLoading<Object>() => _stale,
    _ => null,
  };

  /// Резолвит инстанс и грузит блок. [force] — мимо кэша, прежний блок стоит на экране
  /// до ответа; иначе — новый источник: виден сразу только свежий ответ из кэша.
  Future<void> _start({bool force = false}) {
    final shown = _shown;
    _cancel();
    final PersonalizationSdk sdk;
    try {
      sdk = widget.sdk ?? REES46.getInstance(widget.shopId);
    } catch (error) {
      debugPrint(
        'PersonalizationRecommenderBlock: cannot resolve an SDK for '
        'shopId=${widget.shopId} — $error',
      );
      _sdk = null;
      _stale = null;
      return _load.load(() => Future<Object>.error(error));
    }
    _sdk = sdk;
    final key = _key(sdk);
    _stale = force ? shown : PersonalizationRequestCache.shared.peek(key);
    // Видимое сразу не проявляется заново: проявление — только после пустоты.
    _fade.value = _stale == null ? 0 : 1;
    final load = _request(sdk);
    return _load.load(() => _fetch(key, load, force: force));
  }

  String _key(PersonalizationSdk sdk) {
    final code = widget.code;
    if (code == null) {
      return PersonalizationRequestCache.keyOf(sdk.shopId, 'collection', {
        'collection_id': widget.collectionId,
      });
    }
    return PersonalizationRequestCache.keyOf(sdk.shopId, 'recommend', {
      'code': code,
      'item_id': widget.itemId,
      'category_id': widget.categoryId,
      'locations': widget.locations,
    });
  }

  /// Запрос в SDK по нынешним параметрам — собирается сразу, а не при вызове.
  Future<Object> Function() _request(PersonalizationSdk sdk) {
    final code = widget.code;
    if (code == null) {
      final collectionId = widget.collectionId!;
      return () => sdk.getCollection(collectionId);
    }
    final params = RecommendationParams(
      itemId: widget.itemId,
      categoryId: widget.categoryId,
      locations: widget.locations,
    );
    return () => sdk.getRecommendation(code, params: params);
  }

  Future<Object> _fetch(
    String key,
    Future<Object> Function() load, {
    required bool force,
  }) {
    final answer = _pending = Completer<Object>();
    _subscription = PersonalizationRequestCache.shared.fetch<Object>(
      key,
      load,
      onValue: answer.complete,
      onError: answer.completeError,
      force: force,
    );
    return answer.future;
  }

  /// Отписка от ответа в полёте. Его ожидание завершается ошибкой, которую контроллер
  /// загрузки отбросит как устаревшую: иначе перебитый [_start] (и `reload()` хоста,
  /// который его ждёт) не завершился бы никогда.
  void _cancel() {
    _subscription?.cancel();
    _subscription = null;
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const _Superseded());
    }
  }

  /// Ответ или ошибка пришли — колбэки хоста и проявление блока. Состояние приходит
  /// асинхронно, не посреди сборки.
  void _changed() {
    switch (_load.value) {
      case PersonalizationLoadContent<Object>(:final data):
        _stale = null;
        if (_fade.value == 0 && !_fade.isAnimating) _fade.forward();
        widget.onLoaded?.call(_visible(data).length);
      case PersonalizationLoadEmpty<Object>():
        _stale = null;
        _fade.value = 0;
        widget.onLoaded?.call(0);
      case PersonalizationLoadError<Object>(:final error):
        _stale = null;
        _fade.value = 0;
        widget.onError?.call(error);
      case PersonalizationLoadIdle<Object>() ||
          PersonalizationLoadLoading<Object>():
        break;
    }
  }

  static bool _noProducts(Object answer) => switch (answer) {
    RecommendationResponse(:final products) => products.isEmpty,
    CollectionResponse(:final products) => products.isEmpty,
    _ => true,
  };

  /// Карточки, которые покажет блок: не больше [PersonalizationRecommenderBlock.limit];
  /// меньше [PersonalizationRecommenderBlock.minProducts] — ни одной.
  List<PersonalizationProduct> _visible(Object answer) {
    final actionText = widget.actionText;
    if (!identical(answer, _mappedFrom) || actionText != _mappedAction) {
      _mappedFrom = answer;
      _mappedAction = actionText;
      _cards = switch (answer) {
        RecommendationResponse(:final products) => <PersonalizationProduct>[
          for (final product in products)
            productFromRecommendation(product, actionText: actionText),
        ],
        CollectionResponse(:final products) => <PersonalizationProduct>[
          for (final product in products)
            productFromCatalog(product, actionText: actionText),
        ],
        _ => const <PersonalizationProduct>[],
      };
    }
    final limit = widget.limit;
    final cards = limit == null || _cards.length <= limit
        ? _cards
        : _cards.sublist(0, limit);
    return cards.length < math.max(1, widget.minProducts)
        ? const <PersonalizationProduct>[]
        : cards;
  }

  /// Нажатие на карточку или её кнопку: сначала источник `dynamic` у блока [code],
  /// потом колбэк хоста.
  void _attributed(
    PersonalizationProduct product,
    ValueChanged<PersonalizationProduct>? callback,
  ) {
    final code = widget.code;
    final sdk = _sdk;
    if (code != null && sdk != null) unawaited(_trackSource(sdk, code));
    callback?.call(product);
  }

  /// Источник `dynamic` для следующих событий; сбой трекинга нажатию не мешает.
  static Future<void> _trackSource(PersonalizationSdk sdk, String code) async {
    try {
      await sdk.tracking.setSource(
        TrackingSource(type: TrackingSourceType.dynamicBlock, code: code),
      );
    } catch (error) {
      debugPrint('PersonalizationRecommenderBlock: setSource failed — $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PersonalizationLoadState<Object>>(
      valueListenable: _load,
      builder: (context, _, _) {
        final answer = _shown;
        if (answer == null) return const SizedBox.shrink();
        final cards = _visible(answer);
        if (cards.isEmpty) return const SizedBox.shrink();
        return FadeTransition(
          opacity: _fade,
          child: PersonalizationProductsBlock(
            layout: widget.layout,
            title:
                widget.title ??
                (answer is RecommendationResponse ? answer.title : null),
            showAllText: widget.showAllText,
            onShowAll: widget.onShowAll,
            showDots: widget.showDots,
            products: cards,
            imageAspect: widget.imageAspect,
            // Без колбэка хоста кнопка не нажимается — как у блока товаров.
            onProductAction: widget.onProductAction == null
                ? null
                : (product) => _attributed(product, widget.onProductAction),
            onProductTap: (product) =>
                _attributed(product, widget.onProductTap),
            showRating: widget.showRating,
            iconBuilder: widget.iconBuilder,
          ),
        );
      },
    );
  }
}

/// Ожидание ответа перебито новой загрузкой или уходом блока из дерева.
class _Superseded implements Exception {
  const _Superseded();
}
