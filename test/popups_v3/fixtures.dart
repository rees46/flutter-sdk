import 'dart:convert';
import 'dart:io';

/// Общая фикстура попапов v3 (`test/fixtures/popups_v3/<name>`).
Map<String, Object?> popupsV3Fixture(String name) =>
    jsonDecode(File('test/fixtures/popups_v3/$name').readAsStringSync())
        as Map<String, Object?>;

/// Ожидания фикстуры (`_fixture.expect`).
Map<String, Object?> popupsV3Expect(Map<String, Object?> fixture) =>
    (fixture['_fixture'] as Map<String, Object?>)['expect']
        as Map<String, Object?>;
