// What a native bridge hands Dart over the typed channel, made from the API's JSON
// for the tests: the JSON is read with the released models' `fromJson` and turned
// into the channel's models, the way the native SDKs read an answer into their own
// models. Test-only.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

final MessageCodec<Object?> codec =
    pigeon.PersonalizationHostApi.pigeonChannelCodec;

/// The channel of host method [method].
String hostChannel(String method) =>
    'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationHostApi.$method';

/// A successful reply of the channel carrying [value].
ByteData okReply(Object? value) => codec.encodeMessage(<Object?>[value])!;

/// A failed reply: the native error of [type], as the bridges send it.
ByteData errorReply(
  String type, {
  String? message,
  int? httpCode,
  String? serverCode,
}) => codec.encodeMessage(<Object?>[
  type,
  message ?? type,
  <String, Object?>{'httpCode': httpCode, 'serverCode': serverCode},
])!;

/// Answers host method [method] with [reply], recording the arguments of each
/// call in the returned list.
List<List<Object?>> stubHost(
  String method,
  ByteData Function(List<Object?> args) reply,
) {
  final calls = <List<Object?>>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(hostChannel(method), (message) async {
        final args = codec.decodeMessage(message) as List<Object?>? ?? const [];
        calls.add(args);
        return reply(args);
      });
  return calls;
}

/// Answers [method] with [value] every time.
List<List<Object?>> stubValue(String method, Object? value) =>
    stubHost(method, (_) => okReply(value));

/// Removes the stub of [method].
void unstub(String method) => TestDefaultBinaryMessengerBinding
    .instance
    .defaultBinaryMessenger
    .setMockMessageHandler(hostChannel(method), null);

/// A snapshot of a shop as the native side reports it.
pigeon.SdkSnapshotWire snapshotWire(
  String shopId, {
  String state = 'ready',
  String? deviceId = 'did-1',
  String? sessionId = 'sid-1',
  String? segment = 'A',
  bool agentEnabled = false,
  pigeon.PushTokenWire? pushToken,
  List<pigeon.PushTokenWire> pushTokens = const [],
}) => pigeon.SdkSnapshotWire(
  shopId: shopId,
  state: state,
  deviceId: deviceId,
  sessionId: sessionId,
  segment: segment,
  agentEnabled: agentEnabled,
  pushToken: pushToken,
  pushTokens: pushTokens,
);

/// Sends [message] of the state channel's [method] as the native side does.
Future<void> sendStateEvent(String method, List<Object?> args) async {
  final channel =
      'dev.flutter.pigeon.personalization_flutter_sdk.PersonalizationStateFlutterApi.$method';
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(channel, codec.encodeMessage(args), (_) {});
}

/// A product with every field of the contract set.
pigeon.ProductWire fullProduct({String id = 'p1'}) => pigeon.ProductWire(
  id: id,
  groupId: 'g1',
  name: 'Kettle',
  brand: 'Bosch',
  model: 'TWK',
  description: 'A kettle',
  barcode: '4600000000000',
  url: 'https://shop.test/p1',
  deeplinkAndroid: 'shop://p1',
  deeplinkIos: 'shop-ios://p1',
  imageUrl: 'https://img.test/p1.jpg',
  picture: 'https://img.test/p1-180.jpg',
  resizedImages: const {'120': 'https://img.test/p1-120.jpg'},
  price: 1990,
  priceFormatted: '1 990 ₽',
  priceFull: 1990.5,
  priceFullFormatted: '1 990,50 ₽',
  oldPrice: 2490,
  oldPriceFormatted: '2 490 ₽',
  oldPriceFull: 2490.9,
  oldPriceFullFormatted: '2 490,90 ₽',
  currency: '₽',
  discountPercent: 20,
  discountFormatted: '20%',
  salesRate: 70,
  relativeSalesRate: 0.7,
  rating: 4,
  isNew: true,
  stockQuantity: 12,
  categoryIds: const ['c1', 'c2'],
  categories: [
    pigeon.ProductCategoryWire(
      id: 'c1',
      name: 'Kitchen',
      url: '/kitchen',
      parentId: 'c0',
      level: 2,
    ),
  ],
  params: [
    pigeon.ProductParamWire(key: 'Power', values: const ['2200']),
  ],
  locationIds: const ['msk'],
);

pigeon.ProductCategoryWire _category(ProductCategory c) =>
    pigeon.ProductCategoryWire(
      id: c.id,
      name: c.name,
      url: c.url,
      parentId: c.parentId,
      level: c.level,
      count: c.count,
      alias: c.alias,
    );

