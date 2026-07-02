import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REES46 Flutter SDK',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const InitPage(),
    );
  }
}

class InitPage extends StatefulWidget {
  const InitPage({super.key});

  @override
  State<InitPage> createState() => _InitPageState();
}

enum InitState { idle, initializing, initialized, failed }

class _InitPageState extends State<InitPage> {
  final _sdk = PersonalizationSdk();

  // Platform channel used to ask the host for the Android 13+ notification
  // permission. See [_requestNotificationPermission].
  static const _platformChannel = MethodChannel('rees46_sdk_example/platform');

  // Hardcoded demo credentials — the demo does not need editable init inputs.
  static const _shopId = 'c1140c8254976de297c3caf971701a';
  static const _apiDomain = 'api.rees46.ru';
  final _stream = defaultTargetPlatform == TargetPlatform.android
      ? 'android'
      : 'ios';

  bool _enableLogs = false;
  bool _autoSendPushToken = true;
  bool _sendAdvertisingId = false;
  bool _enableAutoPopupPresentation = true;
  bool _needReInitialization = false;

  InitState _initState = InitState.idle;
  String? _initError;
  DateTime? _lastInitAt;

  String? _storedPushToken;
  DateTime? _tokenUpdatedAt;
  bool _tokenLoading = false;

  // Profile & session state
  String? _sid;
  String? _did;
  String? _profileStatus;

  // Recommendation state
  final _recBlockController = TextEditingController(
    text: 'e6249bb15043644bf25b135006149962',
  );
  String? _recTitle;
  int? _recProductCount;
  String? _recError;
  bool _recLoading = false;

  // Search (full) state
  final _searchQueryController = TextEditingController(text: 'Logitech');
  int? _searchTotal;
  String? _searchError;
  bool _searchLoading = false;

  // Product info state
  final _productIdController = TextEditingController(text: '868');
  String? _productInfoName;
  String? _productInfoError;
  bool _productInfoLoading = false;

  // Products list state
  int? _productsListTotal;
  String? _productsListError;
  bool _productsListLoading = false;

  // Search blank state
  int? _searchBlankProductCount;
  int? _searchBlankSuggestCount;
  String? _searchBlankError;
  bool _searchBlankLoading = false;

  // Search instant state
  final _searchInstantQueryController = TextEditingController(text: 'Logitech');
  int? _searchInstantTotal;
  String? _searchInstantError;
  bool _searchInstantLoading = false;

  // Loyalty state
  final _loyaltyPhoneController = TextEditingController(text: '79991234567');
  String? _loyaltyResult;
  String? _loyaltyError;
  bool _loyaltyLoading = false;

  // Catalog state (profile / product counters / category / collection)
  String? _catalogProfile;
  String? _catalogProfileError;
  bool _catalogProfileLoading = false;

  final _catalogCounterItemController = TextEditingController(text: '868');
  String? _catalogCounters;
  String? _catalogCountersError;
  bool _catalogCountersLoading = false;

  final _catalogCategoryController = TextEditingController(text: 'naushniki');
  String? _catalogCategory;
  String? _catalogCategoryError;
  bool _catalogCategoryLoading = false;

  final _catalogCollectionController = TextEditingController(text: '1');
  String? _catalogCollection;
  String? _catalogCollectionError;
  bool _catalogCollectionLoading = false;

