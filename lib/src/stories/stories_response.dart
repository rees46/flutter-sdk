import '../json_number.dart';

/// A stories block (`GET stories/{code}`), parsed from the server JSON both bridges hand
/// over untouched.
///
/// Internal to the UI kit until its release: the package barrel does not export it, the
/// kit barrel (`src/ui/personalization_ui.dart`) does.
///
/// Parsing is tolerant, the way the native SDKs read the same payload: numbers may arrive
/// as strings (`font_size`, `y_offset`, `duration`), ids as numbers or strings, and a
/// missing field takes the native default. The block-level `settings` (legacy colours of
/// the old stories) are not carried: the kit styles stories with its own tokens.
class StoriesBlock {
  /// Block id on the server.
  final String id;
  final List<Story> stories;

  const StoriesBlock({required this.id, required this.stories});

  factory StoriesBlock.fromJson(Map<String, dynamic> json) {
    return StoriesBlock(
      id: json['id']?.toString() ?? '',
      stories: _maps(json['stories']).map(Story.fromJson).toList(),
    );
  }
}

/// One story: a cover in the bar and the slides the viewer plays.
class Story {
  final String id;
  final String name;

  /// Cover image URL.
  final String avatar;

  /// Seen by this device, as the server remembers it.
  final bool viewed;

  /// Pinned by the shop to the start of the bar.
  final bool pinned;

  /// Slide to start from — the first one the user has not seen yet.
  final int startPosition;
  final List<StorySlide> slides;

  const Story({
    required this.id,
    required this.name,
    required this.avatar,
    this.viewed = false,
    this.pinned = false,
    this.startPosition = 0,
    required this.slides,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      viewed: json['viewed'] == true,
      pinned: json['pinned'] == true,
      startPosition: toIntOrNull(json['start_position']) ?? 0,
      slides: _maps(json['slides']).map(StorySlide.fromJson).toList(),
    );
  }
}

/// What a slide shows behind its elements.
enum StorySlideType {
  /// `image`: [StorySlide.background] is a picture.
  image,

  /// `video`: [StorySlide.background] is a video, [StorySlide.preview] its poster.
  video,

  /// `""`: a dynamic product slide, the product comes in a [StoryProductElement].
  product,
}

/// One slide of a story.
class StorySlide {
  /// Slide id: a number for media slides, a string like `"39_0"` for dynamic ones.
  final String id;
  final StorySlideType type;

  /// Image or video URL; empty on product slides.
  final String background;

  /// Colour behind the background, `#RRGGBB`; empty when not set.
  final String backgroundColor;

  /// Poster of a video slide; empty when not set.
  final String preview;

  /// How long the slide stays on screen.
  final Duration duration;
  final List<StoryElement> elements;

  /// Seconds a slide lasts when the server does not say (or says 0) — the same on every
  /// platform.
  static const int defaultDurationSeconds = 10;

  const StorySlide({
    required this.id,
    required this.type,
    this.background = '',
    this.backgroundColor = '',
    this.preview = '',
    this.duration = const Duration(seconds: defaultDurationSeconds),
    this.elements = const [],
  });

  factory StorySlide.fromJson(Map<String, dynamic> json) {
    final seconds = toIntOrNull(json['duration']);
    return StorySlide(
      id: json['id']?.toString() ?? '',
      type: switch (json['type']) {
        'image' => StorySlideType.image,
        'video' => StorySlideType.video,
        _ => StorySlideType.product,
      },
      background: json['background'] as String? ?? '',
      backgroundColor: json['background_color'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      duration: Duration(
        seconds: seconds == null || seconds <= 0
            ? defaultDurationSeconds
            : seconds,
      ),
      elements: _maps(
        json['elements'],
      ).map(StoryElement.fromJson).whereType<StoryElement>().toList(),
    );
  }

  /// The product of a dynamic product slide, if it has one.
  StoryProduct? get product {
    for (final element in elements) {
      if (element is StoryProductElement) return element.item;
    }
    return null;
  }
}

/// An element placed on a slide. Unknown types and `header` (not drawn by the kit) are
/// dropped while parsing.
sealed class StoryElement {
  const StoryElement();

