import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:rees46_sdk_example/main.dart' as app;

Future<void> _initializeSdk(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(const app.App());
  await $(
    'Status: Initialized',
  ).waitUntilExists(timeout: const Duration(seconds: 30));
  await $('Status: Initialized').scrollTo(scrollDirection: AxisDirection.up);
}

String _labelText(PatrolIntegrationTester $, String key) {
  final widget = $.tester.widget<Text>(find.byKey(Key(key)));
  return widget.data ?? '';
}

void main() {
  // ---------------------------------------------------------------------------
  // getSid
  // ---------------------------------------------------------------------------
  patrolTest('getSid — returns non-empty string after init', ($) async {
    await _initializeSdk($);

    await $('Get SID').scrollTo();
    await $('Get SID').tap();
    await $.pumpAndSettle();

    final sid = _labelText($, 'lbl_sid');
    expect(sid, isNotEmpty);
    expect(sid, isNot('—'));
    expect(sid, isNot(contains('Error')));
  });

  patrolTest('getSid — consistent value on repeated calls', ($) async {
    await _initializeSdk($);

    await $('Get SID').scrollTo();
    await $('Get SID').tap();
    await $.pumpAndSettle();
    final first = _labelText($, 'lbl_sid');

    await $('Get SID').scrollTo();
    await $('Get SID').tap();
    await $.pumpAndSettle();
    final second = _labelText($, 'lbl_sid');

    expect(first, equals(second));
  });

  // ---------------------------------------------------------------------------
  // getDid
  // ---------------------------------------------------------------------------
  patrolTest('getDid — does not crash after init', ($) async {
    await _initializeSdk($);

    await $('Get DID').scrollTo();
    await $('Get DID').tap();
    await $.pumpAndSettle();

    final did = _labelText($, 'lbl_did');
    expect(did, isNot(contains('Error')));
  });

  patrolTest('getDid — result is a DID string or null before first sync', (
    $,
  ) async {
    await _initializeSdk($);

    await $('Get DID').scrollTo();
    await $('Get DID').tap();
    await $.pumpAndSettle();

    final did = _labelText($, 'lbl_did');
    // Either the SDK assigned a DID or returned null before the first API sync.
    expect(did == 'null' || (did.isNotEmpty && did != '—'), isTrue);
  });

  // ---------------------------------------------------------------------------
  // setProfile
  // ---------------------------------------------------------------------------
  patrolTest('setProfile — completes without error', ($) async {
    await _initializeSdk($);

    await $('Set Profile').scrollTo();
    await $('Set Profile').tap();
    await $.pumpAndSettle();

    final status = _labelText($, 'lbl_profile_status');
    expect(status, equals('Profile set'));
  });

  patrolTest('setProfile — can be called multiple times', ($) async {
    await _initializeSdk($);

    await $('Set Profile').scrollTo();
    await $('Set Profile').tap();
    await $.pumpAndSettle();
    expect(_labelText($, 'lbl_profile_status'), equals('Profile set'));

    await $('Set Profile').scrollTo();
    await $('Set Profile').tap();
    await $.pumpAndSettle();
    expect(_labelText($, 'lbl_profile_status'), equals('Profile set'));
  });
}
