import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/popups_v3/popup_v3_values.dart';
import 'package:rees46_sdk/src/ui/popups_v3/css_color.dart';
import 'package:rees46_sdk/src/ui/popups_v3/popup_markup.dart';

import 'fixtures.dart';

Map<String, Object> _span(PopupMarkupSpan span) => <String, Object>{
  'text': span.text,
  if (span.bold) 'bold': true,
  if (span.italic) 'italic': true,
  if (span.underline) 'underline': true,
  if (span.strike) 'strike': true,
  if (span.overline) 'overline': true,
};

void main() {
  final parsing = popupsV3Fixture('parsing.json');

  group('parsing.json', () {
    test('colors: CSS → #rrggbbaa or nothing', () {
      for (final vector in parsing['colors'] as List) {
        final item = vector as Map<String, Object?>;
        final color = parseCssColor(item['in']);
        expect(
          color == null ? null : cssColorHex(color),
          item['out'],
          reason: 'in: ${item['in']}',
        );
      }
    });

    test('numbers: a number, a string with a number or the fallback', () {
      for (final vector in parsing['numbers'] as List) {
        final item = vector as Map<String, Object?>;
        expect(
          cssNum(item['in'], (item['fallback'] as num).toDouble()),
          (item['out'] as num).toDouble(),
          reason: 'in: ${item['in']}',
        );
      }
    });

    test('booleans', () {
      for (final vector in parsing['booleans'] as List) {
        final item = vector as Map<String, Object?>;
        expect(cssBool(item['in']), item['out'], reason: 'in: ${item['in']}');
      }
    });
  });

  group('markup.json', () {
    final markup = popupsV3Fixture('markup.json');
    final cases =
        (markup['_fixture'] as Map<String, Object?>)['expect'] as List;

    test('left to right, no nesting, HTML stays text', () {
      for (final item in cases.cast<Map<String, Object?>>()) {
        expect(
          parsePopupMarkup(item['input'] as String).map(_span).toList(),
          item['spans'],
          reason: 'input: ${item['input']}',
        );
      }
    });

    test('the spans become a text span with the base style', () {
      final span = popupMarkupTextSpan(
        parsePopupMarkup('**a** __b__ ~~c~~ ^^d^^ *e*'),
        const TextStyle(fontSize: 14),
      );
      final children = span.children!.cast<TextSpan>();
      expect(span.style!.fontSize, 14);
      expect(children.first.style!.fontWeight, FontWeight.w700);
      expect(children[2].style!.decoration, TextDecoration.underline);
      expect(children[4].style!.decoration, TextDecoration.lineThrough);
      expect(children[6].style!.decoration, TextDecoration.overline);
      expect(children[8].style!.fontStyle, FontStyle.italic);
    });
  });

  group('values', () {
    test('presence: blank strings and non-strings are missing', () {
      expect(cssPresent('  '), isNull);
      expect(cssPresent(''), isNull);
      expect(cssPresent(null), isNull);
      expect(cssPresent(' a '), ' a ');
      expect(cssPresent(7), '7');
      expect(cssPresent(7.5), '7.5');
    });

    test('rgb with percents and out-of-range channels', () {
      expect(cssColorHex(parseCssColor('rgb(100%, 0%, 50%)')!), '#ff0080ff');
      expect(cssColorHex(parseCssColor('rgba(300, -5, 0, 2)')!), '#ff0000ff');
      expect(parseCssColor('rgb(1, 2)'), isNull);
      expect(parseCssColor('#12345'), isNull);
    });
  });
}