  /// The element for [json], or `null` for a type the kit does not draw.
  static StoryElement? fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'button' => StoryButtonElement.fromJson(json),
      'product' => StoryProductElement.fromJson(json),
      'products' => StoryProductsElement.fromJson(json),
      'text_block' => StoryTextBlockElement.fromJson(json),
      _ => null,
    };
  }
}

/// `button`: a call to action with a link.
class StoryButtonElement extends StoryElement {
  final String title;
  final String link;
  final String linkAndroid;
  final String linkIos;

  /// Legacy colours of the old stories; the kit draws its own primary button.
  final String background;
  final String color;
  final bool textBold;

  const StoryButtonElement({
    required this.title,
    this.link = '',
    this.linkAndroid = '',
    this.linkIos = '',
    this.background = '',
    this.color = '',
    this.textBold = false,
  });

  factory StoryButtonElement.fromJson(Map<String, dynamic> json) {
    return StoryButtonElement(
      title: json['title'] as String? ?? '',
      link: json['link'] as String? ?? '',
      linkAndroid: json['link_android'] as String? ?? '',
      linkIos: json['link_ios'] as String? ?? '',
      background: json['background'] as String? ?? '',
      color: json['color'] as String? ?? '',
      textBold: json['text_bold'] == true || json['bold'] == true,
    );
  }
}

/// `product`: the product of a dynamic product slide.
class StoryProductElement extends StoryElement {
  final String title;
  final StoryProduct? item;

  const StoryProductElement({this.title = '', this.item});

  factory StoryProductElement.fromJson(Map<String, dynamic> json) {
    final item = json['item'];
    return StoryProductElement(
      title: json['title'] as String? ?? '',
      item: item is Map && item.isNotEmpty
          ? StoryProduct.fromJson(Map<String, dynamic>.from(item))
          : null,
    );
  }
}

/// `products`: the products "used" on a media slide, behind a show / hide toggle.
class StoryProductsElement extends StoryElement {
  /// Toggle label while collapsed (`labels.show_carousel`); empty when not set.
  final String showLabel;

  /// Toggle label while expanded (`labels.hide_carousel`); empty when not set.
  final String hideLabel;
  final List<StoryProduct> products;

  const StoryProductsElement({
    this.showLabel = '',
    this.hideLabel = '',
    required this.products,
  });

  factory StoryProductsElement.fromJson(Map<String, dynamic> json) {
    final labels = json['labels'];
    String label(String key) =>
        labels is Map ? (labels[key] as String? ?? '') : '';
    return StoryProductsElement(
      showLabel: label('show_carousel'),
      hideLabel: label('hide_carousel'),
      products: _maps(json['products']).map(StoryProduct.fromJson).toList(),
    );
  }
}

/// `text_block`: a text over a media slide.
class StoryTextBlockElement extends StoryElement {
  final String text;

  /// Font size in logical pixels; 14 when not set, as in the native SDKs.
  final double fontSize;

  /// `serif`, `sans-serif`, `monospaced` or empty.
  final String fontType;
  final bool bold;
  final bool italic;

  /// `left`, `center`, `right` or empty.
  final String textAlign;

  /// `#RRGGBB`; empty — the kit's colour.
  final String textColor;

  /// `#RRGGBB` behind the text; see [backgroundOpacity].
  final String backgroundColor;

  /// 0…1, from `"0%"`…`"100%"`. 0 — the text has no frame.
  final double backgroundOpacity;

  /// Line height as a multiple of the font size; 0 — the font's own.
  final double lineSpacing;

  /// Top of the block, in percent of the slide height.
  final double yOffset;

  /// A code the block copies on tap; `null` when it has none.
  final String? promocode;

  static const double defaultFontSize = 14;

  const StoryTextBlockElement({
    required this.text,
    this.fontSize = defaultFontSize,
    this.fontType = '',
    this.bold = false,
    this.italic = false,
    this.textAlign = '',
    this.textColor = '',
    this.backgroundColor = '',
    this.backgroundOpacity = 0,
    this.lineSpacing = 0,
    this.yOffset = 0,
    this.promocode,
  });

