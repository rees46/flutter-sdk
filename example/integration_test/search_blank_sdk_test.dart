import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:rees46_sdk_example/main.dart' as app;

import 'patrol_setup.dart';

Future<void> _initializeSdk(PatrolIntegrationTester $) async {
  await $.pumpWidgetAndSettle(const app.App());
  await dismissStartupPermissionDialog($);
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
  patrolTest('searchBlank — returns products and suggests counts', ($) async {
    await _initializeSdk($);

    await $(const Key('btn_search_blank')).scrollTo();
    await $(const Key('btn_search_blank')).tap();
    await waitForResultOrError($, 'lbl_search_blank_products', 'lbl_search_blank_error');

    expect(find.byKey(const Key('lbl_search_blank_error')), findsNothing);

    final productsText = _labelText($, 'lbl_search_blank_products');
    final suggestsText = _labelText($, 'lbl_search_blank_suggests');

    expect(productsText, startsWith('Products:'));
    expect(suggestsText, startsWith('Suggests:'));

    final products = int.tryParse(productsText.replaceFirst('Products: ', ''));
    final suggests = int.tryParse(suggestsText.replaceFirst('Suggests: ', ''));
    expect(products, isNotNull);
    expect(suggests, isNotNull);
    expect(products, greaterThanOrEqualTo(0));
    expect(suggests, greaterThanOrEqualTo(0));
  });

  patrolTest('searchBlank — can be called multiple times', ($) async {
    await _initializeSdk($);

    await $(const Key('btn_search_blank')).scrollTo();
    await $(const Key('btn_search_blank')).tap();
    await waitForResultOrError($, 'lbl_search_blank_products', 'lbl_search_blank_error');
    final firstProducts = _labelText($, 'lbl_search_blank_products');

    await $(const Key('btn_search_blank')).scrollTo();
    await $(const Key('btn_search_blank')).tap();
    await waitForResultOrError($, 'lbl_search_blank_products', 'lbl_search_blank_error');
    final secondProducts = _labelText($, 'lbl_search_blank_products');

    expect(firstProducts, equals(secondProducts));
  });

  patrolTest('searchBlank — no error on first call after init', ($) async {
    await _initializeSdk($);

    await $(const Key('btn_search_blank')).scrollTo();
    await $(const Key('btn_search_blank')).tap();
    await waitForResultOrError($, 'lbl_search_blank_products', 'lbl_search_blank_error');

    expect(find.byKey(const Key('lbl_search_blank_error')), findsNothing);
    expect(find.byKey(const Key('lbl_search_blank_products')), findsOneWidget);
  });
}
