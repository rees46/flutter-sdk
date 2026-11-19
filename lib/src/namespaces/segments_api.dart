import '../core/native_events.dart';
import '../errors/sdk_error.dart';
import '../models/segment_models.dart';
import '../pigeon/personalization_api.g.dart' as pigeon;
import '../popups_v3/popups_v3_hooks.dart';
import 'from_wire.dart';

/// The customer's segments and the device's A/B group — the `segments` namespace.
/// The shop sets up static segments in its account and the SDK adds the customer
/// to them or takes them out; the server works out dynamic ones itself. With
/// `email` or `phone` the server applies the call to the contact's owner.
class SegmentsApi {
  SegmentsApi(this._api, this._shopId, this._mirror, this._hookKey);

  final pigeon.PersonalizationHostApi _api;
  final String? _shopId;
  final ShopMirror? Function() _mirror;
  final Object _hookKey;

  /// Adds the customer to static segment [segmentId] (`POST /segments/add`). A
  /// [segmentId] not above 0, or an empty contact, is `invalidArgument`.
  Future<void> add(int segmentId, {String? email, String? phone}) {
    PopupsV3Hooks.contextChanged(_hookKey, 'segment', 'add', [
      segmentId,
      email,
      phone,
    ]);
    return sdkCall(() => _api.segmentsAdd(segmentId, email, phone, _shopId));
  }

  /// Takes the customer out of static segment [segmentId] (`POST /segments/remove`).
  Future<void> remove(int segmentId, {String? email, String? phone}) {
    PopupsV3Hooks.contextChanged(_hookKey, 'segment', 'remove', [
      segmentId,
      email,
      phone,
    ]);
    return sdkCall(() => _api.segmentsRemove(segmentId, email, phone, _shopId));
  }

  /// The segments the customer is in now, static and dynamic (`GET /segments/get`).
  Future<List<Segment>> get() async => List<Segment>.unmodifiable(
    (await sdkCall(() => _api.segmentsGet(_shopId))).map(segmentFromWire),
  );

  /// The device's A/B group, `A` or `B`, at once: the native SDK picks it once and
  /// sends it with every request. Empty before the shop is initialized.
  String getAbGroup() => _mirror()?.segment ?? '';
}
