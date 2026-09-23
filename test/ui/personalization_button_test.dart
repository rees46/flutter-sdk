import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

Widget _host(Widget child) => MaterialApp(home: Center(child: child));

BorderRadiusGeometry? _radius(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(PersonalizationButton),
      matching: find.byType(Container),
    ),
  );
  return (container.decoration! as BoxDecoration).borderRadius;
}

void main() {
  testWidgets('a rounded icon button is a circle', (tester) async {
    await tester.pumpWidget(
      _host(
        const PersonalizationButton(
          size: PersonalizationButtonSize.md,
          view: PersonalizationButtonView.secondary,
          iconStart: PersonalizationIcons.crossLarge,
          rounded: true,
        ),
      ),
    );

    expect(
      _radius(tester),
      BorderRadius.circular(PersonalizationRadius.rounded),
    );
    final size = tester.getSize(find.byType(PersonalizationButton));
    expect(size.width, size.height);
  });

  testWidgets('without rounded the button keeps the radius of its size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const PersonalizationButton(
          size: PersonalizationButtonSize.md,
          iconStart: PersonalizationIcons.crossLarge,
        ),
      ),
    );

    expect(
      _radius(tester),
      BorderRadius.circular(PersonalizationRadius.buttonMd),
    );
  });
}
