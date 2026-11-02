import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

/// Dozens of facets do not push Apply off the screen: the title and the buttons
/// stay put and only the sections scroll. Inside a host's scroll the screen is
/// as tall as its content.
PersonalizationFilters _filters(int sections) => PersonalizationFilters(
  title: 'Filters',
  resetText: 'Reset',
  applyText: 'Apply',
  sections: <PersonalizationFilterSection>[
    for (int i = 1; i <= sections; i++)
      PersonalizationFilterOptions(
        id: 'facet$i',
        title: 'Facet $i',
        options: <PersonalizationFilterOption>[
          for (int j = 1; j <= 3; j++)
            PersonalizationFilterOption(id: '$i-$j', label: 'Value $i.$j'),
        ],
      ),
  ],
);

void main() {
  testWidgets(
    'with a set height the buttons stay on screen and sections scroll',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 360, height: 600, child: _filters(30)),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomLeft(find.text('Apply')).dy,
        lessThanOrEqualTo(600),
      );
      expect(tester.getTopLeft(find.text('Filters')).dy, lessThan(60));
      expect(tester.getTopLeft(find.text('Facet 30')).dy, greaterThan(600));

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -5000),
      );
      await tester.pump();
      expect(tester.getTopLeft(find.text('Facet 30')).dy, lessThan(600));
      expect(
        tester.getBottomLeft(find.text('Apply')).dy,
        lessThanOrEqualTo(600),
      );
    },
  );

  testWidgets('inside a host scroll the screen follows its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: SizedBox(width: 360, child: _filters(2)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Facet 2'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });
}
