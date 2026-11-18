import '../errors/sdk_error.dart';
import '../models/review_models.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import 'from_wire.dart';

/// The customer's feedback — the `reviews` namespace: NPS, CSAT and CES ratings
/// with the dictionaries their forms take questions and thanks from, and the
/// reviews of products. The app collects a rating with its own form and sends it
/// with a `create…` method. The polls go to the shop's host of API v3.
///
/// What an `http` error means: polls — 400 wrong parameters, 402 not paid, 403
/// inactive, 404 no channel, category or campaign, 429 over the limit; reviews of
/// products — 400 no order, 403 the service is off, 404 no product, order or
/// customer.
class ReviewsApi {
  ReviewsApi(this._api, this._shopId);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;

  /// Sends an NPS rating, [rate] 0 to 10 (`POST /api/v3/polls/nps/reviews`).
  Future<PollReview> createNps(
    int rate,
    String channel,
    String category, {
    String? orderId,
    String? comment,
    String? label,
  }) async => pollReviewFromWire(
    await sdkCall(
      () => _api.reviewsCreateNps(
        rate,
        channel,
        category,
        orderId,
        comment,
        label,
        _shopId,
      ),
    ),
  );

  /// Sends a CSAT rating, [rate] 1 to 5 (`POST /api/v3/polls/csat/reviews`).
  Future<PollReview> createCsat(
    int rate,
    String channel,
    String campaign, {
    String? orderId,
    String? comment,
    String? label,
  }) async => pollReviewFromWire(
    await sdkCall(
      () => _api.reviewsCreateCsat(
        rate,
        channel,
        campaign,
        orderId,
        comment,
        label,
        _shopId,
      ),
    ),
  );

  /// Sends a CES rating, [rate] 1 to 7 (`POST /api/v3/polls/ces/reviews`).
  Future<PollReview> createCes(
    int rate,
    String channel,
    String campaign, {
    String? orderId,
    String? comment,
    String? label,
  }) async => pollReviewFromWire(
    await sdkCall(
      () => _api.reviewsCreateCes(
        rate,
        channel,
        campaign,
        orderId,
        comment,
        label,
        _shopId,
      ),
    ),
  );

  /// The shop's NPS categories; none is an empty list.
  Future<List<NpsCategory>> getNpsCategories() async =>
      List<NpsCategory>.unmodifiable(
        (await sdkCall(
          () => _api.reviewsGetNpsCategories(_shopId),
        )).map(npsCategoryFromWire),
      );

  /// The shop's channels of ratings, common to NPS, CSAT and CES.
  Future<List<PollChannel>> getNpsChannels() async =>
      List<PollChannel>.unmodifiable(
        (await sdkCall(
          () => _api.reviewsGetNpsChannels(_shopId),
        )).map(pollChannelFromWire),
      );

  /// The shop's CSAT campaigns.
  Future<List<CsatCampaign>> getCsatCampaigns() async =>
      List<CsatCampaign>.unmodifiable(
        (await sdkCall(
          () => _api.reviewsGetCsatCampaigns(_shopId),
        )).map(csatCampaignFromWire),
      );

  /// The shop's CES campaigns.
  Future<List<CesCampaign>> getCesCampaigns() async =>
      List<CesCampaign>.unmodifiable(
        (await sdkCall(
          () => _api.reviewsGetCesCampaigns(_shopId),
        )).map(cesCampaignFromWire),
      );

  /// The published reviews of product [itemId] and its rating (`GET
  /// /reviews/product`); [limit] 1 to 100, [offset] from 0.
  Future<ProductReviewsResponse> getProductReviews(
    String itemId, {
    int? limit,
    int? offset,
  }) async => productReviewsResponseFromWire(
    await sdkCall(
      () => _api.reviewsGetProductReviews(itemId, limit, offset, _shopId),
    ),
  );

  /// The reviews the customer wrote in order [orderId], in every state of
  /// moderation (`GET /reviews/client`).
  Future<List<ClientReview>> getClientReviews(String orderId) async =>
      List<ClientReview>.unmodifiable(
        (await sdkCall(
          () => _api.reviewsGetClientReviews(orderId, _shopId),
        )).map(clientReviewFromWire),
      );
}
