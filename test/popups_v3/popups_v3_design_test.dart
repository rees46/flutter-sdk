import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/popups_v3/popup_v3.dart';
import 'package:rees46_sdk/src/ui/popups_v3/css_color.dart';
import 'package:rees46_sdk/src/ui/popups_v3/popup_markup.dart';
import 'package:rees46_sdk/src/ui/popups_v3/popup_v3_design.dart';
import 'package:rees46_sdk/src/ui/popups_v3/popup_v3_elements.dart';

import 'fixtures.dart';

final Set<String> _types = popupV3ElementBuilders.keys.toSet();

PopupV3Design _design(
  Map<String, Object?> popup, {
  Map<String, String> runtime = const <String, String>{},
  TargetPlatform platform = TargetPlatform.android,
}) => PopupV3Design.parse(
  popup['design'] as Map<String, Object?>,
  layout: PopupV3Layout.parse(popup['layout'])!,
  types: _types,
  runtime: runtime,
  platform: platform,
);

Map<String, Object> _span(PopupMarkupSpan span) => <String, Object>{
  'text': span.text,
  if (span.bold) 'bold': true,
  if (span.italic) 'italic': true,
  if (span.underline) 'underline': true,
  if (span.strike) 'strike': true,
  if (span.overline) 'overline': true,
};

String _hex(Color color) => cssColorHex(color);

