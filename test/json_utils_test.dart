import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/src/utils/json_utils.dart';

void main() {
  group('getJsonValueOrNull', () {
    final json = {
      'data': {
        'user': {
          'name': 'Ada',
          'tags': ['a', 'b'],
        },
        'users': [
          {'name': 'first'},
          {'name': 'second'},
        ],
      },
      'a.b': 'literal dotted key',
      'nothing': null,
    };

    test('reads a top-level key', () {
      expect(getJsonValueOrNull(json, 'data'), isA<Map>());
    });

    test('reads nested keys with dot notation', () {
      expect(getJsonValueOrNull(json, 'data.user.name'), 'Ada');
    });

    test('indexes into lists with numeric segments', () {
      expect(getJsonValueOrNull(json, 'data.users.1.name'), 'second');
      expect(getJsonValueOrNull(json, 'data.user.tags.0'), 'a');
    });

    test('a literal key containing dots wins over the path', () {
      expect(getJsonValueOrNull(json, 'a.b'), 'literal dotted key');
    });

    test('returns null for missing keys and bad indexes', () {
      expect(getJsonValueOrNull(json, 'missing'), isNull);
      expect(getJsonValueOrNull(json, 'data.missing.name'), isNull);
      expect(getJsonValueOrNull(json, 'data.users.5.name'), isNull);
      expect(getJsonValueOrNull(json, 'data.users.-1.name'), isNull);
      expect(getJsonValueOrNull(json, 'data.users.x.name'), isNull);
    });

    test('returns null when walking into a scalar', () {
      expect(getJsonValueOrNull(json, 'data.user.name.first'), isNull);
    });

    test('returns null for null and non-container input', () {
      expect(getJsonValueOrNull(null, 'data'), isNull);
      expect(getJsonValueOrNull('text', 'data'), isNull);
      expect(getJsonValueOrNull(42, 'a.b'), isNull);
    });

    test('a key whose value is null is null', () {
      expect(getJsonValueOrNull(json, 'nothing'), isNull);
    });

    test('works on a list at the root', () {
      expect(getJsonValueOrNull([10, 20], '1'), isNull); // no dot: not a path
      expect(getJsonValueOrNull([10, 20], '0.x'), isNull);
    });
  });
}
