import 'package:flutter/material.dart';

/// Colour scheme the demo forces on itself, so the kit's dark set can be checked
/// without leaving for the system settings.
///
/// A plain [ValueNotifier] rather than a state manager: the example has no
/// dependency injection and the kit does not ask for one either — [MaterialApp]
/// listens to this, and the UI Kit screen's switch writes to it.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier<ThemeMode>(
  ThemeMode.system,
);

/// Cycles system -> light -> dark -> system.
ThemeMode nextThemeMode(ThemeMode mode) => switch (mode) {
  ThemeMode.system => ThemeMode.light,
  ThemeMode.light => ThemeMode.dark,
  ThemeMode.dark => ThemeMode.system,
};

/// Label of the switch: the mode it is in now, not the one it would go to.
String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'Auto',
  ThemeMode.light => 'Light',
  ThemeMode.dark => 'Dark',
};