  factory StoryTextBlockElement.fromJson(Map<String, dynamic> json) {
    final promocode = json['promocode'];
    return StoryTextBlockElement(
      text: json['text_input'] as String? ?? '',
      fontSize: toDoubleOrNull(json['font_size']) ?? defaultFontSize,
      fontType: json['font_type'] as String? ?? '',
      bold: json['bold'] == true || json['text_bold'] == true,
      italic: json['italic'] == true,
      textAlign: json['text_align'] as String? ?? '',
      textColor: json['text_color'] as String? ?? '',
      backgroundColor: json['text_background_color'] as String? ?? '',
      backgroundOpacity: parseStoryOpacity(
        json['text_background_color_opacity'],
      ),
      lineSpacing: toDoubleOrNull(json['text_line_spacing']) ?? 0,
      yOffset: toDoubleOrNull(json['y_offset']) ?? 0,
      promocode: promocode is String && promocode.isNotEmpty ? promocode : null,
    );
  }
}

/// A product of a stories block — the fields the kit shows and links to.
class StoryProduct {
  final String id;
  final String name;
  final String brand;

  /// Resized copy of the image (`picture`), the one to show; empty when not set.
  final String picture;

  /// Original image (`image_url`).
  final String imageUrl;
  final double price;
  final String priceFormatted;

  /// Price before the discount, 0 when there is none.
  final double oldPrice;
  final String oldPriceFormatted;

  /// Discount in percent (`discount_percent`), 0 when there is none. Kept fractional:
  /// the admin may send `12.5`.
  final double discountPercent;

  /// Promo code for this product, empty when there is none.
  final String promocode;

  /// Price with the promo code applied (`price_with_promocode`), 0 when not sent.
  final double priceWithPromocode;

  /// Price with the promo code applied, formatted.
  final String priceWithPromocodeFormatted;
  final String currency;
  final String url;
  final String deeplinkAndroid;
  final String deeplinkIos;

  const StoryProduct({
    required this.id,
    required this.name,
    this.brand = '',
    this.picture = '',
    this.imageUrl = '',
    this.price = 0,
    this.priceFormatted = '',
    this.oldPrice = 0,
    this.oldPriceFormatted = '',
    this.discountPercent = 0,
    this.promocode = '',
    this.priceWithPromocode = 0,
    this.priceWithPromocodeFormatted = '',
    this.currency = '',
    this.url = '',
    this.deeplinkAndroid = '',
    this.deeplinkIos = '',
  });

  factory StoryProduct.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString() ?? '';
    return StoryProduct(
      id: text('id'),
      name: text('name'),
      brand: text('brand'),
      picture: text('picture'),
      imageUrl: text('image_url'),
      price: toDoubleOrNull(json['price']) ?? 0,
      priceFormatted: text('price_formatted'),
      oldPrice: toDoubleOrNull(json['oldprice']) ?? 0,
      oldPriceFormatted: text('oldprice_formatted'),
      discountPercent: toDoubleOrNull(json['discount_percent']) ?? 0,
      promocode: text('promocode'),
      priceWithPromocode: toDoubleOrNull(json['price_with_promocode']) ?? 0,
      priceWithPromocodeFormatted: text('price_with_promocode_formatted'),
      currency: text('currency'),
      url: text('url'),
      deeplinkAndroid: text('deeplink_android'),
      deeplinkIos: text('deeplink_ios'),
    );
  }

  /// The old price is worth showing: it is set and above the current one.
  bool get hasOldPrice => oldPrice > price && oldPriceFormatted.isNotEmpty;

  /// The image to show: the resized copy, else the original; empty when neither is set.
  String get image => picture.isNotEmpty ? picture : imageUrl;
}

/// Reads an opacity into 0…1. A string is percents with or without the sign (`"50%"`,
/// `"50"`), as the admin sends it and the native SDKs read it; a number above 1 is
/// percents too, otherwise a fraction.
double parseStoryOpacity(dynamic value) {
  final isText = value is String;
  final number = toDoubleOrNull(isText ? value.replaceAll('%', '') : value);
  if (number == null || number <= 0) return 0;
  final fraction = isText || number > 1 ? number / 100 : number;
  return fraction.clamp(0, 1).toDouble();
}

Iterable<Map<String, dynamic>> _maps(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map(Map<String, dynamic>.from);
}
