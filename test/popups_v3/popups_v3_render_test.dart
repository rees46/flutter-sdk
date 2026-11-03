import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/personalization_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/popups_v3/popup_v3.dart';
import 'package:rees46_sdk/src/popups_v3/popups_v3_api.dart';
import 'package:rees46_sdk/src/popups_v3/popups_v3_engine.dart';
import 'package:rees46_sdk/src/ui/components/personalization_product.dart';
import 'package:rees46_sdk/src/ui/components/personalization_product_card.dart';
import 'package:rees46_sdk/src/ui/popups_v3/popup_v3_design.dart';
import 'package:rees46_sdk/src/ui/popups_v3/popup_v3_elements.dart';
import 'package:rees46_sdk/src/ui/popups_v3/popup_v3_grid.dart';
import 'package:rees46_sdk/src/ui/popups_v3/popup_v3_host.dart';
import 'package:rees46_sdk/src/ui/popups_v3/popup_v3_texts.dart';
import 'package:rees46_sdk/src/ui/popups_v3/popup_v3_view.dart';
import 'package:rees46_sdk/src/ui/widgets/personalization_request_cache.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_api_v3.dart';

import 'fixtures.dart';
import 'harness.dart';

/// Действия попапа, записанные для проверки.
class RecordingActions implements PopupV3Actions {
  RecordingActions({FakeHostApi? host})
    : sdk = PersonalizationSdk(api: host ?? FakeHostApi(), shopId: 'shop');

  @override
  final PersonalizationSdk sdk;

  final List<String> events = <String>[];
  final List<String> links = <String>[];
  final List<String> calls = <String>[];
  Object? error;

  @override
  void event(PopupV3Event event, {String? channel}) =>
      events.add(channel == null ? event.wire : '${event.wire}:$channel');

  @override
  Future<void> openLink(String url) async => links.add(url);

  /// Что ответит [openProduct]: товар открыл хост.
  bool hostOpensProducts = false;

  @override
  bool openProduct(PersonalizationProduct product) {
    calls.add('product ${product.id}');
    return hostOpensProducts;
  }

  Future<void> _call(String call) async {
    calls.add(call);
    final error = this.error;
    if (error != null) throw error;
  }

  @override
  Future<void> subscribeEmail({
    required String email,
    required List<String> consentFields,
    String? segmentId,
  }) => _call('subscribe $email $consentFields $segmentId');

  @override
  Future<void> submitProfile(PopupV3ProfileSubmission submission) => _call(
    'profile ${submission.email} ${submission.phone} ${submission.firstName} '
    '${submission.custom} ${submission.consentFields} ${submission.segmentId}',
  );

  @override
  Future<void> review({
    required String kind,
    required String code,
    required int rate,
    String? comment,
  }) => _call('review $kind "$code" $rate "${comment ?? ''}"');
}

