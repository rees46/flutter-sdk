import '../models/catalog.dart';
import '../errors/sdk_error.dart';
import '../models/request_models.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import 'from_wire.dart';
import 'to_wire.dart';

/// The shop's catalog — the `products` namespace: `sdk.products.getInfo('37')`.
///
/// Each method asks the native SDK once and answers with a model; the native SDK
/// adds the device id and the other common fields. A failure is an [SdkException]:
/// `notInitialized`, `shopBlocked`, `invalidArgument` (refused before any request),
/// `network`, `timeout`, `http`, `decoding` or `cancelled`. Nothing repeats a
/// request.
class ProductsApi {
  ProductsApi(this._api, this._shopId);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;

  /// The card of product [itemId] (`GET /products/get`); null for a product the
  /// catalog does not have. An empty [itemId] is `invalidArgument`.
  Future<Product?> getInfo(String itemId) async {
    final wire = await sdkCall(() => _api.productsGetInfo(itemId, _shopId));
    return wire == null ? null : productFromWire(wire);
  }

  /// A page of the catalog's listing with its facets (`GET /products`); without a
  /// [request], the first page of the whole catalog.
  Future<ProductsListResponse> getList({ProductsListRequest? request}) async =>
      productsListResponseFromWire(
        await sdkCall(
          () =>
              _api.productsGetList(productsListRequestToWire(request), _shopId),
        ),
      );

  /// How much interest product [itemId] draws (`GET /products/counters`): views,
  /// carts and purchases today and in the last 30 minutes, and subscriptions to its
  /// price and stock.
  Future<ProductCountersResponse> getCounters(String itemId) async =>
      productCountersResponseFromWire(
        await sdkCall(() => _api.productsGetCounters(itemId, _shopId)),
      );

  /// The screen of category [categoryId]: its products, facets, price range and
  /// order — the listing of that category (`GET /products` with `categories`).
  Future<CategoryResponse> getCategory(
    String categoryId, {
    CategoryRequest? request,
  }) async => categoryResponseFromWire(
    await sdkCall(
      () => _api.productsGetCategory(
        categoryId,
        categoryRequestToWire(request),
        _shopId,
      ),
    ),
  );
}