  @override
  void dispose() {
    _recBlockController.dispose();
    _productIdController.dispose();
    _searchQueryController.dispose();
    _searchInstantQueryController.dispose();
    _loyaltyPhoneController.dispose();
    _catalogCounterItemController.dispose();
    _catalogCategoryController.dispose();
    _catalogCollectionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _sdk.setPushNotificationCallbacks(
      onReceived: (payload) {
        // In the demo we only surface init/token state; push payloads can be added later.
      },
      onDelivered: (payload) {},
      onClicked: (payload) {},
    );
    // Auto-initialize on startup — the demo uses hardcoded config, so no manual
    // step is needed. The button below only re-initializes (e.g. after toggling flags).
    _initialize();
    // Ask for the notification permission after the first frame. Triggering it from
    // Dart (rather than MainActivity.onCreate) guarantees it runs after Patrol's
    // app-service handshake, so the system dialog never hangs an integration test.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await _platformChannel.invokeMethod<void>(
        'requestNotificationPermission',
      );
    } catch (_) {
      // Best-effort: the app still runs without it (pushes just won't be shown
      // until the permission is granted), and non-Android hosts ignore it.
    }
  }

  Future<void> _initialize() async {
    setState(() {
      _initState = InitState.initializing;
      _initError = null;
    });

    try {
      await _sdk.initialize(
        SdkInitConfig(
          shopId: _shopId,
          apiDomain: _apiDomain,
          stream: _stream,
          enableLogs: _enableLogs,
          autoSendPushToken: _autoSendPushToken,
          sendAdvertisingId: _sendAdvertisingId,
          enableAutoPopupPresentation: _enableAutoPopupPresentation,
          needReInitialization: _needReInitialization,
        ),
      );
      setState(() {
        _initState = InitState.initialized;
        _lastInitAt = DateTime.now();
      });
      await _refreshToken();
    } on PlatformException catch (e) {
      setState(() {
        _initState = InitState.failed;
        _initError = 'PlatformException: ${e.code} ${e.message ?? ''}'.trim();
      });
    } catch (e) {
      setState(() {
        _initState = InitState.failed;
        _initError = 'Error: $e';
      });
    }
  }

  Future<void> _refreshToken() async {
    setState(() => _tokenLoading = true);
    try {
      final token = await _sdk.getStoredPushToken();
      setState(() {
        _storedPushToken = (token == null || token.trim().isEmpty)
            ? null
            : token.trim();
        _tokenUpdatedAt = DateTime.now();
      });
    } catch (e) {
      // Keep token as-is; this is just a demo screen.
    } finally {
      setState(() => _tokenLoading = false);
    }
  }

  Future<void> _getSid() async {
    try {
      final sid = await _sdk.getSid();
      setState(() => _sid = sid);
    } catch (e) {
      setState(() => _sid = 'Error: $e');
    }
  }

  Future<void> _getDid() async {
    try {
      final did = await _sdk.getDid();
      setState(() => _did = did ?? 'null');
    } catch (e) {
      setState(() => _did = 'Error: $e');
    }
  }

  Future<void> _setProfile() async {
    try {
      await _sdk.setProfile(
        // Not example.com — the REES46 backend rejects RFC 2606 reserved test
        // domains with 400 "Invalid email or missing".
        const ProfileParams(
          email: 'tester@rees46.com',
          firstName: 'Test',
          gender: ProfileGender.male,
        ),
      );
      setState(() => _profileStatus = 'Profile set');
    } catch (e) {
      setState(() => _profileStatus = 'Error: $e');
    }
  }

  Future<void> _getRecommendation() async {
    final code = _recBlockController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _recLoading = true;
      _recError = null;
      _recTitle = null;
      _recProductCount = null;
    });
    try {
      final response = await _sdk.getRecommendation(code);
      setState(() {
        _recTitle = response.title;
        _recProductCount = response.products.length;
        _recLoading = false;
      });
    } catch (e) {
      setState(() {
        _recError = 'Error: $e';
        _recLoading = false;
      });
    }
  }

  Future<void> _searchFull() async {
    final query = _searchQueryController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searchLoading = true;
      _searchError = null;
      _searchTotal = null;
    });
    try {
      final response = await _sdk.searchFull(query);
      setState(() {
        _searchTotal = response.productsTotal;
        _searchLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Error: $e';
        _searchLoading = false;
      });
    }
  }

  Future<void> _getProductInfo() async {
    final id = _productIdController.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _productInfoLoading = true;
      _productInfoError = null;
      _productInfoName = null;
    });
    try {
      final product = await _sdk.getProductInfo(id);
      setState(() {
        _productInfoName = product.name;
        _productInfoLoading = false;
      });
    } catch (e) {
      setState(() {
        _productInfoError = 'Error: $e';
        _productInfoLoading = false;
      });
    }
  }

  Future<void> _getProductsList() async {
    setState(() {
      _productsListLoading = true;
      _productsListError = null;
      _productsListTotal = null;
    });
    try {
      final response = await _sdk.getProductsList();
      setState(() {
        _productsListTotal = response.productsTotal;
        _productsListLoading = false;
      });
    } catch (e) {
      setState(() {
        _productsListError = 'Error: $e';
        _productsListLoading = false;
      });
    }
  }

  Future<void> _searchBlank() async {
    setState(() {
      _searchBlankLoading = true;
      _searchBlankError = null;
      _searchBlankProductCount = null;
      _searchBlankSuggestCount = null;
    });
    try {
      final response = await _sdk.searchBlank();
      setState(() {
        _searchBlankProductCount = response.products.length;
        _searchBlankSuggestCount = response.suggests.length;
        _searchBlankLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchBlankError = 'Error: $e';
        _searchBlankLoading = false;
      });
    }
  }

  Future<void> _searchInstant() async {
    final query = _searchInstantQueryController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searchInstantLoading = true;
      _searchInstantError = null;
      _searchInstantTotal = null;
    });
    try {
      final response = await _sdk.searchInstant(query);
      setState(() {
        _searchInstantTotal = response.productsTotal;
        _searchInstantLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchInstantError = 'Error: $e';
        _searchInstantLoading = false;
      });
    }
  }

  Future<void> _joinLoyalty() async {
    final phone = _loyaltyPhoneController.text.trim();
    if (phone.isEmpty) return;
    setState(() {
      _loyaltyLoading = true;
      _loyaltyError = null;
      _loyaltyResult = null;
    });
    try {
      final response = await _sdk.joinLoyalty(phone: phone);
      setState(() {
        _loyaltyResult = 'join: status=${response.status}';
        _loyaltyLoading = false;
      });
    } catch (e) {
      setState(() {
        _loyaltyError = 'Error: $e';
        _loyaltyLoading = false;
      });
    }
  }

  Future<void> _getLoyaltyStatus() async {
    final phone = _loyaltyPhoneController.text.trim();
    if (phone.isEmpty) return;
    setState(() {
      _loyaltyLoading = true;
      _loyaltyError = null;
      _loyaltyResult = null;
    });
    try {
      final response = await _sdk.getLoyaltyStatus(phone);
      setState(() {
        _loyaltyResult =
            'status: ${response.status}, member=${response.member}, '
            'level=${response.level?.name ?? '-'}';
        _loyaltyLoading = false;
      });
    } catch (e) {
      setState(() {
        _loyaltyError = 'Error: $e';
        _loyaltyLoading = false;
      });
    }
  }

  Future<void> _getCatalogProfile() async {
    setState(() {
      _catalogProfileLoading = true;
      _catalogProfileError = null;
      _catalogProfile = null;
    });
    try {
      final p = await _sdk.getProfile();
      setState(() {
        _catalogProfile =
            'id=${p.id ?? '-'}, hasEmail=${p.hasEmail ?? false}, '
            'gender=${p.gender ?? '-'}, props=${p.customProperties.length}';
        _catalogProfileLoading = false;
      });
    } catch (e) {
      setState(() {
        _catalogProfileError = 'Error: $e';
        _catalogProfileLoading = false;
      });
    }
  }

  Future<void> _getCatalogCounters() async {
    final item = _catalogCounterItemController.text.trim();
    if (item.isEmpty) return;
    setState(() {
      _catalogCountersLoading = true;
      _catalogCountersError = null;
      _catalogCounters = null;
    });
    try {
      final c = await _sdk.getProductCounters(item);
      setState(() {
        _catalogCounters =
            'now.view=${c.now?.view ?? 0}, daily.view=${c.daily?.view ?? 0}, '
            'priceDrop=${c.triggers?.priceDrop ?? 0}';
        _catalogCountersLoading = false;
      });
    } catch (e) {
      setState(() {
        _catalogCountersError = 'Error: $e';
        _catalogCountersLoading = false;
      });
    }
  }

  Future<void> _getCatalogCategory() async {
    final category = _catalogCategoryController.text.trim();
    if (category.isEmpty) return;
    setState(() {
      _catalogCategoryLoading = true;
      _catalogCategoryError = null;
      _catalogCategory = null;
    });
    try {
      final r = await _sdk.getCategory(category, limit: 5);
      setState(() {
        _catalogCategory =
            'total=${r.productsTotal}, products=${r.products.length}';
        _catalogCategoryLoading = false;
      });
    } catch (e) {
      setState(() {
        _catalogCategoryError = 'Error: $e';
        _catalogCategoryLoading = false;
      });
    }
  }

  Future<void> _getCatalogCollection() async {
    final id = _catalogCollectionController.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _catalogCollectionLoading = true;
      _catalogCollectionError = null;
      _catalogCollection = null;
    });
    try {
      final r = await _sdk.getCollection(id);
      setState(() {
        _catalogCollection = 'products=${r.products.length}';
        _catalogCollectionLoading = false;
      });
    } catch (e) {
      setState(() {
        _catalogCollectionError = 'Error: $e';
        _catalogCollectionLoading = false;
      });
    }
  }

  Future<void> _demoTrackEvent() async {
    if (_initState != InitState.initialized) return;
    try {
      await _sdk.trackEvent(
        'flutter_example',
        // 'source' is a reserved event key (collides with the SDK's own body
        // fields) — use a non-reserved custom key.
        customFields: const {'example_source': 'example_app'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('trackEvent sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('trackEvent failed: $e')));
    }
  }

  Future<void> _demoTrackPurchase() async {
    if (_initState != InitState.initialized) return;
    try {
      await _sdk.trackPurchase(
        orderId: 'example-order-1',
        orderPrice: 99.0,
        items: const [PurchaseLineItem(id: 'sku-1', amount: 1, price: 99.0)],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('trackPurchase sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('trackPurchase failed: $e')));
    }
  }

  Future<void> _copyToken() async {
    final token = _storedPushToken;
    if (token == null || token.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Token copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('REES46 SDK init demo')),
      // A SingleChildScrollView + Column (rather than a lazy ListView) so every
      // card and input field is always built and findable by integration tests,
      // even when off-screen. A ListView only builds children near the viewport,
      // which makes `find.byKey(...)` miss fields below the fold.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InitStatusCard(
              state: _initState,
              error: _initError,
              lastInitAt: _lastInitAt,
            ),
            const SizedBox(height: 12),
            _PushTokenCard(
              token: _storedPushToken,
              updatedAt: _tokenUpdatedAt,
              loading: _tokenLoading,
              onRefresh: _tokenLoading ? null : _refreshToken,
              onCopy: (_storedPushToken?.isNotEmpty ?? false)
                  ? _copyToken
                  : null,
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              value: _enableLogs,
              onChanged: (v) => setState(() => _enableLogs = v),
              title: const Text('enableLogs (iOS)'),
            ),
            SwitchListTile(
              value: _autoSendPushToken,
              onChanged: (v) => setState(() => _autoSendPushToken = v),
              title: const Text('autoSendPushToken'),
            ),
            SwitchListTile(
              value: _sendAdvertisingId,
              onChanged: (v) => setState(() => _sendAdvertisingId = v),
              title: const Text('sendAdvertisingId (iOS)'),
            ),
            SwitchListTile(
              value: _enableAutoPopupPresentation,
              onChanged: (v) =>
                  setState(() => _enableAutoPopupPresentation = v),
              title: const Text('enableAutoPopupPresentation (iOS)'),
            ),
            SwitchListTile(
              value: _needReInitialization,
              onChanged: (v) => setState(() => _needReInitialization = v),
              title: const Text('needReInitialization'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _initState == InitState.initializing
                  ? null
                  : _initialize,
              child: Text(
                _initState == InitState.initializing
                    ? 'Initializing…'
                    : 'Re-initialize',
              ),
            ),
            const SizedBox(height: 12),
            _ProfileCard(
              sid: _sid,
              did: _did,
              profileStatus: _profileStatus,
              enabled: _initState == InitState.initialized,
              onGetSid: _getSid,
              onGetDid: _getDid,
              onSetProfile: _setProfile,
            ),
            const SizedBox(height: 12),
            _RecommendationCard(
              blockController: _recBlockController,
              title: _recTitle,
              productCount: _recProductCount,
              error: _recError,
              loading: _recLoading,
              enabled: _initState == InitState.initialized,
              onGet: _getRecommendation,
            ),
            const SizedBox(height: 12),
            _ProductInfoCard(
              idController: _productIdController,
              productName: _productInfoName,
              error: _productInfoError,
              loading: _productInfoLoading,
              enabled: _initState == InitState.initialized,
              onGet: _getProductInfo,
            ),
            const SizedBox(height: 12),
            _ProductsListCard(
              total: _productsListTotal,
              error: _productsListError,
              loading: _productsListLoading,
              enabled: _initState == InitState.initialized,
              onGet: _getProductsList,
            ),
            const SizedBox(height: 12),
            _SearchBlankCard(
              productCount: _searchBlankProductCount,
              suggestCount: _searchBlankSuggestCount,
              error: _searchBlankError,
              loading: _searchBlankLoading,
              enabled: _initState == InitState.initialized,
              onSearch: _searchBlank,
            ),
            const SizedBox(height: 12),
            _SearchInstantCard(
              queryController: _searchInstantQueryController,
              total: _searchInstantTotal,
              error: _searchInstantError,
              loading: _searchInstantLoading,
              enabled: _initState == InitState.initialized,
              onSearch: _searchInstant,
            ),
            const SizedBox(height: 12),
            _SearchCard(
              queryController: _searchQueryController,
              total: _searchTotal,
              error: _searchError,
              loading: _searchLoading,
              enabled: _initState == InitState.initialized,
              onSearch: _searchFull,
            ),
            const SizedBox(height: 12),
            _LoyaltyCard(
              phoneController: _loyaltyPhoneController,
              result: _loyaltyResult,
              error: _loyaltyError,
              loading: _loyaltyLoading,
              enabled: _initState == InitState.initialized,
              onJoin: _joinLoyalty,
              onStatus: _getLoyaltyStatus,
            ),
            const SizedBox(height: 12),
            _CatalogCard(
              enabled: _initState == InitState.initialized,
              profile: _catalogProfile,
              profileError: _catalogProfileError,
              profileLoading: _catalogProfileLoading,
              onGetProfile: _getCatalogProfile,
              counterItemController: _catalogCounterItemController,
              counters: _catalogCounters,
              countersError: _catalogCountersError,
              countersLoading: _catalogCountersLoading,
              onGetCounters: _getCatalogCounters,
              categoryController: _catalogCategoryController,
              category: _catalogCategory,
              categoryError: _catalogCategoryError,
              categoryLoading: _catalogCategoryLoading,
              onGetCategory: _getCatalogCategory,
              collectionController: _catalogCollectionController,
              collection: _catalogCollection,
              collectionError: _catalogCollectionError,
              collectionLoading: _catalogCollectionLoading,
              onGetCollection: _getCatalogCollection,
            ),
            const SizedBox(height: 24),
            Text('Tracking', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Requires successful initialization above.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('example_demo_track_event'),
              onPressed: _initState == InitState.initialized
                  ? _demoTrackEvent
                  : null,
              child: const Text('Send demo trackEvent'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('example_demo_track_purchase'),
              onPressed: _initState == InitState.initialized
                  ? _demoTrackPurchase
                  : null,
              child: const Text('Send demo trackPurchase'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitStatusCard extends StatelessWidget {
  final InitState state;
  final String? error;
  final DateTime? lastInitAt;

  const _InitStatusCard({
    required this.state,
    required this.error,
    required this.lastInitAt,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = switch (state) {
      InitState.idle => 'Idle',
      InitState.initializing => 'Initializing…',
      InitState.initialized => 'Initialized',
      InitState.failed => 'Failed',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Initialization',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Status: $statusText'),
            if (lastInitAt != null)
              Text('Last init: ${lastInitAt!.toIso8601String()}'),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String? sid;
  final String? did;
  final String? profileStatus;
  final bool enabled;
  final VoidCallback onGetSid;
  final VoidCallback onGetDid;
  final VoidCallback onSetProfile;

  const _ProfileCard({
    required this.sid,
    required this.did,
    required this.profileStatus,
    required this.enabled,
    required this.onGetSid,
    required this.onGetDid,
    required this.onSetProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile & Session',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  key: const Key('btn_get_sid'),
                  onPressed: enabled ? onGetSid : null,
                  child: const Text('Get SID'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    key: const Key('lbl_sid'),
                    sid ?? '—',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  key: const Key('btn_get_did'),
                  onPressed: enabled ? onGetDid : null,
                  child: const Text('Get DID'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    key: const Key('lbl_did'),
                    did ?? '—',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  key: const Key('btn_set_profile'),
                  onPressed: enabled ? onSetProfile : null,
                  child: const Text('Set Profile'),
                ),
                const SizedBox(width: 8),
                if (profileStatus != null)
                  Text(key: const Key('lbl_profile_status'), profileStatus!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final TextEditingController blockController;
  final String? title;
  final int? productCount;
  final String? error;
  final bool loading;
  final bool enabled;
  final VoidCallback onGet;

  const _RecommendationCard({
    required this.blockController,
    required this.title,
    required this.productCount,
    required this.error,
    required this.loading,
    required this.enabled,
    required this.onGet,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('field_rec_block_code'),
              controller: blockController,
              decoration: const InputDecoration(
                labelText: 'Block code',
                hintText: 'e.g. main_page_2',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('btn_get_recommendations'),
              onPressed: (enabled && !loading) ? onGet : null,
              child: Text(loading ? 'Loading…' : 'Get Recommendations'),
            ),
            if (title != null) ...[
              const SizedBox(height: 8),
              Text(key: const Key('lbl_rec_title'), 'Title: $title'),
              Text(key: const Key('lbl_rec_count'), 'Products: $productCount'),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_rec_error'),
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductInfoCard extends StatelessWidget {
  final TextEditingController idController;
  final String? productName;
  final String? error;
  final bool loading;
  final bool enabled;
  final VoidCallback onGet;

  const _ProductInfoCard({
    required this.idController,
    required this.productName,
    required this.error,
    required this.loading,
    required this.enabled,
    required this.onGet,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Info',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('field_product_id'),
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'Product ID',
                hintText: 'e.g. sku-123',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('btn_get_product_info'),
              onPressed: (enabled && !loading) ? onGet : null,
              child: Text(loading ? 'Loading…' : 'Get Product Info'),
            ),
            if (productName != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_product_info_name'),
                'Name: $productName',
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_product_info_error'),
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoyaltyCard extends StatelessWidget {
  final TextEditingController phoneController;
  final String? result;
  final String? error;
  final bool loading;
  final bool enabled;
  final VoidCallback onJoin;
  final VoidCallback onStatus;

  const _LoyaltyCard({
    required this.phoneController,
    required this.result,
    required this.error,
    required this.loading,
    required this.enabled,
    required this.onJoin,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loyalty', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: const Key('field_loyalty_phone'),
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: 'e.g. 79991234567',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('btn_join_loyalty'),
                    onPressed: (enabled && !loading) ? onJoin : null,
                    child: Text(loading ? 'Loading…' : 'Join'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('btn_loyalty_status'),
                    onPressed: (enabled && !loading) ? onStatus : null,
                    child: Text(loading ? 'Loading…' : 'Status'),
                  ),
                ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 8),
              Text(key: const Key('lbl_loyalty_result'), result!),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_loyalty_error'),
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  final bool enabled;

  final String? profile;
  final String? profileError;
  final bool profileLoading;
  final VoidCallback onGetProfile;

  final TextEditingController counterItemController;
  final String? counters;
  final String? countersError;
  final bool countersLoading;
  final VoidCallback onGetCounters;

  final TextEditingController categoryController;
  final String? category;
  final String? categoryError;
  final bool categoryLoading;
  final VoidCallback onGetCategory;

  final TextEditingController collectionController;
  final String? collection;
  final String? collectionError;
  final bool collectionLoading;
  final VoidCallback onGetCollection;

  const _CatalogCard({
    required this.enabled,
    required this.profile,
    required this.profileError,
    required this.profileLoading,
    required this.onGetProfile,
    required this.counterItemController,
    required this.counters,
    required this.countersError,
    required this.countersLoading,
    required this.onGetCounters,
    required this.categoryController,
    required this.category,
    required this.categoryError,
    required this.categoryLoading,
    required this.onGetCategory,
    required this.collectionController,
    required this.collection,
    required this.collectionError,
    required this.collectionLoading,
    required this.onGetCollection,
  });

  @override
  Widget build(BuildContext context) {
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Catalog', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            // getProfile — no input; returns the current session's profile.
            OutlinedButton(
              key: const Key('btn_catalog_profile'),
              onPressed: (enabled && !profileLoading) ? onGetProfile : null,
              child: Text(profileLoading ? 'Loading…' : 'Get Profile'),
            ),
            if (profile != null) ...[
              const SizedBox(height: 8),
              Text(key: const Key('lbl_catalog_profile'), profile!),
            ],
            if (profileError != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_catalog_profile_error'),
                profileError!,
                style: errorStyle,
              ),
            ],
            const Divider(height: 24),

            // getProductCounters
            TextField(
              key: const Key('field_catalog_counter_item'),
              controller: counterItemController,
              decoration: const InputDecoration(
                labelText: 'Counters: item ID',
                hintText: 'e.g. sku-123',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('btn_catalog_counters'),
              onPressed: (enabled && !countersLoading) ? onGetCounters : null,
              child: Text(
                countersLoading ? 'Loading…' : 'Get Product Counters',
              ),
            ),
            if (counters != null) ...[
              const SizedBox(height: 8),
              Text(key: const Key('lbl_catalog_counters'), counters!),
            ],
            if (countersError != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_catalog_counters_error'),
                countersError!,
                style: errorStyle,
              ),
            ],
            const Divider(height: 24),

            // getCategory
            TextField(
              key: const Key('field_catalog_category'),
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: 'Category ID',
                hintText: 'e.g. 100',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('btn_catalog_category'),
              onPressed: (enabled && !categoryLoading) ? onGetCategory : null,
              child: Text(categoryLoading ? 'Loading…' : 'Get Category'),
            ),
            if (category != null) ...[
              const SizedBox(height: 8),
              Text(key: const Key('lbl_catalog_category'), category!),
            ],
            if (categoryError != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_catalog_category_error'),
                categoryError!,
                style: errorStyle,
              ),
            ],
            const Divider(height: 24),

            // getCollection
            TextField(
              key: const Key('field_catalog_collection'),
              controller: collectionController,
              decoration: const InputDecoration(
                labelText: 'Collection ID',
                hintText: 'e.g. 1',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('btn_catalog_collection'),
              onPressed: (enabled && !collectionLoading)
                  ? onGetCollection
                  : null,
              child: Text(collectionLoading ? 'Loading…' : 'Get Collection'),
            ),
            if (collection != null) ...[
              const SizedBox(height: 8),
              Text(key: const Key('lbl_catalog_collection'), collection!),
            ],
            if (collectionError != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_catalog_collection_error'),
                collectionError!,
                style: errorStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductsListCard extends StatelessWidget {
  final int? total;
  final String? error;
  final bool loading;
  final bool enabled;
  final VoidCallback onGet;

  const _ProductsListCard({
    required this.total,
    required this.error,
    required this.loading,
    required this.enabled,
    required this.onGet,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Products List',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('btn_get_products_list'),
              onPressed: (enabled && !loading) ? onGet : null,
              child: Text(loading ? 'Loading…' : 'Get Products List'),
            ),
            if (total != null) ...[
              const SizedBox(height: 8),
              Text(key: const Key('lbl_products_list_total'), 'Total: $total'),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_products_list_error'),
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchBlankCard extends StatelessWidget {
  final int? productCount;
  final int? suggestCount;
  final String? error;
  final bool loading;
  final bool enabled;
  final VoidCallback onSearch;

  const _SearchBlankCard({
    required this.productCount,
    required this.suggestCount,
    required this.error,
    required this.loading,
    required this.enabled,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Blank',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('btn_search_blank'),
              onPressed: (enabled && !loading) ? onSearch : null,
              child: Text(loading ? 'Loading…' : 'Search Blank'),
            ),
            if (productCount != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_search_blank_products'),
                'Products: $productCount',
              ),
              Text(
                key: const Key('lbl_search_blank_suggests'),
                'Suggests: $suggestCount',
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_search_blank_error'),
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchInstantCard extends StatelessWidget {
  final TextEditingController queryController;
  final int? total;
  final String? error;
  final bool loading;
  final bool enabled;
  final VoidCallback onSearch;

  const _SearchInstantCard({
    required this.queryController,
    required this.total,
    required this.error,
    required this.loading,
    required this.enabled,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Instant',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('field_search_instant_query'),
              controller: queryController,
              decoration: const InputDecoration(
                labelText: 'Instant query',
                hintText: 'e.g. pho',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('btn_search_instant'),
              onPressed: (enabled && !loading) ? onSearch : null,
              child: Text(loading ? 'Searching…' : 'Search Instant'),
            ),
            if (total != null) ...[
              const SizedBox(height: 8),
              Text(key: const Key('lbl_search_instant_total'), 'Total: $total'),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_search_instant_error'),
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController queryController;
  final int? total;
  final String? error;
  final bool loading;
  final bool enabled;
  final VoidCallback onSearch;

  const _SearchCard({
    required this.queryController,
    required this.total,
    required this.error,
    required this.loading,
    required this.enabled,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: const Key('field_search_query'),
              controller: queryController,
              decoration: const InputDecoration(
                labelText: 'Search query',
                hintText: 'e.g. phone',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('btn_search'),
              onPressed: (enabled && !loading) ? onSearch : null,
              child: Text(loading ? 'Searching…' : 'Search'),
            ),
            if (total != null) ...[
              const SizedBox(height: 8),
              Text(key: const Key('lbl_search_total'), 'Total: $total'),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                key: const Key('lbl_search_error'),
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PushTokenCard extends StatelessWidget {
  final String? token;
  final DateTime? updatedAt;
  final bool loading;
  final VoidCallback? onRefresh;
  final VoidCallback? onCopy;

  const _PushTokenCard({
    required this.token,
    required this.updatedAt,
    required this.loading,
    required this.onRefresh,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stored push token',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(token ?? 'Not available yet'),
            if (updatedAt != null)
              Text('Updated: ${updatedAt!.toIso8601String()}'),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: onRefresh,
                  child: Text(loading ? 'Refreshing…' : 'Refresh'),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: onCopy, child: const Text('Copy')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
