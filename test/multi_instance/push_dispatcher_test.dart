import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/multi_instance/push_dispatcher.dart';
import 'package:rees46_sdk/src/push/push_notification_callbacks.dart';

/// FL-5 contract: the process-global [PushDispatcher] routes each inbound push —
/// tagged with the `shopId` native resolved — to that shop's callbacks; unknown
/// drops, a null `shopId` falls back to the single registered target.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dispatcher = PushDispatcher.instance;

  PushNotificationCallbacks sink({
    void Function(Map<String, String?>)? onReceived,
    void Function(Map<String, String?>)? onDelivered,
    void Function(Map<String, String?>)? onClicked,
  }) => PushNotificationCallbacks()
    ..setCallbacks(
      onReceived: onReceived,
      onDelivered: onDelivered,
      onClicked: onClicked,
    );

  setUp(dispatcher.reset);

  test('routes a shop_id-tagged push to that shop only', () {
    Map<String, String?>? gotA;
    Map<String, String?>? gotB;
    dispatcher.register('A', sink(onReceived: (p) => gotA = p));
    dispatcher.register('B', sink(onReceived: (p) => gotB = p));

    dispatcher.onPushReceived('B', {'shop_id': 'B', 'title': 'hi'});

    expect(gotB, isNotNull);
    expect(gotB!['title'], 'hi');
    expect(gotA, isNull);
  });

  test('unknown shop_id is dropped', () {
    var fired = 0;
    dispatcher.register('A', sink(onReceived: (_) => fired++));

    dispatcher.onPushReceived('zzz', {'shop_id': 'zzz'});

    expect(fired, 0);
  });

  test('null shop_id with one registered falls back to it', () {
    Map<String, String?>? got;
    dispatcher.register('A', sink(onReceived: (p) => got = p));

    dispatcher.onPushReceived(null, {'title': 'x'});

    expect(got, isNotNull);
  });

  test('null shop_id with two registered is ambiguous and dropped', () {
    var fired = 0;
    dispatcher.register('A', sink(onReceived: (_) => fired++));
    dispatcher.register('B', sink(onReceived: (_) => fired++));

    dispatcher.onPushReceived(null, {});

    expect(fired, 0);
  });

  test('delivered and clicked route to the resolved shop', () {
    final events = <String>[];
    dispatcher.register(
      'A',
      sink(
        onDelivered: (_) => events.add('delivered'),
        onClicked: (_) => events.add('clicked'),
      ),
    );

    dispatcher.onPushDelivered('A', {});
    dispatcher.onPushClicked('A', {});

    expect(events, ['delivered', 'clicked']);
  });

  test('legacy default (null-shop registration) receives a null-shop push', () {
    Map<String, String?>? got;
    dispatcher.register(null, sink(onReceived: (p) => got = p));

    dispatcher.onPushReceived(null, {'title': 'legacy'});

    expect(got, isNotNull);
    expect(got!['title'], 'legacy');
  });
}
