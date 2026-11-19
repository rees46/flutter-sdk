// The stories models of the contract (stories.md): what `stories.get` answers with.
// A text field without a value is "", as the released models have it; a price the
// answer does not have is null.
//
// They share their names with the released classes of the deprecated `getStories`
// and of the UI kit, which keep their 1.6.4 shape. So these are exported from
// `package:rees46_sdk/models.dart`, not from the package's main library.

import '../stories/stories_response.dart' show StorySlideType;

export '../stories/stories_response.dart' show StorySlideType;

/// A stories block (`GET /stories/{code}`): its stories in the feed's order.
class StoriesBlock {
  const StoriesBlock({required this.id, required this.stories});

  final String id;
  final List<Story> stories;
}

/// One story of a block.
class Story {
  const Story({
    required this.id,
    required this.name,
    required this.avatar,
    this.viewed = false,
    this.pinned = false,
    this.startPosition = 0,
    required this.slides,
  });

  final String id;
  final String name;

  /// The cover's image.
  final String avatar;

  /// The server remembers that this device saw the story.
  final bool viewed;

  /// The story is pinned at the start of the feed.
  final bool pinned;

  /// The first slide not seen yet.
  final int startPosition;
  final List<StorySlide> slides;
}

/// One slide of a story.
class StorySlide {
  const StorySlide({
    required this.id,
    required this.type,
    required this.background,
    this.backgroundColor = '',
    this.preview = '',
    this.duration = const Duration(seconds: defaultDurationSeconds),
    this.elements = const [],
  });

  /// How long a slide without its own duration shows, in seconds.
  static const int defaultDurationSeconds = 10;

  /// A number for a slide with media, `{storyId}_{n}` for a product slide.
  final String id;
  final StorySlideType type;

  /// The image or video behind the elements; a product slide's comes from the
  /// stories' settings.
  final String background;

  /// `#RRGGBB`, or "" when not set.
  final String backgroundColor;

  /// A video's poster, or "".
  final String preview;
  final Duration duration;
  final List<StoryElement> elements;
}

/// An element of a slide: one of four kinds by the answer's `type`.
sealed class StoryElement {
  const StoryElement();
}

/// A button with a link (`button`).
class StoryButtonElement extends StoryElement {
  const StoryButtonElement({
    this.title = '',
    this.link = '',
    this.linkAndroid = '',
    this.linkIos = '',
    this.background = '',
    this.color = '',
    this.textBold = false,
  });

  final String title;
  final String link;
  final String linkAndroid;
  final String linkIos;
  final String background;
  final String color;
  final bool textBold;
}

/// The product of a product slide (`product`).
class StoryProductElement extends StoryElement {
  const StoryProductElement({this.title = '', this.item});

  final String title;
  final StoryProduct? item;
}

/// Products of a slide behind a "show / hide" switch (`products`).
class StoryProductsElement extends StoryElement {
  const StoryProductsElement({
    this.showLabel = '',
    this.hideLabel = '',
    this.products = const [],
  });

  final String showLabel;
  final String hideLabel;
  final List<StoryProduct> products;
}

/// A text over the slide (`text_block`).
class StoryTextBlockElement extends StoryElement {
  const StoryTextBlockElement({
    this.text = '',
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

  /// The size of a text without its own.
  static const double defaultFontSize = 14;

  final String text;
  final double fontSize;

  /// `serif`, `sans-serif`, `monospace` or "".
  final String fontType;
  final bool bold;
  final bool italic;

  /// `left`, `center`, `right` or "".
  final String textAlign;

  /// `#RRGGBB` or "".
  final String textColor;

  /// `#RRGGBB` or "".
  final String backgroundColor;

  /// From 0 to 1.
  final double backgroundOpacity;

  /// A factor of the font size; 0 — the font's own.
  final double lineSpacing;

  /// The top of the block in percent of the slide's height.
  final double yOffset;

  /// The code the block copies on a tap; null without one.
  final String? promocode;
}

/// A product of a story.
class StoryProduct {
  const StoryProduct({
    required this.id,
    required this.name,
    this.brand = '',
    this.picture = '',
    this.imageUrl = '',
    this.price = 0,
    this.priceFormatted = '',
    this.oldPrice,
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

  final String id;
  final String name;
  final String brand;

  /// The resized image — the one to show.
  final String picture;

  /// The original image.
  final String imageUrl;
  final double price;
  final String priceFormatted;

  /// The price before the discount; null when it is not above [price].
  final double? oldPrice;
  final String oldPriceFormatted;

  /// The discount in percent, when the shop loaded it into the catalog; 0 without.
  final double discountPercent;
  final String promocode;

  /// The price with the promo code; 0 when the answer has none.
  final double priceWithPromocode;
  final String priceWithPromocodeFormatted;
  final String currency;
  final String url;
  final String deeplinkAndroid;
  final String deeplinkIos;
}
