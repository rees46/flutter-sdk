import 'package:flutter_test/flutter_test.dart';
import 'package:personalization_flutter_sdk/src/push/push_notification_callbacks.dart';

void main() {
  group('PushNotificationCallbacks', () {
    late PushNotificationCallbacks sut;

    setUp(() {
      sut = PushNotificationCallbacks();
    });

    group('dispatch', () {
      test('onPushReceived forwards to registered callback', () {
        Map<String, String?>? got;
        sut.setCallbacks(onReceived: (p) => got = p);

        sut.onPushReceived({'type': 'promo', 'id': null});

        expect(got, {'type': 'promo', 'id': null});
      });

      test('onPushDelivered forwards to registered callback', () {
        Map<String, String?>? got;
        sut.setCallbacks(onDelivered: (p) => got = p);

        sut.onPushDelivered({'id': '42'});

        expect(got, {'id': '42'});
      });

      test('onPushClicked forwards to registered callback', () {
        Map<String, String?>? got;
        sut.setCallbacks(onClicked: (p) => got = p);

        sut.onPushClicked({
          'id': '7',
          'actionIdentifier': 'com.apple.UNNotificationDefaultActionIdentifier',
        });

        expect(got!['id'], '7');
        expect(got!['actionIdentifier'], isNotNull);
      });
    });

    group('null safety', () {
      test('does not throw when no callback registered for received', () {
        expect(() => sut.onPushReceived({'k': 'v'}), returnsNormally);
      });

      test('does not throw when no callback registered for delivered', () {
        expect(() => sut.onPushDelivered({'k': 'v'}), returnsNormally);
      });

      test('does not throw when no callback registered for clicked', () {
        expect(() => sut.onPushClicked({'k': 'v'}), returnsNormally);
      });
    });

    group('copy semantics', () {
      test('received map is a copy — mutating original does not affect it', () {
        Map<String, String?>? got;
        sut.setCallbacks(onReceived: (p) => got = p);

        final original = <String, String?>{'key': 'before'};
        sut.onPushReceived(original);
        original['key'] = 'after';

        expect(got!['key'], 'before');
      });

      test('delivered map is a copy', () {
        Map<String, String?>? got;
        sut.setCallbacks(onDelivered: (p) => got = p);

        final original = <String, String?>{'key': 'before'};
        sut.onPushDelivered(original);
        original['key'] = 'after';

        expect(got!['key'], 'before');
      });

      test('clicked map is a copy', () {
        Map<String, String?>? got;
        sut.setCallbacks(onClicked: (p) => got = p);

        final original = <String, String?>{'key': 'before'};
        sut.onPushClicked(original);
        original['key'] = 'after';

        expect(got!['key'], 'before');
      });
    });

    group('setCallbacks replaces', () {
      test('second setCallbacks replaces first for same event', () {
        int first = 0;
        int second = 0;
        sut.setCallbacks(onReceived: (_) => first++);
        sut.onPushReceived({});
        sut.setCallbacks(onReceived: (_) => second++);
        sut.onPushReceived({});

        expect(first, 1);
        expect(second, 1);
      });

      test('each event type dispatches independently', () {
        Map<String, String?>? received;
        Map<String, String?>? delivered;
        sut.setCallbacks(
          onReceived: (p) => received = p,
          onDelivered: (p) => delivered = p,
        );

        sut.onPushReceived({'src': 'recv'});
        sut.onPushDelivered({'src': 'dlvr'});

        expect(received!['src'], 'recv');
        expect(delivered!['src'], 'dlvr');
      });
    });
  });
}
