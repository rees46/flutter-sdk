import '../errors/sdk_error.dart';
import '../models/slider_models.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import 'from_wire.dart';

/// Banner sliders — the `sliders` namespace: `sdk.sliders.get(code)`. The app draws
/// the carousel and reports a banner shown and tapped with `tracking.bannerView`
/// and `tracking.bannerClick`.
class SlidersApi {
  SlidersApi(this._api, this._shopId);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;

  /// Slider [code] with its banners for the customer (`GET /slider`). [tags] keeps
  /// the banners with those tags; [locationId] is the customer's location, without
  /// which a banner limited to locations is not shown. `invalidArgument` for an
  /// empty [code] or a tag that is empty or has a comma; `http` 404 for an unknown
  /// or inactive slider.
  Future<BannerSlider> get(
    String code, {
    List<String>? tags,
    String? locationId,
  }) async => bannerSliderFromWire(
    await sdkCall(() => _api.slidersGet(code, tags, locationId, _shopId)),
  );
}
