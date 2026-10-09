import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/ui/widgets/stories_seen_store.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_sound.dart';

class _FakeHostApi extends pigeon.PersonalizationHostApi {
  final Map<String, List<String>> stored = <String, List<String>>{
    '40': <String>['36'],
  };
  final List<String> writes = <String>[];
  final List<String> audio = <String>[];
  int reads = 0;

  @override
  Future<Map<String, List<Object?>>> getStoriesSeen(String shop) async {
    reads++;
    return shop == 'shop-a' ? stored : <String, List<String>>{};
  }

  @override
  Future<void> setStorySlideSeen(
    String shop,
    String storyId,
    String slideId,
  ) async => writes.add('$shop/$storyId/$slideId');

  @override
  Future<void> beginStoriesAudio() async => audio.add('begin');

  @override
  Future<void> updateStoriesAudio(bool muted) async =>
      audio.add(muted ? 'muted' : 'sound');

  @override
  Future<void> endStoriesAudio() async => audio.add('end');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seen slides load once per shop and every mark is stored', () async {
    final api = _FakeHostApi();
    final store = StoriesSeenStore();
    final sdk = PersonalizationSdk(api: api, shopId: 'shop-a');

    expect(await store.load(sdk), <String, Set<String>>{
      '40': <String>{'36'},
    });
    store.mark(sdk, '40', '37');
    store.mark(sdk, '40', '37');
    expect(await store.load(sdk), <String, Set<String>>{
      '40': <String>{'36', '37'},
    });
    expect(api.reads, 1);
    expect(api.writes, <String>['shop-a/40/37']);
  });

  test('without the platform store, seen slides live in memory', () async {
    final store = StoriesSeenStore();
    // The real host API: no platform in tests, the channel fails.
    final sdk = PersonalizationSdk(shopId: 'shop-x');
    expect(await store.load(sdk), isEmpty);
    store.mark(sdk, '1', '2');
    expect(store.seen(sdk), <String, Set<String>>{
      '1': <String>{'2'},
    });
  });

  test('sound: muted first, volume up unmutes, the session follows', () async {
    final api = _FakeHostApi();
    StoriesSound.api = api;
    final sound = StoriesSound.instance;
    addTearDown(() => sound.muted.value = true);
    expect(sound.muted.value, isTrue);

    sound.attach();
    await sound.beforeVideo();
    await sound.afterVideo();
    await simulateKeyDownEvent(LogicalKeyboardKey.audioVolumeUp);
    expect(sound.muted.value, isFalse);
    await Future<void>.delayed(Duration.zero);

    sound.toggle();
    sound.detach();
    await Future<void>.delayed(Duration.zero);
    expect(api.audio, <String>['begin', 'muted', 'sound', 'muted', 'end']);
    expect(sound.muted.value, isTrue, reason: 'the choice outlives a viewer');
  });
}
