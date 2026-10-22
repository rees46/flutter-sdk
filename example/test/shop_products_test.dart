import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk_example/shop/shop_products.dart';

Product _product(Map<String, dynamic> fields) => Product.fromJson({
  'id': '868',
  'name': 'Headphones',
  'brand': 'Logitech',
  'image_url': 'https://example.org/full.jpg',
  'price': 900,
  'price_formatted': '900 ₸',
  'currency': '₸',
  ...fields,
});

void main() {
  group('shopCard', () {
    test('a discounted product: old price and the formatted discount', () {
      final card = shopCard(
        _product({
          'oldprice': 1000,
          'oldprice_formatted': '1 000 ₸',
          'discount': 10,
          'discount_formatted': '10%',
          'picture': 'https://example.org/small.jpg',
        }),
        actionText: 'Add to cart',
      );
      expect(card.price, '900 ₸');
      expect(card.oldPrice, '1 000 ₸');
      expect(card.discount, '-10%');
      expect(card.brand, 'Logitech');
      expect(card.actionText, 'Add to cart');
      expect(
        (card.image! as NetworkImage).url,
        'https://example.org/small.jpg',
      );
    });

    test('no old price and no badge when the old price is not above', () {
      final card = shopCard(
        _product({
          'oldprice': 900,
          'oldprice_formatted': '900 ₸',
          'discount': 10,
        }),
      );
      expect(card.oldPrice, isNull);
      expect(card.discount, isNull);
    });

    test('a zero or boolean discount is no discount', () {
      final old = {'oldprice': 1000, 'oldprice_formatted': '1 000 ₸'};
      expect(
        shopCard(
          _product({...old, 'discount': 0, 'discount_formatted': '0%'}),
        ).discount,
        isNull,
      );
      expect(shopCard(_product({...old, 'discount': true})).discount, isNull);
    });

    test('discount_percent alone gives "N%", never discount_formatted', () {
      final card = shopCard(
        _product({
          'oldprice': 1000,
          'oldprice_formatted': '1 000 ₸',
          'discount': 0,
          'discount_formatted': '0%',
          'discount_percent': 12,
        }),
      );
      expect(card.discount, '-12%');
    });

    test('a formatted discount with a minus gets exactly one', () {
      final card = shopCard(
        _product({
          'oldprice': 1000,
          'oldprice_formatted': '1 000 ₸',
          'discount': 10,
          'discount_formatted': '-10%',
        }),
      );
      expect(card.discount, '-10%');
    });

    test('price and image fall back to price + currency and image_url', () {
      final card = shopCard(_product({'price_formatted': null}));
      expect(card.price, '900.0 ₸');
      expect((card.image! as NetworkImage).url, 'https://example.org/full.jpg');
    });
  });

  test('shopTopCategories keeps parentless categories once, in order', () {
    final response = ProductsListResponse.fromJson({
      'products_total': 2,
      'products': [
        {
          'id': '1',
          'categories': [
            {'id': 'phones', 'name': 'Phones'},
            {'id': 'headphones', 'name': 'Headphones', 'parent_id': 'phones'},
          ],
        },
        {
          'id': '2',
          'categories': [
            {'id': 'kitchen', 'name': 'Kitchen'},
            {'id': 'phones', 'name': 'Phones'},
          ],
        },
      ],
    });
    expect(shopTopCategories(response).map((c) => c.id), ['phones', 'kitchen']);
  });
}
