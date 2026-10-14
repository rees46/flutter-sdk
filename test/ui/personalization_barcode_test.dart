import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The encoder is internal to the barcode and stays out of the kit barrel.
import 'package:rees46_sdk/src/ui/components/personalization_code128.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

String _bits(List<bool> modules) =>
    modules.map((bar) => bar ? '1' : '0').join();

Widget _host(Widget child) => MaterialApp(
  home: Align(alignment: Alignment.topLeft, child: child),
);

void main() {
  group('Code 128 encoder', () {
    test('letters and digits go to set B', () {
      final values = PersonalizationCode128.values('PJJ123C')!;
      // Start B, the data, then the checksum.
      expect(values, <int>[104, 48, 42, 42, 17, 18, 19, 35, 55]);
      expect(PersonalizationCode128.checksum(values.sublist(0, 8)), 55);

      final bits = _bits(PersonalizationCode128.encode('PJJ123C')!);
      expect(bits, hasLength(112));
      expect(bits.substring(0, 11), '11010010000');
      expect(bits.substring(bits.length - 13), '1100011101011');
    });

    test('an even run of digits goes to set C in pairs', () {
      expect(PersonalizationCode128.values('1234'), <int>[105, 12, 34, 82]);

      final bits = _bits(PersonalizationCode128.encode('1234')!);
      expect(bits, hasLength(57));
      expect(bits.substring(0, 11), '11010011100');
      expect(bits.substring(bits.length - 13), '1100011101011');
    });

    test('an odd run of digits ends in set B through CODE B', () {
      expect(PersonalizationCode128.values('123'), <int>[105, 12, 100, 19, 65]);
      expect(PersonalizationCode128.encode('123'), hasLength(68));
    });

    test('a single digit is not worth set C', () {
      expect(PersonalizationCode128.values('7')!.first, 104);
    });

    test('empty or non-ASCII input is not encodable', () {
      expect(PersonalizationCode128.values(''), isNull);
      expect(PersonalizationCode128.encode(''), isNull);
      expect(PersonalizationCode128.encode('é'), isNull);
      expect(PersonalizationCode128.encode('tab\there'), isNull);
    });
  });

  group('PersonalizationBarcode', () {
    testWidgets('the module is a whole number of physical pixels', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      // 112 modules into 232: 6 px at 3x, 4 px at 2x, 5 px at 2.625x.
      const cases = <(double, double)>[(3, 6), (2, 4), (2.625, 5)];
      for (final (dpr, pixels) in cases) {
        tester.view.devicePixelRatio = dpr;
        await tester.pumpWidget(
          _host(const PersonalizationBarcode(code: 'PJJ123C')),
        );

        final size = tester.getSize(find.byType(PersonalizationBarcode));
        expect(size.width, closeTo(112 * pixels / dpr, 1e-9), reason: '$dpr');
        expect(size.height, 42, reason: '$dpr');
      }
    });

    testWidgets('a narrower slot gets a smaller whole module', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 3;
      await tester.pumpWidget(
        _host(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: const PersonalizationBarcode(code: 'PJJ123C'),
          ),
        ),
      );

      // floor(120 * 3 / 112) = 3 px — one logical unit per module.
      expect(tester.getSize(find.byType(PersonalizationBarcode)).width, 112);
    });

    testWidgets('an unencodable code takes no space', (tester) async {
      for (final code in <String>['', 'é']) {
        await tester.pumpWidget(_host(PersonalizationBarcode(code: code)));

        expect(
          tester.getSize(find.byType(PersonalizationBarcode)),
          Size.zero,
          reason: code,
        );
      }
    });

    testWidgets('a screen reader reads the code', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const PersonalizationBarcode(code: '2000012345678')),
      );

      expect(find.bySemanticsLabel('2000012345678'), findsOneWidget);
      semantics.dispose();
    });
  });
}