List<pigeon.ProductParamWire> _params(List<ProductParam> params) => params
    .map((p) => pigeon.ProductParamWire(key: p.key, values: p.values))
    .toList();

/// A product of the API's JSON as the native model hands it over.
pigeon.ProductWire productWireFromJson(Map<String, dynamic> json) {
  final p = Product.fromJson(json);
  return pigeon.ProductWire(
    id: p.id,
    groupId: p.groupId,
    name: p.name,
    brand: json['brand'] == null ? null : p.brand,
    model: p.model,
    description: json['description'] == null ? null : p.description,
    barcode: p.barcode,
    url: p.url,
    deeplinkAndroid: p.deeplinkAndroid,
    deeplinkIos: p.deeplinkIos,
    imageUrl: json['image_url'] == null ? null : p.imageUrl,
    picture: p.picture,
    resizedImages: p.resizedImages.isEmpty ? null : p.resizedImages,
    price: p.price,
    priceFormatted: p.priceFormatted,
    priceFull: json['price_full'] == null ? null : p.priceFull,
    priceFullFormatted: p.priceFullFormatted,
    oldPrice: p.oldPrice,
    oldPriceFormatted: p.oldPriceFormatted,
    oldPriceFull: p.oldPriceFull,
    oldPriceFullFormatted: p.oldPriceFullFormatted,
    currency: p.currency,
    discountPercent: p.discountPercent ?? p.discount,
    discountFormatted: p.discountFormatted,
    salesRate: json['sales_rate'] == null ? null : p.salesRate,
    relativeSalesRate: json['relative_sales_rate'] == null
        ? null
        : p.relativeSalesRate,
    rating: p.rating,
    isNew: p.isNew ?? false,
    stockQuantity: p.stockQuantity,
    categoryIds: p.categoryIds,
    categories: p.categories.map(_category).toList(),
    params: _params(p.params),
    locationIds: p.locationIds,
  );
}

List<pigeon.ProductWire> _products(Object? raw) => (raw as List<dynamic>? ?? [])
    .whereType<Map>()
    .map((e) => productWireFromJson(Map<String, dynamic>.from(e)))
    .toList();

List<pigeon.BrandWire>? _brands(Object? raw) => raw is List
    ? raw
          .map(
            (e) => e is Map
                ? pigeon.BrandWire(
                    name: e['name']?.toString() ?? '',
                    count: (e['count'] as num?)?.toInt() ?? 0,
                  )
                : pigeon.BrandWire(name: e.toString(), count: 0),
          )
          .toList()
    : null;

Map<String, pigeon.SearchFilterWire>? _filters(Map<String, SearchFilter> f) =>
    f.isEmpty
    ? null
    : f.map(
        (name, filter) => MapEntry(
          name,
          pigeon.SearchFilterWire(
            count: filter.count,
            values: filter.values,
            priority: filter.priority,
            min: filter.min,
            max: filter.max,
          ),
        ),
      );

List<pigeon.ProductCategoryWire>? _categories(Object? raw) => raw is List
    ? raw
          .whereType<Map>()
          .map(
            (e) => _category(
              ProductCategory.fromJson(Map<String, dynamic>.from(e)),
            ),
          )
          .toList()
    : null;

List<pigeon.LocationWire>? _locations(Object? raw) => raw is List
    ? raw
          .whereType<Map>()
          .map(
            (e) => pigeon.LocationWire(
              id: e['id']?.toString() ?? '',
              name: e['name']?.toString() ?? '',
              type: e['type']?.toString(),
            ),
          )
          .toList()
    : null;

pigeon.PriceRangeWire? _priceRange(Object? raw) => raw is Map
    ? pigeon.PriceRangeWire(
        min: (raw['min'] as num?)?.toDouble() ?? 0,
        max: (raw['max'] as num?)?.toDouble() ?? 0,
      )
    : null;

pigeon.IndustrialFiltersWire? _industrial(Object? raw) {
  if (raw is! Map) return null;
  List<T>? list<T>(Object? items, T Function(Map e) make) =>
      items is List ? items.whereType<Map>().map(make).toList() : null;
  return pigeon.IndustrialFiltersWire(
    colors: list(
      raw['colors'],
      (e) => pigeon.ColorFilterWire(
        color: e['color'].toString(),
        count: (e['count'] as num?)?.toInt() ?? 0,
      ),
    ),
    fashionSizes: list(
      raw['fashion_sizes'],
      (e) => pigeon.SizeFilterWire(
        size: e['size'].toString(),
        count: (e['count'] as num?)?.toInt() ?? 0,
      ),
    ),
  );
}

