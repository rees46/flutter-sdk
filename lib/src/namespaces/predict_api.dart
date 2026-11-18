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
  /// cart or in favorites lately, from the shop's app host (`app.rees46.ru` unless
  /// its cluster has its own). `http` 402 for a shop without the service.
  Future<PurchaseProbability> getProbabilityToPurchase() async =>
      purchaseProbabilityFromWire(
        await sdkCall(() => _api.predictGetProbabilityToPurchase(_shopId)),
      );
}
