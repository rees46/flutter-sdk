import 'package:flutter/material.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

/// "Multi-instance" screen — two shops living in one app at the same time.
///
/// Mirror of the native demos (Android `MultiInstancePane`, iOS
/// `MultiInstanceViewController`, RN `MultiInstancePane`). Shop A is the eager
/// default; shop B is registered lazily and comes to life the moment this screen
/// resolves it. Everything each instance sends carries its own `shop_id`/`did`,
/// so the two session cards (did/sid) are the in-app proof of isolation. Also
/// exercises the fail-fast resolution contract and `Rees46.handlePush` routing.
///
/// (The native demos also show per-shop Stories; the Flutter SDK exposes no
/// stories widget, so that part is omitted here.)
class MultiInstancePane extends StatefulWidget {
  const MultiInstancePane({super.key});

  static const shopIdA = 'c1140c8254976de297c3caf971701a';
  static const shopIdB = '4b464e7c386120d4b621bf7cb79293';

  @override
  State<MultiInstancePane> createState() => _MultiInstancePaneState();
}

class _MultiInstancePaneState extends State<MultiInstancePane> {
  static const _maxLog = 20;

  final List<String> _log = [];
  late final PersonalizationSdk _shopA;
  late final PersonalizationSdk _shopB;

  _Session _sessionA = const _Session.notReady();
  _Session _sessionB = const _Session.notReady();

  // Deterministic last-result labels for integration tests (mirror of the native
  // demos' `mi-contract-result` / `mi-push-result`).
  String? _lastContractResult;
  String? _lastPushResult;

  @override
  void initState() {
    super.initState();

    // Shop A — eager default.
    _shopA = Rees46.isInitialized(MultiInstancePane.shopIdA)
        ? Rees46.getInstance(MultiInstancePane.shopIdA)
        : Rees46.initialize(
            const Rees46Config(shopId: MultiInstancePane.shopIdA),
          );

    // Shop B — registered lazily, then materialized right here by resolving it.
    if (!Rees46.isInitialized(MultiInstancePane.shopIdB) &&
        !Rees46.pendingShopIds.contains(MultiInstancePane.shopIdB)) {
      Rees46.registerShops(const [
        Rees46Config(shopId: MultiInstancePane.shopIdB),
      ]);
    }
    _shopB = Rees46.getInstance(MultiInstancePane.shopIdB); // B is born here

    _shopA.setPushNotificationCallbacks(
      onReceived: (p) => _addLog('✓ shop A onReceived: ${_pushLabel(p)}'),
    );
    _shopB.setPushNotificationCallbacks(
      onReceived: (p) => _addLog('✓ shop B onReceived: ${_pushLabel(p)}'),
    );

    _refresh();
  }

  void _addLog(String message) {
    setState(() {
      _log.insert(0, message);
      if (_log.length > _maxLog) _log.removeLast();
    });
  }

  Future<String?> _tryString(Future<String?> Function() call) async {
    try {
      return await call();
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    final a = _Session(
      did: await _tryString(_shopA.getDid),
      sid: await _tryString(() => _shopA.getSid()),
    );
    final b = _Session(
      did: await _tryString(_shopB.getDid),
      sid: await _tryString(() => _shopB.getSid()),
    );
    if (!mounted) return;
    setState(() {
      _sessionA = a;
      _sessionB = b;
    });
    _addLog('refreshed sessions');
  }

  /// Runs a `getInstance` call and turns the outcome — a value, or the fail-fast
  /// exception — into a log line.
  void _runContract(String label, void Function() call) {
    String result;
    try {
      call();
      result = 'unexpected: returned without throwing';
    } on AmbiguousShopException catch (e) {
      result = 'AmbiguousShopException ${e.registeredShopIds}';
    } on UnknownShopIdException catch (e) {
      result = 'UnknownShopIdException (${e.shopId})';
    } catch (e) {
      result = '${e.runtimeType}';
    }
    setState(() => _lastContractResult = result);
    _addLog('$label → $result');
  }

  Future<void> _injectPush(String? shopId, String note) async {
    final payload = <String, String>{
      'shop_id': ?shopId,
      'type': 'bulk',
      'id': 'mi-demo',
      'title': note,
      'body': note,
    };
    final routed = await Rees46.handlePush(payload, PushEvent.received);
    final result = routed != null ? 'routed:$routed' : 'dropped';
    setState(() => _lastPushResult = result);
    _addLog('injected shop_id=${shopId ?? '—'} → $result');
  }

  static String _pushLabel(Map<String, String?> p) =>
      p['title'] ?? p['type'] ?? '—';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multi-instance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Two shops, one app',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          const Text(
            'Shop A is the eager default; shop B is lazy and materialized on '
            'open. Each session below carries its own shop_id/did/sid.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),

          _SessionCard(
            title: 'Shop A',
            shopId: MultiInstancePane.shopIdA,
            session: _sessionA,
          ),
          const SizedBox(height: 8),
          _SessionCard(
            title: 'Shop B',
            shopId: MultiInstancePane.shopIdB,
            session: _sessionB,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _refresh,
            child: const Text('Refresh sessions'),
          ),

          const SizedBox(height: 16),
          const Text(
            'Fail-fast contracts',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: () =>
                    _runContract('getInstance()', () => Rees46.getInstance()),
                child: const Text('getInstance() → Ambiguous'),
              ),
              ElevatedButton(
                onPressed: () => _runContract(
                  'getInstance("nope")',
                  () => Rees46.getInstance('nope'),
                ),
                child: const Text('getInstance("nope") → Unknown'),
              ),
            ],
          ),
          Text(
            'result: ${_lastContractResult ?? '—'}',
            key: const Key('mi-contract-result'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),

          const SizedBox(height: 16),
          const Text(
            'Push routing (Rees46.handlePush)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: () =>
                    _injectPush(MultiInstancePane.shopIdA, 'Shop A push'),
                child: const Text('push shop_id=A'),
              ),
              ElevatedButton(
                onPressed: () =>
                    _injectPush(MultiInstancePane.shopIdB, 'Shop B push'),
                child: const Text('push shop_id=B'),
              ),
              ElevatedButton(
                onPressed: () =>
                    _injectPush('zzz-unknown-shop', 'Unknown shop'),
                child: const Text('push shop_id=unknown'),
              ),
              ElevatedButton(
                onPressed: () => _injectPush(null, 'No shop'),
                child: const Text('push (no shop_id)'),
              ),
            ],
          ),
          Text(
            'result: ${_lastPushResult ?? '—'}',
            key: const Key('mi-push-result'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),

          const SizedBox(height: 16),
          const Text('Log', style: TextStyle(fontWeight: FontWeight.bold)),
          if (_log.isEmpty)
            const Text(
              'Interact above — routed/dropped decisions and callbacks appear here.',
              style: TextStyle(fontSize: 12),
            )
          else
            ..._log.map(
              (e) => Text(
                e,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _Session {
  const _Session({this.did, this.sid});
  const _Session.notReady() : did = null, sid = null;

  final String? did;
  final String? sid;

  bool get ready => (did?.isNotEmpty ?? false) || (sid?.isNotEmpty ?? false);
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.title,
    required this.shopId,
    required this.session,
  });

  final String title;
  final String shopId;
  final _Session session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'shop_id=$shopId',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              session.ready
                  ? 'did=${session.did?.isNotEmpty == true ? session.did : '—'}  '
                        'sid=${session.sid?.isNotEmpty == true ? session.sid : '—'}'
                  : 'not initialized yet — tap Refresh after init settles',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
