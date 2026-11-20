import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/personalization_sdk.dart'
    show PersonalizationStoryViewerBridge;
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

  final List<String> probed = <String>[];

  @override
  Future<bool?> storiesVideoHasAudio(String source) async {
    probed.add(source);
    if (source.endsWith('broken.mp4')) throw PlatformException(code: 'x');
    return source.endsWith('sound.mp4');
  }

  final List<String> shares = <String>[];

  @override
  Future<void> shareUrl(
    String url,
    double anchorX,
    double anchorY,
    double anchorWidth,
    double anchorHeight,
  ) async => shares.add('$url $anchorX,$anchorY $anchorWidth×$anchorHeight');
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

  test('the new feed keeps the sound button choice on the device', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final sound = StoriesSound.instance;
    addTearDown(() => sound.muted.value = true);
    await sound.restore();
    expect(sound.muted.value, isTrue, reason: 'muted by default');
    sound.toggle(remember: true);
    await Future<void>.delayed(Duration.zero);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(StoriesSound.mutedKey), isFalse);
    sound.muted.value = true;
    await sound.restore();
    expect(sound.muted.value, isFalse, reason: 'the stored choice');
    sound.toggle();
    await Future<void>.delayed(Duration.zero);
    expect(
      preferences.getBool(StoriesSound.mutedKey),
      isFalse,
      reason: 'the old feed does not store it',
    );
  });

  test(
    'the audio of a video: the platform answers, a failure is unknown',
    () async {
      final api = _FakeHostApi();
      StoriesSound.api = api;
      final sound = StoriesSound.instance;
      expect(await sound.hasAudio('/cache/sound.mp4'), isTrue);
      expect(await sound.hasAudio('https://cdn.example/mute.mp4'), isFalse);
      expect(await sound.hasAudio('https://cdn.example/broken.mp4'), isNull);
      expect(api.probed, <String>[
        '/cache/sound.mp4',
        'https://cdn.example/mute.mp4',
        'https://cdn.example/broken.mp4',
      ]);
    },
  );

  test('share hands the link and the button frame to the platform', () async {
    final api = _FakeHostApi();
    final sdk = PersonalizationSdk(api: api, shopId: 'shop-a');
    await sdk.shareUrl(
      'https://shop.test/?r46_story=5',
      const Rect.fromLTWH(320, 60, 32, 32),
    );
    expect(api.shares, <String>[
      'https://shop.test/?r46_story=5 320.0,60.0 32.0×32.0',
    ]);
  });
}