/// Мост, который отвечает на рекомендации живым ответом из test/fixtures без картинок
/// (в виджет-тестах они не грузятся).
class _RecommendationsHostApi extends FakeHostApi {
  @override
  Future<String> getRecommendation(
    String code,
    String? paramsJson,
    String? shopId,
  ) async {
    final answer =
        jsonDecode(
              File('test/fixtures/recommend_extended.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    for (final product in (answer['recommends'] as List).cast<Map>()) {
      product
        ..remove('picture')
        ..remove('image_url')
        ..remove('image_url_resized');
    }
    return jsonEncode(answer);
  }

  @override
  Future<void> trackSetSource(
    pigeon.TrackingSourceWire source,
    String? shopId,
  ) async {}
}

/// Буфер обмена без платформы: что в него клали, по порядку.
List<String?> _mockClipboard(WidgetTester tester) {
  final copied = <String?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add(
          (call.arguments as Map<Object?, Object?>)['text'] as String?,
        );
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

PopupV3Design _parse(
  Map<String, Object?> popup, {
  Map<String, String> runtime = const <String, String>{},
}) => PopupV3Design.parse(
  popup['design'] as Map<String, Object?>,
  layout: PopupV3Layout.parse(popup['layout'])!,
  types: popupV3ElementBuilders.keys.toSet(),
  runtime: runtime,
);

/// Попап [popup] в рамке на экране 390×844.
Future<({RecordingActions actions, List<String> closes})> _pump(
  WidgetTester tester,
  Map<String, Object?> popup, {
  double maxHeight = 760,
  Map<String, String> runtime = const <String, String>{},
  RecordingActions? actions,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  actions ??= RecordingActions();
  final closes = <String>[];
  final design = _parse(popup, runtime: runtime);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PopupV3Scope(
          design: design,
          actions: actions,
          texts: PopupV3Texts.ru,
          onClose: () => closes.add('close'),
          onDismiss: () => closes.add('dismiss'),
          child: Material(
            type: MaterialType.transparency,
            child: Center(
              child: PopupV3FrameView(
                design: design,
                layout: PopupV3Layout.parse(popup['layout'])!,
                screen: const Size(390, 844),
                maxWidth: 390,
                maxHeight: maxHeight,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (actions: actions, closes: closes);
}

void main() {
  const fixtures = <String>[
    'element-text.json',
    'element-box.json',
    'element-button.json',
    'element-close.json',
    'element-image.json',
    'element-email-collector.json',
    'element-form.json',
    'element-promo-code.json',
    'element-survey.json',
    'element-recommendation.json',
    'grid.json',
    'breakpoints.json',
    'variables.json',
    'markup.json',
    'unknown-element.json',
    'legacy-free-elements.json',
  ];

  for (final name in fixtures) {
    testWidgets('$name renders without errors', (tester) async {
      await _pump(
        tester,
        popupsV3Fixture(name),
        runtime: const <String, String>{'promo_code': 'ABC123'},
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PopupV3FrameView), findsOneWidget);
    });
  }

  testWidgets('layouts.json renders every layout', (tester) async {
    for (final popup
        in (popupsV3Fixture('layouts.json')['popups'] as List)
            .cast<Map<String, Object?>>()) {
      await _pump(tester, popup);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('live 181 and 182 render all their elements', (tester) async {
    final popups =
        ((popupsV3Fixture('live-list-181-182.json')['payload']
                    as Map<String, Object?>)['popups']
                as List)
            .cast<Map<String, Object?>>();
    await _pump(tester, popups.first);
    expect(find.text('×'), findsOneWidget);
    expect(find.text('Test !@#%\$%^&*'), findsOneWidget);
    expect(find.text('Подробнее'), findsOneWidget);
    expect(find.text('Подписаться'), findsOneWidget);
    expect(find.text('Согласен получать рассылки'), findsOneWidget);
    expect(
      find.text('Насколько вероятно, что вы порекомендуете нас друзьям?'),
      findsOneWidget,
    );
    expect(find.text('10'), findsOneWidget);
    await _pump(tester, popups.last);
    expect(find.text('Fix Test'), findsOneWidget);
    expect(find.text('Ваш промокод'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('6'), findsNothing);
  });

  testWidgets('a tall popup scrolls inside a frame that stays put', (
    tester,
  ) async {
    final popup =
        ((popupsV3Fixture('live-list-181-182.json')['payload']
                        as Map<String, Object?>)['popups']
                    as List)
                .first
            as Map<String, Object?>;
    await _pump(tester, popup, maxHeight: 300);
    final frame = tester.getRect(find.byType(PopupV3FrameView));
    expect(frame.height, 300);
    final question = find.text(
      'Насколько вероятно, что вы порекомендуете нас друзьям?',
    );
    final before = tester.getTopLeft(question).dy;
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(question).dy, lessThan(before));
    expect(tester.getRect(find.byType(PopupV3FrameView)), frame);
  });

  testWidgets('the row: fractions, gap, min height, cell alignment', (
    tester,
  ) async {
    await _pump(tester, popupsV3Fixture('grid.json'));
    final rows = tester
        .renderObjectList<RenderPopupV3Row>(find.byType(PopupV3RowLayout))
        .toList();
    // row-a: minHeight 80, две колонки по 50 % с промежутком 12.
    expect(rows.first.size.height, greaterThanOrEqualTo(80));
    final rowA = find.byType(PopupV3RowLayout).first;
    final cells = find.descendant(
      of: rowA,
      matching: find.byType(PopupV3CellLayout),
    );
    final left = tester.getRect(cells.at(0));
    final right = tester.getRect(cells.at(1));
    expect(right.left - left.right, closeTo(12, 0.01));
    expect(left.width, closeTo(right.width, 0.01));
    expect(left.height, rows.first.size.height);
    // a1 в правой ячейке — по центру по обеим осям.
    final a1 = tester.getRect(find.text('A1'));
    expect(a1.center.dx, closeTo(right.center.dx, 1));
    expect(a1.center.dy, closeTo(right.center.dy, 1));
    // row-b: выравнивание строки — справа и снизу.
    final b0 = tester.getRect(find.text('B0'));
    final rowB = tester.getRect(find.byType(PopupV3RowLayout).at(1));
    expect(
      b0.right,
      closeTo(
        tester
            .getRect(
              find
                  .descendant(
                    of: find.byType(PopupV3RowLayout).at(1),
                    matching: find.byType(PopupV3CellLayout),
                  )
                  .first,
            )
            .right,
        0.5,
      ),
    );
    expect(b0.bottom, closeTo(rowB.bottom, 0.5));
    // row-d: шесть ячеек.
    expect(
      find.descendant(
        of: find.byType(PopupV3RowLayout).at(3),
        matching: find.byType(PopupV3CellLayout),
      ),
      findsNWidgets(6),
    );
    expect(find.text('Нет такой строки'), findsNothing);
  });

  testWidgets('buttons: close, copy and link', (tester) async {
    final copied = _mockClipboard(tester);
    final pumped = await _pump(tester, popupsV3Fixture('element-button.json'));
    await tester.tap(find.text('Не сейчас'));
    expect(pumped.closes, <String>['close']);
    await tester.tap(find.text('Скопировать код'));
    await tester.pump();
    expect(pumped.actions.events, <String>['click']);
    expect(copied, <String>['SALE10']);
    expect(find.text('Скопировано'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('Старый документ'));
    expect(pumped.actions.links, <String>['https://demo.rees46.ru']);
    expect(find.text('Подробнее'), findsOneWidget);
    await tester.tap(find.text('Подробнее'));
    expect(pumped.actions.links, hasLength(1));
    expect(pumped.actions.events, <String>['click', 'click', 'click']);
  });

  testWidgets('the close element: × by default, images and SVG as a cross', (
    tester,
  ) async {
    final pumped = await _pump(tester, popupsV3Fixture('element-close.json'));
    await tester.tap(find.text('×'));
    expect(pumped.closes, <String>['close']);
    expect(find.byType(PopupV3CloseCross), findsWidgets);
  });

  testWidgets('a text with a link opens it with a click event', (tester) async {
    final pumped = await _pump(tester, popupsV3Fixture('element-text.json'));
    await tester.tap(find.textContaining('Скидка 10%', findRichText: true));
    expect(pumped.actions.links, <String>['https://demo.rees46.ru/sale']);
    expect(pumped.actions.events, <String>['click']);
  });

  testWidgets('email: consent and format are checked, then success', (
    tester,
  ) async {
    final pumped = await _pump(
      tester,
      popupsV3Fixture('element-email-collector.json'),
    );
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'not an email');
    await tester.tap(find.text('Подписаться').first);
    await tester.pump();
    expect(find.text('Проверьте email'), findsOneWidget);
    expect(pumped.actions.calls, isEmpty);

    await tester.enterText(field, 'demo+flutter@rees46.test');
    await tester.tap(
      find.textContaining('Согласен получать', findRichText: true),
    );
    await tester.tap(find.text('Подписаться').first);
    await tester.pumpAndSettle();
    expect(pumped.actions.calls, <String>[
      'subscribe demo+flutter@rees46.test [email_bulk, email_chain] 123',
    ]);
    expect(find.text('Готово!'), findsOneWidget);
    expect(find.text('Проверьте почту'), findsOneWidget);
  });

  testWidgets(
    'email: a failed subscription shows an error and can be retried',
    (tester) async {
      final pumped = await _pump(
        tester,
        popupsV3Fixture('element-email-collector.json'),
      );
      pumped.actions.error = Exception('offline');
      await tester.enterText(find.byType(TextField).first, 'a@b.ru');
      await tester.tap(
        find.textContaining('Согласен получать', findRichText: true),
      );
      await tester.tap(find.text('Подписаться').first);
      await tester.pumpAndSettle();
      expect(find.text(PopupV3Texts.ru.sendError), findsOneWidget);
      pumped.actions.error = null;
      await tester.tap(find.text('Подписаться').first);
      await tester.pumpAndSettle();
      expect(pumped.actions.calls, hasLength(2));
      expect(find.text('Готово!'), findsOneWidget);
    },
  );

  testWidgets('form: required fields, then the profile', (tester) async {
    final pumped = await _pump(tester, popupsV3Fixture('element-form.json'));
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    expect(find.text('Заполните обязательные поля'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'anna@example.com');
    await tester.enterText(fields.at(2), 'Анна');
    await tester.enterText(fields.at(4), 'зелёный');
    await tester.tap(find.text('Согласен на обработку данных'));
    await tester.tap(find.text('Женский'));
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(pumped.actions.calls, <String>[
      'profile anna@example.com null Анна {fav_color: зелёный} [email_bulk] 456',
    ]);
    expect(find.text('Данные сохранены'), findsOneWidget);
  });

  testWidgets('survey: a score opens the comment, then thanks', (tester) async {
    final pumped = await _pump(tester, popupsV3Fixture('element-survey.json'));
    // Оценки шкалы — в ряд, а не по одной на всю ширину.
    expect(
      tester.getCenter(find.text('1').first).dy,
      tester.getCenter(find.text('2').first).dy,
    );
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('1').first,
                  matching: find.byType(Container),
                )
                .first,
          )
          .width,
      lessThan(60),
    );
    expect(find.text('Что можно улучшить?'), findsNothing);
    await tester.tap(find.text('0').first);
    await tester.pump();
    expect(find.text('Что можно улучшить?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Долгая доставка');
    await tester.ensureVisible(find.text('Отправить').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить').first);
    await tester.pumpAndSettle();
    expect(pumped.actions.calls, <String>[
      'review nps "test" 0 "Долгая доставка"',
    ]);
    expect(find.text('Спасибо за оценку!'), findsOneWidget);
  });

  testWidgets('survey: a failed review shows the error, the retry works', (
    tester,
  ) async {
    final pumped = await _pump(tester, popupsV3Fixture('element-survey.json'));
    pumped.actions.error = StoriesV3Exception('HTTP 404: Channel not found');
    await tester.tap(find.text('5').at(1));
    await tester.pump();
    await tester.ensureVisible(find.text('Отправить').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отправить').first);
    await tester.pumpAndSettle();
    expect(
      find.text('${PopupV3Texts.ru.sendError} (HTTP 404: Channel not found)'),
      findsOneWidget,
    );
    pumped.actions.error = null;
    await tester.tap(find.text('Отправить').first);
    await tester.pumpAndSettle();
    expect(pumped.actions.calls, <String>[
      'review csat "MNTEST" 5 ""',
      'review csat "MNTEST" 5 ""',
    ]);
    expect(find.text('Спасибо!'), findsOneWidget);
  });

  testWidgets('promo code: copy, then «copied» and the apply link', (
    tester,
  ) async {
    final copied = _mockClipboard(tester);
    final pumped = await _pump(
      tester,
      popupsV3Fixture('element-promo-code.json'),
      runtime: const <String, String>{'promo_code': 'ABC123'},
    );
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('WELCOME5'), findsOneWidget);
    await tester.tap(find.text('Копировать'));
    await tester.pump();
    expect(find.text('Скопировано!'), findsOneWidget);
    expect(copied, <String>['ABC123']);
    expect(pumped.actions.links, <String>['rees46demo://cart?promo=ABC123']);
    expect(pumped.actions.events, <String>['click']);
  });

  for (final hostOpens in <bool>[true, false]) {
    testWidgets(
      'a product of the recommendations: click, then '
      '${hostOpens ? 'the host opens it and the popup goes without close' : 'its link, the popup stays'}',
      (tester) async {
        PersonalizationRequestCache.shared.clear();
        final actions = RecordingActions(host: _RecommendationsHostApi())
          ..hostOpensProducts = hostOpens;
        final pumped = await _pump(
          tester,
          popupsV3Fixture('element-recommendation.json'),
          actions: actions,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PersonalizationProductCard).first);
        await tester.pump();
        expect(actions.events, <String>['click']);
        expect(actions.calls, <String>['product 52173']);
        expect(pumped.closes, hostOpens ? <String>['dismiss'] : isEmpty);
      },
    );
  }

  group('host', () {
    late List<Map<String, Object?>> live;

    setUp(() {
      live =
          ((popupsV3Fixture('live-list-181-182.json')['payload']
                      as Map<String, Object?>)['popups']
                  as List)
              .cast<Map<String, Object?>>();
    });

    Future<void> app(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('App'))),
      );
    }

    testWidgets('a modal over the root navigator; × closes it with an event', (
      tester,
    ) async {
      await app(tester);
      final actions = RecordingActions();
      final host = PopupV3Host(texts: PopupV3Texts.ru);
      final popup = PopupV3.tryParse(live.last)!;
      final shown = await host.present(
        popup,
        const <String, String>{},
        actions,
      );
      await tester.pumpAndSettle();
      expect(find.text('Fix Test'), findsOneWidget);
      var closed = false;
      shown!.closed.then((_) => closed = true);
      // Тап по затемнению закрывает окно.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Fix Test'), findsNothing);
      expect(closed, isTrue);
      expect(actions.events, <String>['close']);
    });

    testWidgets('a banner leaves the app tappable; × closes it', (
      tester,
    ) async {
      var taps = 0;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('App button'),
              ),
            ),
          ),
        ),
      );
      final actions = RecordingActions();
      final popup = PopupV3.tryParse(live.first)!;
      final shown = await PopupV3Host(
        texts: PopupV3Texts.ru,
      ).present(popup, const <String, String>{}, actions);
      await tester.pumpAndSettle();
      expect(find.text('Подробнее'), findsOneWidget);
      // Баннер сверху не выше экрана без поля 16 снизу.
      final banner = tester.getRect(find.byType(PopupV3FrameView));
      expect(banner.top, 0);
      expect(banner.bottom, lessThanOrEqualTo(844 - 16));
      await tester.tap(find.text('App button'));
      expect(taps, 1);
      await tester.tap(find.text('×'));
      await tester.pumpAndSettle();
      expect(find.text('Подробнее'), findsNothing);
      expect(actions.events, <String>['close']);
      var closed = false;
      await shown!.closed.then((_) => closed = true);
      expect(closed, isTrue);
    });

    for (final (index, name) in <(int, String)>[(0, 'banner'), (1, 'modal')]) {
      testWidgets(
        'the keyboard: the $name frame and the field in focus stay above it',
        (tester) async {
          await app(tester);
          final popup = PopupV3.tryParse(live[index])!;
          await PopupV3Host(
            texts: PopupV3Texts.ru,
          ).present(popup, const <String, String>{}, RecordingActions());
          await tester.pumpAndSettle();
          // Оценка открывает комментарий опроса.
          final score = find.text(index == 0 ? '9' : '5');
          await tester.ensureVisible(score.first);
          await tester.pumpAndSettle();
          await tester.tap(score.first);
          await tester.pumpAndSettle();
          final comment = find.byType(TextField).last;
          await tester.showKeyboard(comment);
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          const visibleBottom = 844.0 - 300;
          final frame = tester.getRect(find.byType(PopupV3FrameView));
          expect(frame.bottom, lessThanOrEqualTo(visibleBottom - 16 + 0.01));
          final field = tester.getRect(comment);
          expect(field.bottom, lessThanOrEqualTo(frame.bottom));
          expect(field.top, greaterThanOrEqualTo(frame.top));
        },
      );
    }

    /// Попадает ли касание в точку крестика баннера в сам крестик.
    bool closeReachable(WidgetTester tester) {
      final cross = find.text('×');
      final result = tester.hitTestOnBinding(tester.getCenter(cross));
      final paragraph = tester.renderObject(cross);
      return result.path.any((entry) => entry.target == paragraph);
    }

    for (final bannerFirst in <bool>[true, false]) {
      testWidgets('layers: the modal and its overlay lie over the banner '
          '(banner ${bannerFirst ? 'first' : 'second'})', (tester) async {
        await app(tester);
        final host = PopupV3Host(texts: PopupV3Texts.ru);
        final bannerActions = RecordingActions();
        final modalActions = RecordingActions();
        Future<PopupsV3Shown?> banner() => host.present(
          PopupV3.tryParse(live.first)!,
          const <String, String>{},
          bannerActions,
        );
        Future<PopupsV3Shown?> modal() => host.present(
          PopupV3.tryParse(live.last)!,
          const <String, String>{},
          modalActions,
        );
        if (bannerFirst) {
          await banner();
          await tester.pumpAndSettle();
          expect(closeReachable(tester), isTrue);
          await modal();
        } else {
          await modal();
          await tester.pumpAndSettle();
          await banner();
        }
        await tester.pumpAndSettle();
        expect(find.text('Fix Test'), findsOneWidget);
        expect(find.text('Подробнее'), findsOneWidget);
        // Баннер под затемнением окна: его крестик не нажать.
        expect(closeReachable(tester), isFalse);
        // Ещё одна страница приложения не поднимает баннер над окном.
        unawaited(
          tester
              .state<NavigatorState>(find.byType(Navigator))
              .push(
                MaterialPageRoute<void>(builder: (_) => const Text('Page')),
              ),
        );
        await tester.pumpAndSettle();
        expect(closeReachable(tester), isFalse);
        // Первое «назад» закрывает страницу, второе — окно; баннер снова доступен.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Fix Test'), findsOneWidget);
        expect(closeReachable(tester), isFalse);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Fix Test'), findsNothing);
        expect(modalActions.events, <String>['close']);
        expect(closeReachable(tester), isTrue);
        await tester.tap(find.text('×'));
        await tester.pumpAndSettle();
        expect(bannerActions.events, <String>['close']);
      });
    }

    testWidgets('dismiss removes the popup without an event', (tester) async {
      await app(tester);
      final actions = RecordingActions();
      final shown = await PopupV3Host(texts: PopupV3Texts.ru).present(
        PopupV3.tryParse(live.last)!,
        const <String, String>{},
        actions,
      );
      await tester.pumpAndSettle();
      shown!.dismiss();
      await tester.pumpAndSettle();
      expect(find.text('Fix Test'), findsNothing);
      expect(actions.events, isEmpty);
    });

    testWidgets('an empty design is not shown', (tester) async {
      await app(tester);
      final shown = await PopupV3Host().present(
        PopupV3.tryParse(popupsV3Fixture('empty-design.json'))!,
        const <String, String>{},
        RecordingActions(),
      );
      expect(shown, isNull);
    });
  });
}
