// The v3 gate: popups of the new builder and stories over API v3 are reachable only
// through `src/v3/personalization_v3.dart` — not from the package barrel and not from
// the kit barrel it exports.
//
// Dart has no reflection in Flutter tests, so the export namespaces are read from the
// sources: export directives with their show/hide, parts, and the public top-level
// declarations of each file (dart format puts those at column 0).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _root = 'lib/rees46_sdk.dart';
const String _kit = 'lib/src/ui/personalization_ui.dart';
const String _v3 = 'lib/src/v3/personalization_v3.dart';

/// What the v3 gate gives the demo.
const Set<String> _v3Names = <String>{
  'PopupsV3',
  'PersonalizationPopupsV3',
  'PersonalizationScreenObserver',
  'PersonalizationStoriesV3',
  'StoryShareV3',
  'StorySlideShareV3',
  'StoryPollType',
  'StoryMiniPollKind',
  'StoryPollOption',
  'StoryPollBand',
  'StoryPollAnswer',
  'StoryPollResults',
  'StoryPollLabels',
  'StoryPollElement',
  'StoryPollsTransport',
  'StoryPollReply',
};

/// v3 internals no barrel exports.
const Set<String> _internal = <String>{
  'StoriesV3Scope',
  'StoriesV3Options',
  'StoriesApiV3',
  'StoriesPollsApi',
  'PopupsV3Engine',
  'PopupsV3Hooks',
};

/// Members and parameters of v3 that kit classes must not carry.
const Set<String> _v3Members = <String>{
  'apiV3Domain',
  'ownApiV3Domain',
  'pollsTransport',
  'shareUrlTransform',
  'handleLink',
  'pollReanswerText',
  'pollSubmitText',
  'pollErrorText',
  'shareLabel',
  'shareUrl',
  'shareable',
  'popups',
};

final RegExp _export = RegExp(r"^export\s+'([^']+)'([^;]*);", multiLine: true);
final RegExp _part = RegExp(r"^part\s+'([^']+)';", multiLine: true);
final RegExp _combinator = RegExp(
  r'\b(show|hide)\b([^]*?)(?=\b(?:show|hide)\b|$)',
);
final RegExp _type = RegExp(
  r'^(?:(?:abstract|sealed|final|base|interface|mixin)\s+)*'
  r'(?:class|enum|mixin|typedef|extension(?:\s+type)?)\s+([A-Za-z]\w*)',
  multiLine: true,
);
final RegExp _function = RegExp(
  r'^(?!(?:import|export|part|library|class|enum|mixin|typedef|extension|abstract|'
  r'sealed|final|base|interface)\b)[A-Za-z][\w<>?, ]*[ \t]+(?:get[ \t]+)?'
  r'([A-Za-z]\w*)[ \t]*[(=]',
  multiLine: true,
);
final RegExp _variable = RegExp(
  r'^(?:const|final|var|late)[ \t]+(?:[\w<>?, ]+[ \t]+)?([A-Za-z]\w*)[ \t]*[=;]',
  multiLine: true,
);

String _resolve(String from, String uri) {
  if (uri.startsWith('package:rees46_sdk/')) {
    return 'lib/${uri.substring('package:rees46_sdk/'.length)}';
  }
  return File(from).parent.uri
      .resolve(uri)
      .toFilePath()
      .replaceFirst('${Directory.current.path}/', '');
}

/// Public top-level names [file] and its parts declare.
Set<String> _declared(String file) {
  final source = File(file).readAsStringSync();
  return <String>{
    for (final pattern in <RegExp>[_type, _function, _variable])
      for (final match in pattern.allMatches(source)) match.group(1)!,
    for (final part in _part.allMatches(source))
      ..._declared(_resolve(file, part.group(1)!)),
  };
}

/// The export namespace of the library [file].
Set<String> _namespace(String file) {
  final source = File(file).readAsStringSync();
  final names = _declared(file);
  for (final export in _export.allMatches(source)) {
    final uri = export.group(1)!;
    if (uri.startsWith('dart:') ||
        (uri.startsWith('package:') &&
            !uri.startsWith('package:rees46_sdk/'))) {
      continue;
    }
    var exported = _namespace(_resolve(file, uri));
    for (final combinator in _combinator.allMatches(export.group(2)!)) {
      final listed = combinator
          .group(2)!
          .split(',')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet();
      exported = combinator.group(1) == 'show'
          ? exported.intersection(listed)
          : exported.difference(listed);
    }
    names.addAll(exported);
  }
  return names;
}

