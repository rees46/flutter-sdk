import '../errors/sdk_error.dart';
import '../models/predict_models.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import 'from_wire.dart';

/// Forecasts of the customer's behaviour — the `predict` namespace.
class PredictApi {
  PredictApi(this._api, this._shopId);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;

  /// How likely the customer is to buy, from the products they viewed, put in the
  /// cart or in favorites lately (`GET /api/v3/cdp/users/probability-to-purchase`
  /// on the shop's host of API v3). `http` 402 for a shop without the service.
  Future<PurchaseProbability> getProbabilityToPurchase() async =>
      purchaseProbabilityFromWire(
        await sdkCall(() => _api.predictGetProbabilityToPurchase(_shopId)),
      );
}
