import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/models.dart';
import 'package:rees46_sdk_example/shop/shop_products.dart';

Product _product({
  String id = '868',
  String? priceFormatted = '900 ₸',
  double? oldPrice,
  String? oldPriceFormatted,
  int? discountPercent,
  String? discountFormatted,
  String? picture,
  List<ProductCategory>? categories,
}) => Product(
  id: id,
  name: 'Headphones',
  brand: 'Logitech',
  url: '',
  imageUrl: 'https://example.org/full.jpg',
  picture: picture,
  price: 900,
  priceFormatted: priceFormatted,
  oldPrice: oldPrice,
  oldPriceFormatted: oldPriceFormatted,
  currency: '₸',
  discountPercent: discountPercent,
  discountFormatted: discountFormatted,
  categories: categories,
);

void main() {
  group('shopCard', () {
    test('a discounted product: old price and the formatted discount', () {
      final card = shopCard(
        _product(
          oldPrice: 1000,
          oldPriceFormatted: '1 000 ₸',
          discountPercent: 10,
          discountFormatted: '10%',
          picture: 'https://example.org/small.jpg',
        ),
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
        _product(
          oldPrice: 900,
          oldPriceFormatted: '900 ₸',
          discountPercent: 10,
        ),
      );
      expect(card.oldPrice, isNull);
      expect(card.discount, isNull);
    });

    test('a zero discount is no discount', () {
      expect(
        shopCard(
          _product(
            oldPrice: 1000,
            oldPriceFormatted: '1 000 ₸',
            discountPercent: 0,
            discountFormatted: '0%',
          ),
        ).discount,
        isNull,
      );
    });

    test('without discountFormatted the badge is "N%"', () {
      final card = shopCard(
        _product(
          oldPrice: 1000,
          oldPriceFormatted: '1 000 ₸',
          discountPercent: 12,
        ),
      );
      expect(card.discount, '-12%');
    });

    test('a formatted discount with a minus gets exactly one', () {
      final card = shopCard(
        _product(
          oldPrice: 1000,
          oldPriceFormatted: '1 000 ₸',
          discountPercent: 10,
          discountFormatted: '-10%',
        ),
      );
      expect(card.discount, '-10%');
    });

    test('price and image fall back to price + currency and imageUrl', () {
      final card = shopCard(_product(priceFormatted: null));
      expect(card.price, '900.0 ₸');
      expect((card.image! as NetworkImage).url, 'https://example.org/full.jpg');
    });
  });

  test('shopTopCategories takes the listing categories first', () {
    final response = ProductsListResponse(
      productsTotal: 1,
      categories: const [
        ProductCategory(id: 'laptops', name: 'Laptops'),
        ProductCategory(
          id: 'gaming',
          name: 'Gaming laptops',
          parentId: 'laptops',
        ),
        ProductCategory(id: 'kitchen', name: 'Kitchen'),
      ],
      products: [
        _product(
          id: '1',
          categories: const [ProductCategory(id: 'phones', name: 'Phones')],
        ),
      ],
    );
    expect(shopTopCategories(response).map((c) => c.id), [
      'laptops',
      'kitchen',
    ]);
  });

  test('without listing categories they come from the products', () {
    final response = ProductsListResponse(
      productsTotal: 2,
      products: [
        _product(
          id: '1',
          categories: const [
            ProductCategory(id: 'phones', name: 'Phones'),
            ProductCategory(
              id: 'headphones',
              name: 'Headphones',
              parentId: 'phones',
            ),
          ],
        ),
        _product(
          id: '2',
          categories: const [
            ProductCategory(id: 'kitchen', name: 'Kitchen'),
            ProductCategory(id: 'phones', name: 'Phones'),
          ],
        ),
      ],
    );
    expect(shopTopCategories(response).map((c) => c.id), ['phones', 'kitchen']);
  });
}
