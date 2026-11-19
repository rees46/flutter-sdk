import '../models/catalog.dart';
import '../core/native_events.dart';
import '../errors/sdk_error.dart';
import '../models/agent_models.dart';
import '../models/request_models.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import 'from_wire.dart';
import 'to_wire.dart';

/// Search in the shop's catalog — the `search` namespace:
/// `sdk.search.instant('phone')`.
///
/// The methods send no search event: when the customer searched, call
/// `sdk.tracking.search`; a product opened from the results counts for the search
/// with the source `instantSearch` or `fullSearch` and the query as its code.
///
/// The search agent (AI search) is a dialog the shop may show instead of the empty
/// search: [agentEnabled] says whether to, [agentDialog] opens it and [agent] sends
/// the customer's message. It lives on the shop's app host (`app.rees46.ru`
/// unless its cluster has its own).
class SearchApi {
  SearchApi(this._api, this._shopId, this._mirror);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;
  final ShopMirror? Function() _mirror;

  /// Whether the shop shows the search agent instead of the empty search: the last
  /// `/init` answer's `search.blank_mode` is `agent`. Read at once from the copy the
  /// bridge keeps; false before the first answer.
  bool get agentEnabled => _mirror()?.agentEnabled ?? false;

  /// What to show in an empty search field (`GET /search/blank`).
  Future<SearchBlankResponse> blank() async => searchBlankResponseFromWire(
    await sdkCall(() => _api.searchBlank(_shopId)),
  );

  /// Products and suggestions as the customer types [query] (instant search). An
  /// empty [query] is `invalidArgument`. [excludedMerchants] is sent only with
  /// [locations].
  Future<SearchInstantResponse> instant(
    String query, {
    List<String>? locations,
    List<String>? excludedMerchants,
    List<String>? excludedBrands,
  }) async => searchInstantResponseFromWire(
    await sdkCall(
      () => _api.searchInstant(
        query,
        locations,
        excludedMerchants,
        excludedBrands,
        _shopId,
      ),
    ),
  );

  /// The screen of the results of [query] (full search) with the filters, order and
  /// page of [request]. An empty [query] is `invalidArgument`.
  Future<SearchFullResponse> full(
    String query, {
    SearchFullRequest? request,
  }) async => searchFullResponseFromWire(
    await sdkCall(
      () => _api.searchFull(query, searchFullRequestToWire(request), _shopId),
    ),
  );

  /// The customer's dialog with the search agent: the last 20 sessions and the
  /// messages of [sessionId], or of the latest session without one. Call it when the
  /// agent's window opens. Besides the errors of every request: `http` 404 for a
  /// session not found, 429 over the limit, 503 when the agent is unavailable — show
  /// [blank] instead.
  Future<AgentDialogResponse> agentDialog({
    int? sessionId,
    List<String>? locations,
  }) async => agentDialogResponseFromWire(
    await sdkCall(() => _api.searchAgentDialog(sessionId, locations, _shopId)),
  );

  /// Sends the customer's [message] to the search agent and returns its answer, in
  /// session [sessionId] or a new one without it. The agent may take up to a minute.
  /// An empty [message], or one longer than 500 characters, is `invalidArgument`.
  Future<AgentResponse> agent(
    String message, {
    int? sessionId,
    List<String>? locations,
  }) async => agentResponseFromWire(
    await sdkCall(
      () => _api.searchAgent(message, sessionId, locations, _shopId),
    ),
  );
}