void main() {
  test('element-text.json: markup, numbers as strings, shadow alpha, link', () {
    final fixture = popupsV3Fixture('element-text.json');
    final expectations = popupsV3Expect(fixture);
    final design = _design(fixture);

    final full = design.element('el-text-full')!;
    final fullExpect = expectations['el-text-full'] as Map<String, Object?>;
    final box = full.box;
    expect(
      design.variables.rich(full.text('message')).map(_span).toList(),
      fullExpect['spans'],
    );
    expect(full.messageAlign, TextAlign.center);
    expect(full.alignIn(PopupV3Align.left), PopupV3Align.center);
    expect(full.messageFontSize, fullExpect['fontSize']);
    expect(full.messageFontWeight, fullExpect['fontWeight']);
    expect(box.lineHeight, fullExpect['lineHeight']);
    expect(box.letterSpacing, fullExpect['letterSpacing']);
    expect(box.opacity, fullExpect['opacity']);
    expect(box.paddingX, fullExpect['paddingX']);
    expect(box.paddingY, fullExpect['paddingY']);
    expect(_hex(box.textColor), fullExpect['textColor']);
    expect(_hex(box.background), fullExpect['bgColor']);
    expect(_hex(box.borderColor), fullExpect['borderColor']);
    final shadow = fullExpect['shadow'] as Map<String, Object?>;
    expect(box.shadow!.y, shadow['y']);
    expect(box.shadow!.blur, shadow['blur']);
    expect(_hex(box.shadow!.color), shadow['color']);
    expect(full.link(design.variables), fullExpect['link']);

    final bare = design.element('el-text-bare')!;
    final bareExpect = expectations['el-text-bare'] as Map<String, Object?>;
    expect(bare.messageFontSize, bareExpect['fontSize']);
    expect(bare.messageFontWeight, bareExpect['fontWeight']);
    expect(_hex(bare.box.background), bareExpect['bgColor']);
    expect(_hex(bare.box.textColor), bareExpect['textColor']);
    expect(bare.box.lineHeight, bareExpect['lineHeight']);
    expect(bare.messageAlign, TextAlign.left);
    expect(bare.box.shadow, isNull);

    // CSS-позиционирование не поддерживается, элемент остаётся в потоке.
    expect(design.element('el-text-css-position'), isNotNull);
  });

  test('element-box.json: the box defaults and an empty plate', () {
    final fixture = popupsV3Fixture('element-box.json');
    final expectations = popupsV3Expect(fixture);
    final design = _design(fixture);
    for (final id in <String>['el-box-defaults', 'el-box-empty']) {
      final element = design.element(id)!;
      final expected = expectations[id] as Map<String, Object?>;
      expect(_hex(element.box.background), expected['bgColor'], reason: id);
      expect(element.box.radius, expected['borderRadius'], reason: id);
      expect(element.box.paddingX, expected['paddingX'], reason: id);
      expect(element.box.paddingY, expected['paddingY'], reason: id);
    }
    expect(design.element('el-box-defaults')!.messageFontSize, 12);
    expect(design.element('el-box-empty')!.text('message'), isNull);
  });

  group('element-button.json', () {
    final fixture = popupsV3Fixture('element-button.json');
    final expectations = popupsV3Expect(fixture);

    test('actions, hrefs and copy texts', () {
      final android = _design(fixture);
      final ios = _design(fixture, platform: TargetPlatform.iOS);
      final link = android.element('el-btn-link')!;
      final linkExpect = expectations['el-btn-link'] as Map<String, Object?>;
      final href = linkExpect['href'] as Map<String, Object?>;
      expect(link.buttonAction, 'link');
      expect(link.buttonHref(android.variables), href['android']);
      expect(
        ios.element('el-btn-link')!.buttonHref(ios.variables),
        href['ios'],
      );
      expect(
        android.variables.rich(link.text('buttonText')).map(_span).toList(),
        linkExpect['spans'],
      );
      expect(link.alignIn(PopupV3Align.center), PopupV3Align.left);
      expect(_hex(link.color('buttonBgColor', '#000')), linkExpect['bgColor']);
      expect(
        _hex(link.color('buttonTextColor', '#000')),
        linkExpect['textColor'],
      );
      expect(link.number('buttonFontSize', 12), linkExpect['fontSize']);
      expect(link.number('buttonRadius', 0), linkExpect['radius']);
      expect(link.number('buttonPaddingX', 0), linkExpect['paddingX']);
      expect(link.number('buttonPaddingY', 0), linkExpect['paddingY']);
      // Обёртка кнопки без фона и рамки.
      expect(link.box.background.a, 0);

      expect(
        android.element('el-btn-ios-var')!.buttonHref(android.variables),
        (expectations['el-btn-ios-var'] as Map<String, Object?>)['href'],
      );
      expect(android.element('el-btn-close')!.buttonAction, 'close');
      final copy = android.element('el-btn-copy')!;
      expect(copy.buttonAction, 'copy');
      expect(
        copy.copyText(android.variables),
        (expectations['el-btn-copy'] as Map<String, Object?>)['clipboard'],
      );
      expect(
        android.element('el-btn-copy-fallback')!.copyText(android.variables),
        (expectations['el-btn-copy-fallback']
            as Map<String, Object?>)['clipboard'],
      );
      final legacy = android.element('el-btn-legacy-href')!;
      expect(legacy.buttonAction, 'link');
      expect(
        legacy.buttonHref(android.variables),
        (expectations['el-btn-legacy-href'] as Map<String, Object?>)['href'],
      );
      final unknown = android.element('el-btn-unknown-action')!;
      expect(unknown.buttonAction, 'link');
      expect(
        unknown.buttonHref(android.variables),
        (expectations['el-btn-unknown-action'] as Map<String, Object?>)['href'],
      );
    });

    test('an empty button takes the editor defaults', () {
      final design = _design(fixture);
      final button = design.element('el-btn-defaults')!;
      final expected = expectations['el-btn-defaults'] as Map<String, Object?>;
      expect(button.buttonAction, expected['action']);
      expect(button.text('buttonText'), isNull);
      expect(button.alignIn(PopupV3Align.left), PopupV3Align.center);
      expect(_hex(button.color('buttonBgColor', '#000')), expected['bgColor']);
      expect(
        _hex(button.color('buttonTextColor', '#000')),
        expected['textColor'],
      );
      expect(button.number('buttonFontSize', 12), expected['fontSize']);
      expect(button.number('buttonPaddingX', 0), expected['paddingX']);
      expect(button.number('buttonPaddingY', 0), expected['paddingY']);
      expect(button.number('buttonRadius', 0), expected['radius']);
      expect(button.buttonHref(design.variables), isNull);
    });
  });

  test('element-close.json: modes, the × default, size 8–128', () {
    final fixture = popupsV3Fixture('element-close.json');
    final expectations = popupsV3Expect(fixture);
    final design = _design(fixture);

    final close = design.element('el-close-default')!;
    final closeExpect =
        expectations['el-close-default'] as Map<String, Object?>;
    expect(close.buttonAction, 'close');
    expect(close.closeMode, closeExpect['mode']);
    expect(close.text('buttonText'), isNull);
    expect(close.alignIn(PopupV3Align.left), PopupV3Align.right);
    expect(_hex(close.color('buttonBgColor', '#000')), closeExpect['bgColor']);
    expect(
      _hex(close.color('buttonTextColor', '#000')),
      closeExpect['textColor'],
    );
    expect(close.number('buttonFontSize', 0), closeExpect['fontSize']);
    expect(close.number('buttonPaddingX', 0), closeExpect['paddingX']);
    expect(close.number('buttonPaddingY', 0), closeExpect['paddingY']);
    expect(close.number('buttonRadius', 0), closeExpect['radius']);

    final text = design.element('el-close-text')!;
    expect(text.text('buttonText'), 'Закрыть ×');
    expect(text.alignIn(PopupV3Align.right), PopupV3Align.left);
    expect(text.number('buttonFontSize', 22), 16);

    final image = design.element('el-close-image')!;
    final imageExpect = expectations['el-close-image'] as Map<String, Object?>;
    expect(image.closeMode, 'image');
    expect(image.closeImageUrl(design.variables), imageExpect['url']);
    expect(image.closeIconSize, imageExpect['size']);

    final svg = design.element('el-close-svg')!;
    expect(svg.closeMode, 'svg');
    expect(svg.closeIconSize, 8);
    expect(svg.closeSvg, isNot(contains('script')));
    expect(svg.closeSvg, isNot(contains('onload')));
    expect(svg.closeSvg, startsWith('<svg'));
  });

  test('element-image.json: variables, heights, fit, ratio, hidden', () {
    final fixture = popupsV3Fixture('element-image.json');
    final expectations = popupsV3Expect(fixture);
    final design = _design(fixture);

    final auto = design.element('el-img-auto')!;
    final autoExpect = expectations['el-img-auto'] as Map<String, Object?>;
    expect(auto.stretch, isTrue);
    expect(
      popupV3ImageUrl(auto.text('imageUrl'), design.variables),
      autoExpect['url'],
    );
    expect(auto.imageHeight, const PopupV3ImageHeight.auto());
    expect(auto.imageFit, BoxFit.cover);
    expect(auto.number('imageRadius', 0), autoExpect['radius']);
    expect(auto.number('imageMarginBottom', 0), autoExpect['marginBottom']);
    expect(auto.link(design.variables), autoExpect['link']);

    final px = design.element('el-img-px')!;
    expect(px.imageHeight, const PopupV3ImageHeight.px(180));
    expect(px.imageFit, BoxFit.contain);
    expect(
      design.element('el-img-percent')!.imageHeight,
      const PopupV3ImageHeight.percent(100),
    );
    final vh = design.element('el-img-vh')!.imageHeight;
    expect(vh, const PopupV3ImageHeight.vh(40));
    expect(vh.resolve(800), 320);
    expect(
      design.element('el-img-ratio')!.imageAspectRatio,
      closeTo(1.7778, 0.0001),
    );
    final bad = design.element('el-img-bad-ratio')!;
    expect(bad.imageAspectRatio, isNull);
    expect(bad.imageFit, BoxFit.cover);
    expect(design.element('el-img-hidden')!.showImage, isFalse);
  });

  test('element-email-collector.json: layouts, consent fields, success', () {
    final fixture = popupsV3Fixture('element-email-collector.json');
    final expectations = popupsV3Expect(fixture);
    final design = _design(fixture);

    final inline = design.element('el-email-inline')!;
    final inlineExpect =
        expectations['el-email-inline'] as Map<String, Object?>;
    expect(inline.emailInline, isTrue);
    expect(inline.emailConsentFields, inlineExpect['consentFields']);
    expect(
      design.variables.rich(inline.emailConsentLabel).map(_span).toList(),
      inlineExpect['consentSpans'],
    );
    expect(inline.segmentId('emailSegmentId'), inlineExpect['segmentId']);
    final success = inlineExpect['success'] as Map<String, Object?>;
    expect(inline.text('emailSuccessTitle'), success['title']);
    expect(inline.text('emailSuccessMessage'), success['message']);
    expect(_hex(inline.color('emailSuccessBg', '#000')), success['bg']);
    expect(inline.value('emailSuccessAlign'), success['align']);

    final legacy = design.element('el-email-stacked-legacy')!;
    final legacyExpect =
        expectations['el-email-stacked-legacy'] as Map<String, Object?>;
    expect(legacy.emailInline, isFalse);
    expect(legacy.emailConsentFields, legacyExpect['consentFields']);
    expect(legacy.emailConsentLabel, legacyExpect['consentLabel']);

    final bare = design.element('el-email-bare')!;
    final bareExpect = expectations['el-email-bare'] as Map<String, Object?>;
    expect(bare.emailInline, isFalse);
    expect(bare.emailConsentFields, bareExpect['consentFields']);
    expect(bare.emailConsentLabel, isNull);
    expect(bare.segmentId('emailSegmentId'), isNull);
    // Коробка формы: белый фон, текст #0f172a, радиус 12, поля 12.
    expect(_hex(bare.box.background), '#ffffffff');
    expect(_hex(bare.box.textColor), '#0f172aff');
    expect(bare.box.radius, 12);
    expect(bare.box.paddingX, 12);
  });

  test('element-form.json: fields normalized like the compiler', () {
    final fixture = popupsV3Fixture('element-form.json');
    final expectations = popupsV3Expect(fixture);
    final design = _design(fixture);
    final form = design.element('el-form')!;
    final expected = expectations['el-form'] as Map<String, Object?>;
    expect(
      <Map<String, Object?>>[
        for (final field in form.formFields)
          <String, Object?>{
            'id': field.id,
            'kind': field.kind,
            'required': field.required,
            'propertyKey': field.propertyKey,
          },
      ],
      <Map<String, Object?>>[
        for (final field
            in (expected['fields'] as List).cast<Map<String, Object?>>())
          <String, Object?>{
            'id': field['id'],
            'kind': field['kind'],
            'required': field['required'],
            'propertyKey': field['propertyKey'],
          },
      ],
    );
    expect(form.formConsentFields, expected['consentFields']);
    expect(form.segmentId('formSegmentId'), expected['segmentId']);

    final bare = design.element('el-form-bare')!;
    expect(bare.formFields, isEmpty);
    expect(bare.formConsentFields, isEmpty);
  });

  test('element-promo-code.json: personal and static codes', () {
    final fixture = popupsV3Fixture('element-promo-code.json');
    final expectations = popupsV3Expect(fixture);
    final design = _design(
      fixture,
      runtime: <String, String>{'promo_code': 'ABC123'},
    );

    final personal = design.element('el-promo-personal')!;
    final personalExpect =
        expectations['el-promo-personal'] as Map<String, Object?>;
    expect(personal.promoStatic, isFalse);
    expect(personal.promoCode(design.variables), 'ABC123');
    expect(personal.value('messageAlign'), personalExpect['align']);
    expect(
      personal.number('promoCodeFontSize', 20),
      personalExpect['fontSize'],
    );
    expect(personal.promoShowCopy, isTrue);
    expect(personal.text('promoCopiedText'), 'Скопировано!');
    expect(
      personal.promoApplyHref(design.variables),
      'rees46demo://cart?promo=ABC123',
    );

    final stat = design.element('el-promo-static')!;
    expect(stat.promoStatic, isTrue);
    expect(
      stat.promoCode(design.variables),
      (expectations['el-promo-static'] as Map<String, Object?>)['code'],
    );
    expect(stat.promoShowCopy, isFalse);

    final text = design.element('el-text-with-code')!;
    expect(
      design.variables.rich(text.text('message')).map(_span).toList(),
      (expectations['el-text-with-code']
          as Map<String, Object?>)['spans_after_substitution_example'],
    );
  });

  test('element-survey.json: scales and codes', () {
    final fixture = popupsV3Fixture('element-survey.json');
    final expectations = popupsV3Expect(fixture);
    final design = _design(fixture);
    for (final id in <String>[
      'el-survey-nps',
      'el-survey-csat',
      'el-survey-ces',
      'el-survey-unknown',
    ]) {
      final element = design.element(id)!;
      final scale = (expectations[id] as Map<String, Object?>)['scale'] as List;
      expect(element.surveyScale.first, scale.first, reason: id);
      expect(element.surveyScale.last, scale.last, reason: id);
    }
    expect(design.element('el-survey-unknown')!.surveyType, 'nps');
    expect(
      design.element('el-survey-ces')!.string('surveyCampaignCode'),
      'MN TEST',
    );
    final csat = design.element('el-survey-csat')!;
    final defaults =
        (expectations['el-survey-csat'] as Map<String, Object?>)['defaults']
            as Map<String, Object?>;
    expect(_hex(csat.color('surveyScaleBg', '#000')), defaults['scaleBg']);
    expect(
      _hex(csat.color('surveyScaleActiveBg', '#000')),
      defaults['activeBg'],
    );
    expect(csat.text('surveySubmitText'), isNull);
    // Без bgColor у опроса — белая коробка компилятора.
    expect(_hex(csat.box.background), '#ffffffff');
  });

  test(
    'element-recommendation.json: the block code; a blank code is dropped',
    () {
      final fixture = popupsV3Fixture('element-recommendation.json');
      final expectations = popupsV3Expect(fixture);
      final design = _design(fixture);
      final block = design.element('el-rec')!;
      expect(
        block.recommenderCode,
        (expectations['el-rec'] as Map<String, Object?>)['code'],
      );
      // Коробка рекомендаций прозрачная, без отступов, даже если они заданы.
      expect(block.box.background.a, 0);
      expect(block.box.paddingX, 0);
      expect(design.element('el-rec-empty')!.recommenderCode, isNull);
    },
  );

  test('grid.json: fractions, alignment, order, defaults, dropped', () {
    final fixture = popupsV3Fixture('grid.json');
    final expectations = popupsV3Expect(fixture);
    final design = _design(fixture);
    final rows = expectations['rows'] as Map<String, Object?>;
    for (final row in design.rows) {
      final expected = rows[row.id] as Map<String, Object?>;
      final fractions = (expected['fractions'] as List).cast<num>();
      expect(row.fractions.length, fractions.length, reason: row.id);
      for (final (index, fraction) in row.fractions.indexed) {
        expect(fraction, closeTo(fractions[index], 0.0001), reason: row.id);
      }
      expect(row.gap, expected['gap'], reason: row.id);
      expect(row.minHeight, expected['minHeight'], reason: row.id);
      final cells = expected['cells'];
      if (cells is List) {
        for (final (index, cell) in row.cells.indexed) {
          final expectedCell = cells[index] as Map<String, Object?>;
          expect(
            cell.align.name,
            expectedCell['align'],
            reason: '${row.id}[$index]',
          );
          expect(
            cell.verticalAlign.name,
            expectedCell['verticalAlign'],
            reason: '${row.id}[$index]',
          );
          expect(
            cell.elements.map((element) => element.id).toList(),
            expectedCell['elements'],
            reason: '${row.id}[$index]',
          );
        }
      }
    }
    final rowC = design.rows.firstWhere((row) => row.id == 'row-c');
    final background =
        (rows['row-c'] as Map<String, Object?>)['background']
            as Map<String, Object?>;
    expect(_hex(rowC.background!), background['color']);
    expect(rowC.backgroundImage, background['image']);
    expect(rowC.backgroundSize, background['size']);
    expect(rowC.backgroundPosition, background['position']);
    expect(rowC.backgroundRepeat, background['repeat']);
    expect(
      design.element('c1')!.alignIn(rowC.cells[1].align),
      PopupV3Align.right,
    );
    final rowD = design.rows.firstWhere((row) => row.id == 'row-d');
    expect(rowD.cells.length, 6);
    expect(rowD.cells[5].elements.single.id, 'd5');
    expect(
      design.dropped.keys.toSet(),
      (expectations['dropped'] as List).toSet(),
    );
  });

  group('layouts.json', () {
    final fixture = popupsV3Fixture('layouts.json');
    final expectations = popupsV3Expect(fixture);
    final popups = (fixture['popups'] as List).cast<Map<String, Object?>>();
    PopupV3Design design(int id) =>
        _design(popups.firstWhere((popup) => popup['id'] == id));

    test('a top banner: no overlay, offsets, full width', () {
      final frame = design(9201).frame;
      expect(frame.overlay.enabled, isFalse);
      expect(frame.offsetX, 12);
      expect(frame.offsetY, 16);
      expect(frame.lockBackground, isFalse);
      final metrics = frame.metrics(const Size(390, 844));
      // Экран − 2×12.
      expect(metrics.resolveWidth(390 - 2 * frame.offsetX), 366);
      expect(metrics.maxWidth, isNull);
    });

    test('a bottom banner with an overlay and a locked background', () {
      final frame = design(9202).frame;
      final expected = expectations['9202'] as Map<String, Object?>;
      final overlay = expected['overlay'] as Map<String, Object?>;
      expect(frame.overlay.enabled, isTrue);
      expect(frame.overlay.color.a, closeTo(overlay['opacity'] as num, 0.01));
      expect(frame.lockBackground, isTrue);
      expect(frame.offsetX, 0);
    });

    test('a modal: the overlay by default, min height, frame', () {
      final frame = design(9203).frame;
      expect(frame.overlay.enabled, isTrue);
      expect(cssColorHex(frame.overlay.color), '#00000080');
      final metrics = frame.metrics(const Size(390, 844));
      expect(metrics.resolveWidth(390), closeTo(358.8, 0.01));
      expect(metrics.minHeight, 200);
      expect(metrics.radius, 16);
      expect(metrics.padding, 20);
      expect(frame.borderWidth, 1);
      expect(cssColorHex(frame.borderColor), '#e5e7ebff');
    });

    test('fullscreen: no overlay', () {
      final frame = design(9204).frame;
      expect(frame.overlay.enabled, isFalse);
      expect(cssColorHex(frame.background), '#0f172aff');
    });
  });

  test('breakpoints.json: the frame on screens 390, 414 and 800', () {
    final fixture = popupsV3Fixture('breakpoints.json');
    final expectations = popupsV3Expect(fixture);
    final frame = _design(fixture).frame;
    for (final width in <int>[390, 414, 800]) {
      final expected = expectations['screen_$width'] as Map<String, Object?>;
      final metrics = frame.metrics(Size(width.toDouble(), 800));
      expect(
        metrics.resolveWidth(width.toDouble()),
        closeTo(expected['width'] as num, 0.01),
        reason: 'screen $width',
      );
      if (expected.containsKey('maxWidth')) {
        expect(metrics.maxWidth, expected['maxWidth'], reason: 'screen $width');
      }
      expect(metrics.padding, expected['padding'], reason: 'screen $width');
      expect(metrics.radius, expected['borderRadius'], reason: 'screen $width');
      if (expected.containsKey('minHeight')) {
        expect(
          metrics.minHeight,
          expected['minHeight'],
          reason: 'screen $width',
        );
      }
    }
  });

  test('variables.json: static, runtime and unknown keys', () {
    final fixture = popupsV3Fixture('variables.json');
    final expectations = popupsV3Expect(fixture);
    final design = _design(fixture);
    final statics = Map<String, Object?>.from(
      expectations['static_variables'] as Map<String, Object?>,
    )..remove('promo_code');
    expect(design.variables.statics, statics);
    final text = design.element('t')!.string('message');
    expect(design.variables.applyStatic(text), expectations['t_after_static']);
    final withCode = PopupV3Variables(
      statics: design.variables.statics,
      runtime: const <String, String>{'promo_code': 'ABC123'},
    );
    expect(withCode.apply(text), expectations['t_at_show_with_code_ABC123']);
    expect(
      design.element('b')!.buttonHref(design.variables),
      expectations['b_href'],
    );
    expect(
      popupV3ImageUrl(design.element('i')!.text('imageUrl'), design.variables),
      expectations['i_url'],
    );
    expect(
      design.variables.apply(design.element('e')!.string('emailPlaceholder')),
      expectations['e_placeholder'],
    );
  });

  test(
    'unknown-element.json: unknown types are skipped, a bad style is empty',
    () {
      final fixture = popupsV3Fixture('unknown-element.json');
      final expectations = popupsV3Expect(fixture);
      final design = _design(fixture);
      expect(
        design.elements.map((element) => element.id).toList(),
        expectations['rendered'],
      );
      expect(design.dropped.keys.toSet(), <String>{
        'wheel',
        'countdown',
        'no-type',
      });
      expect(design.element('bad-style')!.style, isEmpty);
    },
  );

  test('legacy-free-elements.json: in the flow by y, then x', () {
    final fixture = popupsV3Fixture('legacy-free-elements.json');
    final design = _design(fixture);
    expect(
      design.elements.map((element) => element.id).toList(),
      popupsV3Expect(fixture)['order'],
    );
  });

  test('empty-design.json: the empty frame, nothing to show', () {
    final fixture = popupsV3Fixture('empty-design.json');
    final design = _design(fixture);
    expect(design.isEmpty, isTrue);
    final metrics = design.frame.metrics(const Size(1000, 800));
    expect(metrics.resolveWidth(1000), 480);
    expect(metrics.height, isNull);
    expect(cssColorHex(design.frame.background), '#ffffffff');
    expect(metrics.radius, 16);
    expect(metrics.padding, 20);
  });

  test('live-list-181-182.json: both designs parse whole', () {
    final fixture = popupsV3Fixture('live-list-181-182.json');
    final popups =
        ((fixture['payload'] as Map<String, Object?>)['popups'] as List)
            .cast<Map<String, Object?>>();
    final banner = _design(popups.first);
    expect(banner.dropped, isEmpty);
    expect(banner.elements.map((element) => element.type).toList(), <String>[
      'close',
      'text',
      'button',
      'image',
      'emailCollector',
      'survey',
    ]);
    expect(banner.rows.single.minHeight, 60);
    expect(banner.frame.overlay.enabled, isFalse);
    final modal = _design(popups.last);
    expect(modal.elements.map((element) => element.type).toList(), <String>[
      'promoCode',
      'survey',
      'recommendation',
    ]);
    expect(
      modal.element('el-mw0k6x8f-r')!.promoCode(modal.variables),
      'Fix Test',
    );
    expect(modal.frame.overlay.enabled, isTrue);
  });
}
