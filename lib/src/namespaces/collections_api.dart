import '../collection/collection_response.dart';
import '../errors/sdk_error.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import 'from_wire.dart';

/// Product collections the shop sets up in its account — the `collections`
/// namespace: `sdk.collections.get('12')`.
class CollectionsApi {
  CollectionsApi(this._api, this._shopId);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;

  /// The products of collection [collectionId] (`GET /collection/{id}`). Fails with
  /// [SdkException]: `invalidArgument` for an empty id, `http` 400 for a collection
  /// the shop does not have or that is off, and the other errors of a request.
  Future<CollectionResponse> get(String collectionId) async =>
      collectionResponseFromWire(
        await sdkCall(() => _api.collectionsGet(collectionId, _shopId)),
      );
}
