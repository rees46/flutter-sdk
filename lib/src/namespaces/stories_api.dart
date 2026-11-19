import '../errors/sdk_error.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import '../models/stories.dart';
import 'from_wire.dart';

/// The stories blocks — the `stories` namespace: `sdk.stories.get(code)`. The
/// events of a story are `tracking.storyView` and `tracking.storyClick`.
class StoriesApi {
  StoriesApi(this._api, this._shopId);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;

  /// The stories block [code] (`GET /stories/{code}`) for this device. A block
  /// without stories is a block with an empty list. `invalidArgument` for an empty
  /// [code]; `http` 404 for an unknown block, 402 when the shop does not pay for
  /// stories.
  Future<StoriesBlock> get(String code) async =>
      storiesBlockFromWire(await sdkCall(() => _api.storiesGet(code, _shopId)));
}
