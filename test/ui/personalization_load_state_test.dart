import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/widgets/personalization_load_state.dart';

void main() {
  late PersonalizationLoadController<List<String>> controller;
  late List<PersonalizationLoadState<List<String>>> states;

  setUp(() {
    controller = PersonalizationLoadController<List<String>>();
    states = <PersonalizationLoadState<List<String>>>[];
    controller.addListener(() => states.add(controller.value));
  });

  tearDown(() => controller.dispose());

  test('starts idle', () {
    expect(controller.value, isA<PersonalizationLoadIdle<List<String>>>());
  });

  test('loading, then the data', () async {
    await controller.load(() async => <String>['a']);
    expect(states, hasLength(2));
    expect(states[0], isA<PersonalizationLoadLoading<List<String>>>());
    final content = states[1] as PersonalizationLoadContent<List<String>>;
    expect(content.data, <String>['a']);
  });

  test('an empty answer is empty, not content', () async {
    await controller.load(() async => <String>[]);
    expect(controller.value, isA<PersonalizationLoadEmpty<List<String>>>());
  });

  test('a custom emptiness check', () async {
    final custom = PersonalizationLoadController<int>(isEmpty: (n) => n == 0);
    addTearDown(custom.dispose);
    await custom.load(() async => 0);
    expect(custom.value, isA<PersonalizationLoadEmpty<int>>());
    await custom.load(() async => 3);
    expect((custom.value as PersonalizationLoadContent<int>).data, 3);
  });

  test('an error, and retry repeats the same request', () async {
    var calls = 0;
    Future<List<String>> load() async {
      calls++;
      if (calls == 1) throw StateError('offline');
      return <String>['a'];
    }

    await controller.load(load);
    final error = controller.value as PersonalizationLoadError<List<String>>;
    expect(error.error, isStateError);

    await controller.retry();
    expect(calls, 2);
    expect(states.map((s) => s.runtimeType).toList(), <Type>[
      PersonalizationLoadLoading<List<String>>,
      PersonalizationLoadError<List<String>>,
      PersonalizationLoadLoading<List<String>>,
      PersonalizationLoadContent<List<String>>,
    ]);
  });

  test('retry without a request does nothing', () async {
    await controller.retry();
    expect(states, isEmpty);
  });

  test('an answer to an older request is dropped', () async {
    final slow = Completer<List<String>>();
    final first = controller.load(() => slow.future);
    await controller.load(() async => <String>['new']);
    slow.complete(<String>['old']);
    await first;
    expect(
      (controller.value as PersonalizationLoadContent<List<String>>).data,
      <String>['new'],
    );
  });

  test('reset goes back to idle and drops the request in flight', () async {
    final slow = Completer<List<String>>();
    final pending = controller.load(() => slow.future);
    controller.reset();
    slow.complete(<String>['late']);
    await pending;
    expect(controller.value, isA<PersonalizationLoadIdle<List<String>>>());
    await controller.retry();
    expect(controller.value, isA<PersonalizationLoadIdle<List<String>>>());
  });

  test('an answer after dispose is dropped quietly', () async {
    final own = PersonalizationLoadController<List<String>>();
    final slow = Completer<List<String>>();
    final pending = own.load(() => slow.future);
    own.dispose();
    slow.complete(<String>['late']);
    await pending;
  });
}
