import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

import '../support/wire.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    for (final method in [
      'productsGetInfo',
      'productsGetList',
      'productsGetCounters',
      'productsGetCategory',
    ]) {
      unstub(method);
    }
  });

  group('products.getInfo', () {
    test('sends the item id and the handle\'s shop', () async {
      final calls = stubValue('productsGetInfo', fullProduct());
      await PersonalizationSdk(shopId: 'shop-a').products.getInfo('37');
      expect(calls.single, ['37', 'shop-a']);
    });

    test('maps every field of the contract onto Product', () async {
      stubValue('productsGetInfo', fullProduct());
      final p = (await PersonalizationSdk().products.getInfo('p1'))!;
      expect(p.id, 'p1');
      expect(p.groupId, 'g1');
      expect(p.name, 'Kettle');
      expect(p.brand, 'Bosch');
      expect(p.model, 'TWK');
      expect(p.description, 'A kettle');
      expect(p.barcode, '4600000000000');
      expect(p.url, 'https://shop.test/p1');
      expect(p.deeplinkAndroid, 'shop://p1');
      expect(p.deeplinkIos, 'shop-ios://p1');
      expect(p.imageUrl, 'https://img.test/p1.jpg');
      expect(p.picture, 'https://img.test/p1-180.jpg');
      expect(p.resizedImages, {'120': 'https://img.test/p1-120.jpg'});
      expect(p.price, 1990);
      expect(p.priceFormatted, '1 990 ₽');
      expect(p.priceFull, 1990.5);
      expect(p.priceFullFormatted, '1 990,50 ₽');
      expect(p.oldPrice, 2490);
      expect(p.oldPriceFormatted, '2 490 ₽');
      expect(p.oldPriceFull, 2490.9);
      expect(p.oldPriceFullFormatted, '2 490,90 ₽');
      expect(p.currency, '₽');
      expect(p.discountPercent, 20);
      expect(p.discount, 20, reason: 'the released field keeps its value');
      expect(p.discountFormatted, '20%');
      expect(p.salesRate, 70);
      expect(p.relativeSalesRate, 0.7);
      expect(p.rating, 4);
      expect(p.isNew, isTrue);
      expect(p.stockQuantity, 12);
      expect(p.categoryIds, ['c1', 'c2']);
      expect(p.categories.single.id, 'c1');
      expect(p.categories.single.name, 'Kitchen');
      expect(p.categories.single.parentId, 'c0');
      expect(p.categories.single.level, 2);
      expect(p.params.single.key, 'Power');
      expect(p.params.single.values, ['2200']);
      expect(p.locationIds, ['msk']);
    });

    test('a product the catalog does not have is null', () async {
      stubValue('productsGetInfo', null);
      expect(await PersonalizationSdk().products.getInfo('nope'), isNull);
    });

    test('the optional released fields keep their released defaults', () async {
      stubValue(
        'productsGetInfo',
        pigeon.ProductWire(
          id: 'x',
          name: 'X',
          url: 'u',
          price: 1,
          currency: 'EUR',
          isNew: false,
        ),
      );
      final p = (await PersonalizationSdk().products.getInfo('x'))!;
      expect(p.brand, '');
      expect(p.description, '');
      expect(p.imageUrl, '');
      expect(p.priceFull, 0);
      expect(p.salesRate, 0);
      expect(p.categories, isEmpty);
      expect(p.params, isEmpty);
      expect(p.oldPrice, isNull);
    });

    test('an invalid argument of the native side is an SdkException', () async {
      stubHost(
        'productsGetInfo',
        (_) => errorReply('invalidArgument', message: 'itemId is empty'),
      );
      await expectLater(
        PersonalizationSdk().products.getInfo(''),
        throwsA(
          isA<SdkException>()
              .having((e) => e.type, 'type', 'invalidArgument')
              .having(
                (e) => e.error,
                'error',
                const SdkErrorInvalidArgument('itemId is empty'),
              ),
        ),
      );
    });
  });

  group('products.getList', () {
    test('sends the request; none is the first page of the catalog', () async {
      final calls = stubValue(
        'productsGetList',
        pigeon.ProductsListResponseWire(products: const []),
      );
      await PersonalizationSdk().products.getList();
      await PersonalizationSdk().products.getList(
        request: const ProductsListRequest(
          categoryIds: ['1', '2'],
          brands: ['Apple'],
          merchants: ['m1'],
          locations: ['msk'],
          priceMin: 10,
          priceMax: 99.5,
          sortBy: SortBy.salesRate,
          sortDir: SortDirection.desc,
          limit: 20,
          page: 3,
        ),
      );
      final empty = calls[0][0]! as pigeon.ProductsListRequestWire;
      expect(empty.categoryIds, isNull);
      expect(empty.limit, isNull);
      final r = calls[1][0]! as pigeon.ProductsListRequestWire;
      expect(r.categoryIds, ['1', '2']);
      expect(r.brands, ['Apple']);
      expect(r.merchants, ['m1']);
      expect(r.locations, ['msk']);
      expect([r.priceMin, r.priceMax], [10, 99.5]);
      expect([r.sortBy, r.sortDir], ['sales_rate', 'desc']);
      expect([r.limit, r.page], [20, 3]);
    });

    test('maps the listing with its facets', () async {
      stubValue(
        'productsGetList',
        pigeon.ProductsListResponseWire(
          productsTotal: 120,
          products: [fullProduct()],
          categories: [
            pigeon.ProductCategoryWire(
              id: 'c1',
              name: 'Kitchen',
              count: 7,
              alias: 'kitchen',
            ),
          ],
          brands: [pigeon.BrandWire(name: 'Bosch', count: 3)],
          locations: [pigeon.LocationWire(id: 'msk', name: 'Moscow')],
          filters: {
            'Цвет': pigeon.SearchFilterWire(
              count: 5,
              priority: 1,
              values: const {'red': 3},
            ),
            'Вес': pigeon.SearchFilterWire(count: 2, min: 1, max: 9.5),
          },
          industrialFilters: pigeon.IndustrialFiltersWire(
            colors: [pigeon.ColorFilterWire(color: 'red', count: 4)],
          ),
          priceRange: pigeon.PriceRangeWire(min: 100, max: 900),
          priceRanges: [
            pigeon.PriceIntervalWire(from: 0, to: 500, count: 6),
            pigeon.PriceIntervalWire(from: 500, count: 1),
          ],
          priceMedian: 450,
        ),
      );
      final r = await PersonalizationSdk().products.getList();
      expect(r.productsTotal, 120);
      expect(r.products.single.id, 'p1');
      expect(r.categories.single.count, 7);
      expect(r.categories.single.alias, 'kitchen');
      expect(r.brands, ['Bosch']);
      expect(r.brandCounts, {'Bosch': 3});
      expect(r.locations!.single.name, 'Moscow');
      expect(r.filters['Цвет']!.values, {'red': 3});
      expect(r.filters['Цвет']!.priority, 1);
      expect([r.filters['Вес']!.min, r.filters['Вес']!.max], [1, 9.5]);
      expect(r.industrialFilters!.colorCounts, {'red': 4});
      expect([r.priceRange!.min, r.priceRange!.max], [100, 900]);
      expect(r.priceRanges.first.to, 500);
      expect(r.priceRanges.last.to, isNull);
      expect(r.priceMedian, 450);
    });
  });

  group('products.getCounters', () {
    test('sends the item and maps the counters', () async {
      final calls = stubValue(
        'productsGetCounters',
        pigeon.ProductCountersResponseWire(
          daily: pigeon.ProductCounterWire(view: 10, cart: 2, purchase: 1),
          now: pigeon.ProductCounterWire(view: 1, cart: 0, purchase: 0),
          triggers: pigeon.ProductCounterTriggersWire(
            backInStock: 3,
            priceDrop: 4,
          ),
        ),
      );
      final c = await PersonalizationSdk().products.getCounters('37');
      expect(calls.single[0], '37');
      expect([c.daily!.view, c.daily!.cart, c.daily!.purchase], [10, 2, 1]);
      expect(c.now!.view, 1);
      expect([c.triggers!.backInStock, c.triggers!.priceDrop], [3, 4]);
    });
  });

  group('products.getCategory', () {
    test('sends the category and its request', () async {
      final calls = stubValue(
        'productsGetCategory',
        pigeon.ProductsListResponseWire(products: const []),
      );
      await PersonalizationSdk().products.getCategory(
        'kitchen',
        request: const CategoryRequest(
          brands: ['Bosch'],
          locations: ['msk'],
          priceMin: 1,
          priceMax: 2,
          sortBy: SortBy('popular'),
          sortDir: SortDirection.asc,
          limit: 5,
          page: 2,
        ),
      );
      expect(calls.single[0], 'kitchen');
      final r = calls.single[1]! as pigeon.ProductsListRequestWire;
      expect(r.brands, ['Bosch']);
      expect(r.locations, ['msk']);
      expect(r.categoryIds, isNull, reason: 'the category goes on its own');
      expect(r.merchants, isNull);
      expect([r.priceMin, r.priceMax], [1, 2]);
      expect([r.sortBy, r.sortDir], ['popular', 'asc']);
      expect([r.limit, r.page], [5, 2]);
    });

    test('maps the category answer', () async {
      stubValue(
        'productsGetCategory',
        pigeon.ProductsListResponseWire(
          productsTotal: 2,
          products: [
            fullProduct(),
            fullProduct(id: 'p2'),
          ],
          categories: [pigeon.ProductCategoryWire(id: 'c1', name: 'Kitchen')],
          brands: [pigeon.BrandWire(name: 'Bosch', count: 2)],
          priceRange: pigeon.PriceRangeWire(min: 1, max: 2),
          priceRanges: [pigeon.PriceIntervalWire(from: 0, count: 2)],
          priceMedian: 1.5,
        ),
      );
      final r = await PersonalizationSdk().products.getCategory('kitchen');
      expect(r.productsTotal, 2);
      expect(r.products.map((p) => p.id), ['p1', 'p2']);
      expect(r.categories.single.name, 'Kitchen');
      expect(r.brandCounts, {'Bosch': 2});
      expect(r.priceRange!.max, 2);
      expect(r.priceRanges.single.count, 2);
      expect(r.priceMedian, 1.5);
    });

    test('an HTTP failure carries its codes', () async {
      stubHost(
        'productsGetCategory',
        (_) => errorReply('http', httpCode: 404, serverCode: 'not_found'),
      );
      await expectLater(
        PersonalizationSdk().products.getCategory('x'),
        throwsA(
          isA<SdkException>()
              .having((e) => e.httpCode, 'httpCode', 404)
              .having((e) => e.serverCode, 'serverCode', 'not_found')
              .having(
                (e) => e.error,
                'error',
                const SdkErrorHttp(404, serverCode: 'not_found'),
              ),
        ),
      );
    });
  });
}
