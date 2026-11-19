import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

import '../support/wire.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(REES46.reset);

  group('collections.get', () {
    tearDown(() => unstub('collectionsGet'));

    test('sends the collection id and maps its products', () async {
      final calls = stubValue(
        'collectionsGet',
        pigeon.CollectionResponseWire(products: [fullProduct()]),
      );
      final r = await PersonalizationSdk(shopId: 's').collections.get('12');
      expect(calls.single, ['12', 's']);
      expect(r.products.single.oldPriceFull, 2490.9);
    });
  });

  group('recommendations.get', () {
    tearDown(() => unstub('recommendationsGet'));

    test('sends the request; none is extended without locations', () async {
      final calls = stubValue(
        'recommendationsGet',
        pigeon.RecommendationResponseWire(
          products: const [],
          itemIds: const [],
        ),
      );
      await PersonalizationSdk().recommendations.get('block');
      await PersonalizationSdk().recommendations.get(
        'block',
        request: const RecommendationRequest(
          itemId: '37',
          categoryId: 'c1',
          searchQuery: 'kettle',
          excludedItemIds: ['1'],
          brands: ['Bosch'],
          locations: ['msk'],
          limit: 6,
          extended: true,
          withLocations: true,
        ),
      );
      final none = calls[0][1]! as pigeon.RecommendationRequestWire;
      expect([none.extended, none.withLocations], [true, false]);
      final r = calls[1][1]! as pigeon.RecommendationRequestWire;
      expect(calls[1][0], 'block');
      expect([r.itemId, r.categoryId, r.searchQuery], ['37', 'c1', 'kettle']);
      expect(r.excludedItemIds, ['1']);
      expect(r.brands, ['Bosch']);
      expect(r.locations, ['msk']);
      expect(r.limit, 6);
      expect(r.withLocations, isTrue);
    });

    test('maps the block: id, title, link, products, item ids', () async {
      stubValue(
        'recommendationsGet',
        pigeon.RecommendationResponseWire(
          id: 7,
          title: 'Popular',
          link: 'https://shop.test/popular',
          products: [fullProduct()],
          itemIds: const ['p1'],
        ),
      );
      final r = await PersonalizationSdk().recommendations.get('block');
      expect(r.id, 7);
      expect(r.title, 'Popular');
      expect(r.link, 'https://shop.test/popular');
      expect(r.itemIds, ['p1']);
      final product = r.products.single;
      expect(product.picture, 'https://img.test/p1-180.jpg');
      expect(product.model, 'TWK');
      expect(product.params!.single.key, 'Power');
      expect(product.discountPercent, 20);
    });
  });

  group('search', () {
    tearDown(() {
      for (final m in [
        'searchBlank',
        'searchInstant',
        'searchFull',
        'searchAgentDialog',
        'searchAgent',
        'initialize',
      ]) {
        unstub(m);
      }
    });

    test('blank maps queries, popular items and the products', () async {
      stubValue(
        'searchBlank',
        pigeon.SearchBlankResponseWire(
          products: [fullProduct()],
          lastProducts: true,
          lastQueries: [pigeon.QueryWire(name: 'kettle', url: '/s?q=kettle')],
          suggests: [pigeon.QueryWire(name: 'tea', score: 0.5)],
          popularCategories: [
            pigeon.PopularItemWire(name: 'Kitchen', url: '/k'),
          ],
          popularBrands: [pigeon.PopularItemWire(name: 'Bosch', url: '/b')],
          popularLinks: [pigeon.PopularItemWire(name: 'Sale', url: '/sale')],
        ),
      );
      final r = await PersonalizationSdk().search.blank();
      expect(r.products.single.id, 'p1');
      expect(r.lastProducts, isTrue);
      expect(r.lastQueries!.single.url, '/s?q=kettle');
      expect(r.suggests!.single.score, 0.5);
      expect(r.suggests!.single.url, isNull, reason: 'no link is null');
      expect(r.popularCategories!.single.name, 'Kitchen');
      expect(r.popularBrands!.single.name, 'Bosch');
      expect(r.popularLinks!.single.url, '/sale');
    });

    test('instant sends its lists and maps the answer', () async {
      final calls = stubValue(
        'searchInstant',
        pigeon.SearchInstantResponseWire(
          searchQuery: 'kettle',
          searchQueryOriginal: 'kettel',
          clarification: true,
          productsTotal: 1,
          products: [fullProduct()],
          categories: [pigeon.ProductCategoryWire(id: 'c1', name: 'K')],
          queries: [pigeon.QueryWire(name: 'kettle')],
          locations: [pigeon.LocationWire(id: 'msk', name: 'Moscow')],
          redirect: pigeon.SearchRedirectWire(query: 'sale', url: '/sale'),
        ),
      );
      final r = await PersonalizationSdk().search.instant(
        'kettel',
        locations: ['msk'],
        excludedMerchants: ['m'],
        excludedBrands: ['b'],
      );
      expect(calls.single.take(4), [
        'kettel',
        ['msk'],
        ['m'],
        ['b'],
      ]);
      expect(r.searchQuery, 'kettle');
      expect(r.searchQueryOriginal, 'kettel');
      expect(r.clarification, isTrue);
      expect(r.productsTotal, 1);
      expect(r.products.single.categories!.single.id, 'c1');
      expect(r.categories!.single.name, 'K');
      expect(r.queries!.single.name, 'kettle');
      expect(r.locations!.single.id, 'msk');
      expect(r.redirect!.url, '/sale');
    });

    test('full sends its request and maps the answer', () async {
      final calls = stubValue(
        'searchFull',
        pigeon.SearchFullResponseWire(
          productsTotal: 1,
          products: [fullProduct()],
          brands: [pigeon.BrandWire(name: 'Bosch', count: 1)],
          priceRange: pigeon.PriceRangeWire(min: 1, max: 2),
          priceRanges: [pigeon.PriceIntervalWire(from: 0, count: 1)],
          priceMedian: 1.5,
          searchQuery: 'kettle',
        ),
      );
      final r = await PersonalizationSdk().search.full(
        'kettle',
        request: const SearchFullRequest(
          excludedBrands: ['b'],
          excludedMerchants: ['m'],
          excludedItemIds: ['1'],
          sortBy: SortBy.relevance,
          disableClarification: true,
          categoryLimit: 3,
          brandLimit: 4,
          page: 2,
        ),
      );
      final request = calls.single[1]! as pigeon.SearchFullRequestWire;
      expect(request.excludedBrands, ['b']);
      expect(request.excludedMerchants, ['m']);
      expect(request.excludedItemIds, ['1']);
      expect(request.sortBy, 'relevance');
      expect(request.disableClarification, isTrue);
      expect([request.categoryLimit, request.brandLimit], [3, 4]);
      expect(request.page, 2);
      expect(r.brands!.single.name, 'Bosch');
      expect(r.brands!.single.count, 1);
      expect(r.priceRange!.max, 2);
      expect(r.priceRanges!.single.count, 1);
      expect(r.filters, isNull);
      expect(r.industrialFilters, isNull);
      expect(r.priceMedian, 1.5);
      expect(r.searchQuery, 'kettle');
    });

    test('the agent: dialog and message, 64-bit ids', () async {
      final session = pigeon.AgentSessionWire(
        id: 9007199254740993,
        title: 'Kettles',
        updatedAt: '2026-11-18T10:00:00Z',
        messages: [
          pigeon.AgentMessageWire(
            id: 1,
            role: 'assistant',
            content: 'Here you are',
            createdAt: '2026-11-18T10:00:00Z',
            products: [
              pigeon.AgentProductWire(
                id: 'p1',
                name: 'Kettle',
                price: 1990,
                reason: 'cheap',
              ),
            ],
          ),
        ],
      );
      final dialogCalls = stubValue(
        'searchAgentDialog',
        pigeon.AgentDialogResponseWire(sessions: [session], session: session),
      );
      final agentCalls = stubValue(
        'searchAgent',
        pigeon.AgentResponseWire(
          session: session,
          message: session.messages.single,
        ),
      );
      final sdk = PersonalizationSdk();
      final dialog = await sdk.search.agentDialog(
        sessionId: 9007199254740993,
        locations: ['msk'],
      );
      final answer = await sdk.search.agent('a kettle', sessionId: 5);
      expect(dialogCalls.single.take(2), [
        9007199254740993,
        ['msk'],
      ]);
      expect(agentCalls.single.take(3), ['a kettle', 5, null]);
      expect(dialog.sessions.single.id, 9007199254740993);
      final message = dialog.session!.messages.single;
      expect(message.role, AgentMessageRole.assistant);
      expect(message.products.single.reason, 'cheap');
      expect(answer.message.content, 'Here you are');
      expect(answer.session.title, 'Kettles');
    });

    test('agentEnabled is the copy of the native flag', () async {
      stubValue('initialize', snapshotWire('agent-shop', agentEnabled: true));
      final sdk = REES46.initialize(const REES46Config(shopId: 'agent-shop'));
      expect(sdk.search.agentEnabled, isFalse, reason: 'before the answer');
      await sdk.ready;
      expect(sdk.search.agentEnabled, isTrue);
      await sendStateEvent('onSnapshot', <Object?>[
        snapshotWire('agent-shop', agentEnabled: false),
      ]);
      expect(sdk.search.agentEnabled, isFalse);
    });
  });

  group('stories.get', () {
    tearDown(() => unstub('storiesGet'));

    test('maps the block, slides and every kind of element', () async {
      final product = pigeon.StoryProductWire(
        id: 'p1',
        name: 'Kettle',
        brand: 'Bosch',
        picture: 'pic',
        imageUrl: 'img',
        price: 10,
        priceFormatted: '10',
        oldPriceFormatted: '',
        discountPercent: 0,
        promocode: '',
        priceWithPromocode: 0,
        priceWithPromocodeFormatted: '',
        currency: '₽',
        url: 'u',
        deeplinkAndroid: '',
        deeplinkIos: '',
      );
      final calls = stubValue(
        'storiesGet',
        pigeon.StoriesBlockWire(
          id: 'block',
          stories: [
            pigeon.StoryWire(
              id: '1',
              name: 'Story',
              avatar: 'a',
              viewed: true,
              pinned: false,
              startPosition: 1,
              slides: [
                pigeon.StorySlideWire(
                  id: '10',
                  type: 'video',
                  background: 'bg',
                  backgroundColor: '#fff',
                  preview: 'pv',
                  duration: 0,
                  elements: [
                    pigeon.StoryElementWire(
                      type: 'button',
                      title: 'Buy',
                      link: 'l',
                      textBold: true,
                    ),
                    pigeon.StoryElementWire(type: 'product', item: product),
                    pigeon.StoryElementWire(
                      type: 'products',
                      showLabel: 'Show',
                      hideLabel: 'Hide',
                      products: [product],
                    ),
                    pigeon.StoryElementWire(
                      type: 'text_block',
                      text: 'Hi',
                      fontSize: 20,
                      promocode: 'SALE',
                    ),
                    pigeon.StoryElementWire(type: 'unknown'),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      final block = await PersonalizationSdk().stories.get('block');
      expect(calls.single[0], 'block');
      final story = block.stories.single;
      expect([story.viewed, story.startPosition], [true, 1]);
      final slide = story.slides.single;
      expect(slide.type, StorySlideType.video);
      expect(slide.duration, const Duration(seconds: 10), reason: 'default');
      expect(slide.elements, hasLength(4), reason: 'unknown kinds dropped');
      expect((slide.elements[0] as StoryButtonElement).textBold, isTrue);
      expect(slide.product!.brand, 'Bosch');
      expect((slide.elements[2] as StoryProductsElement).hideLabel, 'Hide');
      final text = slide.elements[3] as StoryTextBlockElement;
      expect([text.text, text.fontSize, text.promocode], ['Hi', 20, 'SALE']);
    });
  });
}