/// A listing (`/products`, a category) as the native model hands it over.
pigeon.ProductsListResponseWire productsListWireFromJson(
  Map<String, dynamic> json,
) => pigeon.ProductsListResponseWire(
  productsTotal: (json['products_total'] as num?)?.toInt(),
  products: _products(json['products']),
  categories: _categories(json['categories']),
  brands: _brands(json['brands']),
  locations: _locations(json['locations']),
  filters: _filters(ProductsListResponse.fromJson(json).filters),
  priceRange: _priceRange(json['price_range']),
);

pigeon.CollectionResponseWire collectionWireFromJson(
  Map<String, dynamic> json,
) => pigeon.CollectionResponseWire(products: _products(json['products']));

pigeon.RecommendationResponseWire recommendationWireFromJson(
  Map<String, dynamic> json,
) {
  final products = _products(json['recommends']);
  return pigeon.RecommendationResponseWire(
    id: (json['id'] as num?)?.toInt(),
    title: json['title'] as String?,
    products: products,
    itemIds: products.map((p) => p.id).toList(),
  );
}

List<pigeon.QueryWire>? _queries(Object? raw) => raw is List
    ? raw
          .whereType<Map>()
          .map(
            (e) => pigeon.QueryWire(
              name: e['name']?.toString() ?? '',
              url: e['url']?.toString(),
            ),
          )
          .toList()
    : null;

List<pigeon.PopularItemWire>? _popular(Object? raw) => raw is List
    ? raw
          .whereType<Map>()
          .map(
            (e) => pigeon.PopularItemWire(
              name: e['name']?.toString() ?? '',
              url: e['url']?.toString() ?? '',
            ),
          )
          .toList()
    : null;

pigeon.SearchFullResponseWire searchFullWireFromJson(
  Map<String, dynamic> json,
) => pigeon.SearchFullResponseWire(
  productsTotal: (json['products_total'] as num?)?.toInt(),
  products: _products(json['products']),
  categories: _categories(json['categories']),
  brands: _brands(json['brands']),
  locations: _locations(json['locations']),
  filters: _filters(SearchFullResponse.fromJson(json).filters),
  industrialFilters: _industrial(json['industrial_filters']),
  priceRange: _priceRange(json['price_range']),
);

pigeon.SearchInstantResponseWire searchInstantWireFromJson(
  Map<String, dynamic> json,
) => pigeon.SearchInstantResponseWire(
  productsTotal: (json['products_total'] as num?)?.toInt(),
  products: _products(json['products']),
  categories: _categories(json['categories']),
  queries: _queries(json['queries']),
  locations: _locations(json['locations']),
);

pigeon.SearchBlankResponseWire searchBlankWireFromJson(
  Map<String, dynamic> json,
) => pigeon.SearchBlankResponseWire(
  products: _products(json['products']),
  lastProducts: json['last_products'] == true,
  lastQueries: _queries(json['last_queries']),
  suggests: _queries(json['suggests']),
  popularCategories: _popular(json['popular_categories']),
);

pigeon.ProductCountersResponseWire countersWireFromJson(
  Map<String, dynamic> json,
) {
  final r = ProductCountersResponse.fromJson(json);
  pigeon.ProductCounterWire? counter(ProductCounter? c) => c == null
      ? null
      : pigeon.ProductCounterWire(
          view: c.view,
          cart: c.cart,
          purchase: c.purchase,
        );
  return pigeon.ProductCountersResponseWire(
    daily: counter(r.daily),
    now: counter(r.now),
    triggers: r.triggers == null
        ? null
        : pigeon.ProductCounterTriggersWire(
            backInStock: r.triggers!.backInStock,
            priceDrop: r.triggers!.priceDrop,
          ),
  );
}

