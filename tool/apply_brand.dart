import 'dart:io';

/// Applies brand-specific package metadata changes.
///
/// Usage:
/// - BRAND=rees46 dart run tool/apply_brand.dart
/// - BRAND=personaclick dart run tool/apply_brand.dart
/// - BRAND=personalization dart run tool/apply_brand.dart
///
/// Defaults to BRAND=personalization.
void main(List<String> args) {
  final brand = (Platform.environment['BRAND'] ?? 'personalization').trim();
  final targetPackageName = switch (brand.toLowerCase()) {
    'rees46' => 'rees46_flutter_sdk',
    'personaclick' => 'personaclick_flutter_sdk',
    'personalization' => 'personalization_flutter_sdk',
    _ => _fail(
      'Unknown BRAND="$brand". Use: personalization | rees46 | personaclick',
    ),
  };
  final wrapperEntry = switch (brand.toLowerCase()) {
    'rees46' => _WrapperEntry(
      fileName: 'lib/rees46_flutter_sdk.dart',
      className: 'Rees46FlutterSdk',
      configAlias: 'Rees46InitConfig',
      otherWrapperToDelete: 'lib/personaclick_flutter_sdk.dart',
    ),
    'personaclick' => _WrapperEntry(
      fileName: 'lib/personaclick_flutter_sdk.dart',
      className: 'PersonaclickFlutterSdk',
      configAlias: 'PersonaclickInitConfig',
      otherWrapperToDelete: 'lib/rees46_flutter_sdk.dart',
    ),
    // For internal/default package keep both wrappers present.
    'personalization' => null,
    _ => null,
  };

  _patchPubspecName(path: File('pubspec.yaml'), newName: targetPackageName);

  _patchExamplePubspecDependency(
    path: File('example/pubspec.yaml'),
    oldNames: const [
      'rees46_flutter_sdk',
      'personaclick_flutter_sdk',
      'personalization_flutter_sdk',
    ],
    newName: targetPackageName,
  );

  _patchDartImports(
    root: Directory('.'),
    oldNames: const [
      'rees46_flutter_sdk',
      'personaclick_flutter_sdk',
      'personalization_flutter_sdk',
    ],
    newName: targetPackageName,
  );

  if (wrapperEntry != null) {
    _generateWrapper(wrapperEntry);
    _deleteIfExists(wrapperEntry.otherWrapperToDelete);
    _patchExampleMainImport(
      path: File('example/lib/main.dart'),
      packageName: targetPackageName,
      wrapperFileBasename: wrapperEntry.fileName.split('/').last,
    );
    _patchIntegrationTestImport(
      path: File('example/integration_test/plugin_integration_test.dart'),
      packageName: targetPackageName,
      wrapperFileBasename: wrapperEntry.fileName.split('/').last,
      wrapperClassName: wrapperEntry.className,
    );
    _patchReadmeImport(
      path: File('README.md'),
      packageName: targetPackageName,
      wrapperFileBasename: wrapperEntry.fileName.split('/').last,
    );
  }

  stdout.writeln('Applied BRAND="$brand" -> name: $targetPackageName');
}

Never _fail(String message) {
  stderr.writeln(message);
  exitCode = 2;
  throw StateError(message);
}

void _patchPubspecName({required File path, required String newName}) {
  final content = path.readAsStringSync();
  final replaced = content.replaceFirstMapped(
    RegExp(r'^name:\s*(.+)\s*$', multiLine: true),
    (_) => 'name: $newName',
  );
  path.writeAsStringSync(replaced);
}

void _patchExamplePubspecDependency({
  required File path,
  required List<String> oldNames,
  required String newName,
}) {
  var content = path.readAsStringSync();

  // Replace dependency key under "dependencies:".
  for (final old in oldNames) {
    content = content.replaceAll(
      RegExp('^\\s{2}$old:\\s*\$', multiLine: true),
      '  $newName:',
    );
  }

  // Replace occurrences in description text.
  for (final old in oldNames) {
    content = content.replaceAll(old, newName);
  }

  path.writeAsStringSync(content);
}

void _patchDartImports({
  required Directory root,
  required List<String> oldNames,
  required String newName,
}) {
  final files = root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where(
        (f) => !f.path.contains(
          '${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}',
        ),
      )
      .where(
        (f) => !f.path.contains(
          '${Platform.pathSeparator}build${Platform.pathSeparator}',
        ),
      )
      .toList();

  for (final file in files) {
    var content = file.readAsStringSync();
    for (final old in oldNames) {
      content = content.replaceAll('package:$old/', 'package:$newName/');
    }
    file.writeAsStringSync(content);
  }
}

class _WrapperEntry {
  final String fileName;
  final String className;
  final String configAlias;
  final String otherWrapperToDelete;

  const _WrapperEntry({
    required this.fileName,
    required this.className,
    required this.configAlias,
    required this.otherWrapperToDelete,
  });
}

void _generateWrapper(_WrapperEntry entry) {
  final file = File(entry.fileName);
  file.writeAsStringSync('''
import 'src/personalization_sdk.dart';
import 'src/sdk_init_config.dart';

export 'src/sdk_init_config.dart' show SdkInitConfig;
export 'src/tracking/purchase_line_item.dart' show PurchaseLineItem;

typedef ${entry.configAlias} = SdkInitConfig;

class ${entry.className} extends PersonalizationSdk {}
''');
}

void _deleteIfExists(String path) {
  final file = File(path);
  if (file.existsSync()) {
    file.deleteSync();
  }
}

void _patchExampleMainImport({
  required File path,
  required String packageName,
  required String wrapperFileBasename,
}) {
  var content = path.readAsStringSync();
  // Replace any import of package:<pkg>/<something>_flutter_sdk.dart
  content = content.replaceAll(
    RegExp(r"import 'package:[^/]+/[^']+_flutter_sdk\.dart';"),
    "import 'package:$packageName/$wrapperFileBasename';",
  );
  path.writeAsStringSync(content);
}

void _patchIntegrationTestImport({
  required File path,
  required String packageName,
  required String wrapperFileBasename,
  required String wrapperClassName,
}) {
  var content = path.readAsStringSync();
  content = content.replaceAll(
    RegExp(r"import 'package:[^/]+/[^']+_flutter_sdk\.dart';"),
    "import 'package:$packageName/$wrapperFileBasename';",
  );
  // Also patch the class usage line if needed.
  content = content.replaceAll(
    RegExp(r'final\s+\w+\s+plugin\s*=\s*\w+\(\);'),
    'final $wrapperClassName plugin = $wrapperClassName();',
  );
  path.writeAsStringSync(content);
}

void _patchReadmeImport({
  required File path,
  required String packageName,
  required String wrapperFileBasename,
}) {
  var content = path.readAsStringSync();
  content = content.replaceAll(
    RegExp(r"import 'package:[^/]+/[^']+_flutter_sdk\.dart';"),
    "import 'package:$packageName/$wrapperFileBasename';",
  );
  path.writeAsStringSync(content);
}
