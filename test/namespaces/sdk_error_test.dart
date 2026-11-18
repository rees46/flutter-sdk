import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

import '../support/wire.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SdkException.fromPlatform', () {
    SdkException map(String code, [Object? details]) =>
        SdkException.fromPlatform(
          PlatformException(code: code, message: 'm', details: details),
        );

    test('every native type becomes its SdkError', () {
      expect(map('notInitialized').error, const SdkErrorNotInitialized());
      expect(map('shopBlocked').error, const SdkErrorShopBlocked());
      expect(map('invalidArgument').error, const SdkErrorInvalidArgument('m'));
      expect(map('network').error, const SdkErrorNetwork());
      expect(map('timeout').error, const SdkErrorTimeout());
      expect(map('decoding').error, const SdkErrorDecoding());
      expect(map('cancelled').error, const SdkErrorCancelled());
      expect(
        map('http', {'httpCode': 503, 'serverCode': 'busy'}).error,
        const SdkErrorHttp(503, serverCode: 'busy'),
      );
    });

    test('type, httpCode and serverCode are read from the error', () {
      final e = map('http', {'httpCode': 429, 'serverCode': null});
      expect([e.type, e.httpCode, e.serverCode], ['http', 429, null]);
      final other = map('network', {'httpCode': null, 'serverCode': null});
      expect(
        [other.type, other.httpCode, other.serverCode],
        ['network', null, null],
      );
    });

    test('a call that reached no native code is notInitialized', () {
      expect(map('channel-error').error, const SdkErrorNotInitialized());
    });

    test('a type this release does not know is decoding', () {
      expect(map('somethingNew').error, const SdkErrorDecoding());
    });

    test('it stays a PlatformException with the type as its code', () {
      final e = map('http', {'httpCode': 404, 'serverCode': null});
      expect(e, isA<PlatformException>());
      expect(e.code, 'http');
      expect(e.details, {'httpCode': 404, 'serverCode': null});
      expect(e.message, 'm');
    });

    test('an SdkException passes through unchanged', () {
      final e = SdkException(const SdkErrorTimeout());
      expect(SdkException.fromPlatform(e), same(e));
      expect(e.message, 'The answer did not come in time');
    });
  });

  test('a namespace without the native side fails as notInitialized', () async {
    unstub('cartGet');
    await expectLater(
      PersonalizationSdk().cart.get(),
      throwsA(
        isA<SdkException>().having(
          (e) => e.error,
          'error',
          const SdkErrorNotInitialized(),
        ),
      ),
    );
  });
}