/// A stories block of the API's JSON as the native model hands it over.
pigeon.StoriesBlockWire storiesWireFromJson(Map<String, dynamic> json) {
  final block = StoriesBlock.fromJson(json);
  pigeon.StoryProductWire product(StoryProduct p) => pigeon.StoryProductWire(
    id: p.id,
    name: p.name,
    brand: p.brand,
    picture: p.picture,
    imageUrl: p.imageUrl,
    price: p.price,
    priceFormatted: p.priceFormatted,
    oldPrice: p.oldPrice,
    oldPriceFormatted: p.oldPriceFormatted,
    discountPercent: p.discountPercent,
    promocode: p.promocode,
    priceWithPromocode: p.priceWithPromocode,
    priceWithPromocodeFormatted: p.priceWithPromocodeFormatted,
    currency: p.currency,
    url: p.url,
    deeplinkAndroid: p.deeplinkAndroid,
    deeplinkIos: p.deeplinkIos,
  );
  pigeon.StoryElementWire? element(StoryElement e) => switch (e) {
    StoryButtonElement() => pigeon.StoryElementWire(
      type: 'button',
      title: e.title,
      link: e.link,
      linkAndroid: e.linkAndroid,
      linkIos: e.linkIos,
      background: e.background,
      color: e.color,
      textBold: e.textBold,
    ),
    StoryProductElement() => pigeon.StoryElementWire(
      type: 'product',
      title: e.title,
      item: e.item == null ? null : product(e.item!),
    ),
    StoryProductsElement() => pigeon.StoryElementWire(
      type: 'products',
      showLabel: e.showLabel,
      hideLabel: e.hideLabel,
      products: e.products.map(product).toList(),
    ),
    StoryTextBlockElement() => pigeon.StoryElementWire(
      type: 'text_block',
      text: e.text,
      fontSize: e.fontSize,
      fontType: e.fontType,
      bold: e.bold,
      italic: e.italic,
      textAlign: e.textAlign,
      textColor: e.textColor,
      backgroundColor: e.backgroundColor,
      backgroundOpacity: e.backgroundOpacity,
      lineSpacing: e.lineSpacing,
      yOffset: e.yOffset,
      promocode: e.promocode,
    ),
    _ => null,
  };
  return pigeon.StoriesBlockWire(
    id: block.id,
    stories: [
      for (final story in block.stories)
        pigeon.StoryWire(
          id: story.id,
          name: story.name,
          avatar: story.avatar,
          viewed: story.viewed,
          pinned: story.pinned,
          startPosition: story.startPosition,
          slides: [
            for (final slide in story.slides)
              pigeon.StorySlideWire(
                id: slide.id,
                type: slide.type.name,
                background: slide.background,
                backgroundColor: slide.backgroundColor,
                preview: slide.preview,
                duration: slide.duration.inSeconds,
                elements: slide.elements
                    .map(element)
                    .whereType<pigeon.StoryElementWire>()
                    .toList(),
              ),
          ],
        ),
    ],
  );
}

// region the released bridges' parameter JSON, for fakes written against it

/// The parameters of a category request as the released bridges sent them
/// (`paramsJson`): null when there are none.
Map<String, Object>? legacyCategoryParams(pigeon.ProductsListRequestWire r) {
  final params = <String, Object>{
    if (r.brands != null) 'brands': r.brands!.join(','),
    if (r.locations != null) 'locations': r.locations!.join(','),
    if (r.filters != null && r.filters!.isNotEmpty) 'filters': r.filters!,
    'price_min': ?r.priceMin,
    'price_max': ?r.priceMax,
    'sort_by': ?r.sortBy,
    'sort_dir': ?r.sortDir,
  };
  return params.isEmpty ? null : params;
}

/// The parameters of a full search as the released `SearchParams.toJson` had them.
Map<String, dynamic> legacySearchParams(pigeon.SearchFullRequestWire r) =>
    <String, dynamic>{
      'limit': ?r.limit,
      'page': ?r.page,
      'category_limit': ?r.categoryLimit,
      'brand_limit': ?r.brandLimit,
      'categories': ?r.categoryIds,
      'sort_by': ?r.sortBy,
      'sort_dir': ?r.sortDir,
      if (r.locations != null) 'locations': r.locations!.join(','),
      'excluded_brands': ?r.excludedBrands,
      if (r.brands != null) 'brands': r.brands!.join(','),
      'price_min': ?r.priceMin,
      'price_max': ?r.priceMax,
      'colors': ?r.colors,
      'fashion_sizes': ?r.fashionSizes,
      if (r.filters != null && r.filters!.isNotEmpty) 'filters': r.filters,
    };

/// The parameters of a recommendation block as the released bridges sent them.
String legacyRecommendationParams(pigeon.RecommendationRequestWire r) =>
    jsonEncode(<String, Object?>{
      'item_id': ?r.itemId,
      'category_id': ?r.categoryId,
      if (r.locations != null) 'locations': r.locations!.join(','),
      'with_locations': r.withLocations,
    });

// endregion
