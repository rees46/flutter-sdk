/// Filter labels of the demo shop's feed — what an integrator sets up for their own
/// feed. The kit knows only the shape of the data; facet names and their values are the
/// shop's own, so the shop names them.
library;

/// Titles of the shop's facets; `null` — the kit's default title.
String? shopFacetTitle(String name) => switch (name) {
  'stickers' || 'stickers_liquid' => 'Стикеры',
  'product_type' => 'Тип товара',
  _ => null,
};

/// Labels of the values of the shop's facets; `null` — the kit's label (the `title` of
/// an object value, else the value itself).
String? shopFacetValueTitle(String facet, String value) =>
    switch ((facet, value)) {
      ('product_type', 'regular') => 'Обычный',
      ('product_type', 'digital') => 'Цифровой',
      ('product_type', 'mto') => 'Под заказ',
      _ => null,
    };
