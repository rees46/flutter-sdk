// Models of the SDK contract, as the native SDKs hand them over.

/// A banner of a [BannerSlider].
class SliderBanner {
  const SliderBanner({
    required this.id,
    required this.code,
    this.imageUrl,
    this.url,
    this.deeplinkIos,
    this.deeplinkAndroid,
    this.html,
  });

  /// For `tracking.bannerView` and `bannerClick`.
  final String id;

  /// For `tracking.bannerView` and `bannerClick`.
  final String code;

  final String? imageUrl;

  final String? url;

  final String? deeplinkIos;

  final String? deeplinkAndroid;

  final String? html;
}

/// A slider of banners (`Slider` of the contract; Flutter's own `Slider` widget takes that name).
class BannerSlider {
  const BannerSlider({
    required this.code,
    required this.width,
    required this.height,
    required this.banners,
  });

  final String code;

  final int width;

  final int height;

  /// Empty for a slider without banners.
  final List<SliderBanner> banners;
}
