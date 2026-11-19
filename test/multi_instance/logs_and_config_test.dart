import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/core/sdk_logs.dart' show SdkLogs;
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

import '../support/wire.dart';

// `REES46.setLogHandler`: the native SDKs' messages and those of the SDK's Dart code
// reach the app's handler as the contract's `SdkLogMessage`, each by its shop's
// `logLevel`; the configuration carries the contract's fields to the native SDKs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    unstub('setLogForwarding');
    unstub('initialize');
    SdkLogs.reset();
    REES46.reset();
  });

  group('setLogHandler', () {
    test('turns the native forwarding on and off', () async {
      final calls = stubValue('setLogForwarding', null);

      REES46.setLogHandler((_) {});
      REES46.setLogHandler(null);
      await pumpEventQueue();

      expect(calls, [
        [true],
        [false],
      ]);
    });

    test(
      'a native message reaches the handler with its level and context',
      () async {
        stubValue('setLogForwarding', null);
        final heard = <SdkLogMessage>[];
        REES46.setLogHandler(heard.add);

        await sendStateEvent('onLog', <Object?>[
          pigeon.SdkLogMessageWire(
            level: 'warning',
            code: 'init_retry',
            message: '/init will be retried',
            shopId: 'shop-a',
            context: const <String, Object?>{'attempt': 2, 'path': 'init'},
          ),
        ]);

        final message = heard.single;
        expect(message.level, LogLevel.warning);
        expect(message.code, 'init_retry');
        expect(message.shopId, 'shop-a');
        expect(message.context, {'attempt': 2, 'path': 'init'});
      },
    );

    test('a handler that throws is caught', () async {
      stubValue('setLogForwarding', null);
      final printed = <String>[];
      final before = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => printed.add('$m');
      addTearDown(() => debugPrint = before);
      REES46.setLogHandler((_) => throw StateError('broken'));

      await sendStateEvent('onLog', <Object?>[
        pigeon.SdkLogMessageWire(
          level: 'error',
          code: 'init_refused',
          message: 'refused',
          context: const <String, Object?>{},
        ),
      ]);

      expect(printed.single, contains('log_handler_failed'));
    });

    test('messages of the Dart code pass by the shop\'s logLevel', () async {
      stubValue('setLogForwarding', null);
      stubValue('initialize', snapshotWire('quiet-shop'));
      final heard = <String>[];
      REES46.setLogHandler((m) => heard.add('${m.level.name} ${m.code}'));
      await REES46
          .initialize(
            const REES46Config(shopId: 'quiet-shop', logLevel: LogLevel.error),
          )
          .ready;
      await REES46
          .initialize(
            const REES46Config(shopId: 'chatty-shop', logLevel: LogLevel.debug),
          )
          .ready
          .catchError((_) {});

      SdkLogs.log(LogLevel.warning, 'area', 'dropped', shopId: 'quiet-shop');
      SdkLogs.log(LogLevel.error, 'area', 'kept', shopId: 'quiet-shop');
      SdkLogs.log(LogLevel.debug, 'area', 'kept', shopId: 'chatty-shop');
      SdkLogs.log(LogLevel.info, 'area', 'dropped', shopId: 'unknown-shop');

      expect(heard, ['error area', 'debug area']);
    });
  });

  group('the configuration', () {
    test('goes to the native SDK with the contract\'s fields', () async {
      final calls = stubValue('initialize', snapshotWire('shop-a'));

      await REES46
          .initialize(
            const REES46Config(
              shopId: 'shop-a',
              appDomain: ' app.cluster.test ',
              deviceId: 'did-kept',
              logLevel: LogLevel.info,
              storageKey: 'partition-a',
            ),
          )
          .ready;

      final config = calls.single.single! as pigeon.InitConfig;
      expect(config.appDomain, 'app.cluster.test');
      expect(config.deviceId, 'did-kept');
      expect(config.logLevel, 'info');
      expect(config.storageKey, 'partition-a');
    });

    test(
      'without them the native defaults apply; enableLogs is debug',
      () async {
        final calls = stubValue('initialize', snapshotWire('shop-a'));

        await REES46
            .initialize(
              // ignore: deprecated_member_use_from_same_package
              const REES46Config(shopId: 'shop-a', enableLogs: true),
            )
            .ready;

        final config = calls.single.single! as pigeon.InitConfig;
        expect(config.appDomain, isNull);
        expect(config.deviceId, isNull);
        expect(
          config.logLevel,
          isNull,
          reason: 'the native side reads enableLogs',
        );
        expect(config.enableLogs, isTrue);
        expect(config.storageKey, isNull);
        expect(
          const SdkInitConfig(shopId: 's', enableLogs: true).effectiveLogLevel,
          LogLevel.debug,
        );
        expect(
          const SdkInitConfig(shopId: 's').effectiveLogLevel,
          LogLevel.warning,
        );
      },
    );
  });
}
