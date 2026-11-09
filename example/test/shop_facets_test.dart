import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk_example/shop/shop_facets.dart';

void main() {
  test('the shop names its own facets, the rest keep the kit title', () {
    expect(shopFacetTitle('stickers'), 'Стикеры');
    expect(shopFacetTitle('stickers_liquid'), 'Стикеры');
    expect(shopFacetTitle('product_type'), 'Тип товара');
    expect(shopFacetTitle('merchant'), isNull);
  });

  test('product types get names, other values keep the kit label', () {
    expect(shopFacetValueTitle('product_type', 'regular'), 'Обычный');
    expect(shopFacetValueTitle('product_type', 'digital'), 'Цифровой');
    expect(shopFacetValueTitle('product_type', 'mto'), 'Под заказ');
    expect(shopFacetValueTitle('product_type', 'other'), isNull);
    expect(shopFacetValueTitle('stickers', 'regular'), isNull);
  });
}