/// Files reachable through the export directives of [file].
Set<String> _exportedFiles(String file) {
  final source = File(file).readAsStringSync();
  return <String>{
    file,
    for (final export in _export.allMatches(source))
      if (!export.group(1)!.startsWith('dart:'))
        ..._exportedFiles(_resolve(file, export.group(1)!)),
  };
}

/// Names the top-level class [name] in [file] declares: its members (two spaces in)
/// and the parameters of their signatures (four spaces in, one per line), comments and
/// bodies left out.
Set<String> _declaredIn(String file, String name) {
  final source = File(file).readAsStringSync();
  final start = RegExp(
    r'^(?:(?:abstract|sealed|final|base|interface)\s+)*class\s+' + name + r'\b',
    multiLine: true,
  ).firstMatch(source);
  expect(start, isNotNull, reason: '$name in $file');
  final body = source.substring(
    start!.start,
    source.indexOf('\n}\n', start.start),
  );
  final member = RegExp(
    r'^  (?:(?:static|final|const|late|factory)\s+)*(?:[\w<>?, ()]*?\s)?'
    r'(?:get\s+|set\s+)?(\w+)\s*(?:=>|=|;|\(|\{)',
  );
  final parameter = RegExp(
    r'^    (?:required\s+)?(?:(?:this|super)\.(\w+)|[A-Za-z][\w<>?, ()]*\s(\w+))'
    r'(?:\s*=\s*[^,]+)?,$',
  );
  return <String>{
    for (final line in body.split('\n'))
      if (!line.trimLeft().startsWith('//'))
        for (final pattern in <RegExp>[member, parameter])
          for (final match in pattern.allMatches(line))
            match.group(1) ?? match.group(2)!,
  };
}

void main() {
  test('the reader sees the kit, the root and the gate', () {
    final kit = _namespace(_kit);
    expect(
      kit,
      containsAll(<String>[
        'PersonalizationStories',
        'PersonalizationStoriesController',
        'PersonalizationStoryViewer',
        'Story',
        'StorySlide',
        'StoryElement',
        'PersonalizationButton',
      ]),
    );
    expect(
      _namespace(_root),
      containsAll(<String>['REES46', 'PersonalizationSdk']),
    );
  });

  test('neither the package barrel nor the kit barrel exports v3', () {
    for (final barrel in <String>[_root, _kit]) {
      final names = _namespace(barrel);
      expect(names.intersection(_v3Names), isEmpty, reason: barrel);
      expect(names.intersection(_internal), isEmpty, reason: barrel);
      expect(
        names.where((name) => name.contains('V3')),
        isEmpty,
        reason: barrel,
      );
      expect(
        _exportedFiles(barrel).where((file) => file.contains('popups_v3')),
        isEmpty,
        reason: barrel,
      );
    }
  });

  test('the v3 gate exports v3 and no internals', () {
    final names = _namespace(_v3);
    expect(names, containsAll(_v3Names));
    expect(names.intersection(_internal), isEmpty);
  });

  test('kit classes carry no v3 members', () {
    const classes = <(String, String)>[
      (
        'lib/src/ui/widgets/personalization_stories.dart',
        'PersonalizationStories',
      ),
      (
        'lib/src/ui/widgets/personalization_story_viewer.dart',
        'PersonalizationStoryViewer',
      ),
      ('lib/src/stories/stories_response.dart', 'Story'),
      ('lib/src/stories/stories_response.dart', 'StorySlide'),
      ('lib/src/personalization_sdk.dart', 'PersonalizationSdk'),
    ];
    for (final (file, name) in classes) {
      final declared = _declaredIn(file, name);
      expect(declared, isNotEmpty, reason: name);
      expect(declared.intersection(_v3Members), isEmpty, reason: name);
    }
  });

  test('the docs of the package barrel do not mention v3', () {
    for (final file in _exportedFiles(_root)) {
      final lines = File(file).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (!line.startsWith('///')) continue;
        expect(
          RegExp(r'\bv3\b', caseSensitive: false).hasMatch(line),
          isFalse,
          reason: '$file:${i + 1}: $line',
        );
      }
    }
  });
}
