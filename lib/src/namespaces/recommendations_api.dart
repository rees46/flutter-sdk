import '../errors/sdk_error.dart';
import '../models/request_models.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import '../recommendation/recommendation_response.dart';
import 'from_wire.dart';
import 'to_wire.dart';

/// Recommendation blocks the shop sets up in its account — the `recommendations`
/// namespace: `sdk.recommendations.get('block-code')`.
///
/// For a view, a cart or a purchase to count for the block, pass the source
/// `TrackingSource(type: TrackingSourceType.dynamicBlock, code: code)` to
/// `sdk.tracking`.
class RecommendationsApi {
  RecommendationsApi(this._api, this._shopId);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;

  /// The products of block [code] (`GET /recommend/{code}`) for where the customer
  /// is ([request]). Fails with [SdkException]: `invalidArgument` for an empty
  /// [code], a limit below 1 or `withLocations` without `extended`; `http` 404 for a
  /// block the shop does not have, 402 for a service not paid for; and the other
  /// errors of a request.
  Future<RecommendationResponse> get(
    String code, {
    RecommendationRequest? request,
  }) async => recommendationResponseFromWire(
    await sdkCall(
      () => _api.recommendationsGet(
        code,
        recommendationRequestToWire(request),
        _shopId,
      ),
    ),
  );
}
