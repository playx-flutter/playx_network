import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/src/utils/extensions.dart';

void main() {
  group('PlayxNetworkNullableStringExtensions', () {
    group('isNullOrBlank', () {
      test('returns true for null', () {
        const String? value = null;
        expect(value.isNullOrBlank, isTrue);
      });

      test('returns true for empty string', () {
        const String value = '';
        expect(value.isNullOrBlank, isTrue);
      });

      test('returns true for whitespace-only string (spaces)', () {
        const String value = '   ';
        expect(value.isNullOrBlank, isTrue);
      });

      test('returns true for whitespace-only string (tabs and newlines)', () {
        const String value = '\t\n\r';
        expect(value.isNullOrBlank, isTrue);
      });

      test('returns false for non-blank string', () {
        const String value = 'hello';
        expect(value.isNullOrBlank, isFalse);
      });

      test(
          'returns false for string that has content with surrounding whitespace',
          () {
        const String value = '  hello  ';
        expect(value.isNullOrBlank, isFalse);
      });
    });

    group('isNotNullOrBlank', () {
      test('returns false for null', () {
        const String? value = null;
        expect(value.isNotNullOrBlank, isFalse);
      });

      test('returns false for empty string', () {
        const String value = '';
        expect(value.isNotNullOrBlank, isFalse);
      });

      test('returns false for whitespace-only string', () {
        const String value = '   ';
        expect(value.isNotNullOrBlank, isFalse);
      });

      test('returns true for non-blank string', () {
        const String value = 'hello';
        expect(value.isNotNullOrBlank, isTrue);
      });

      test('returns true for string with surrounding whitespace', () {
        const String value = '  hello  ';
        expect(value.isNotNullOrBlank, isTrue);
      });
    });

    group('nullIfEmpty', () {
      test('returns null for null', () {
        const String? value = null;
        expect(value.nullIfEmpty, isNull);
      });

      test('returns null for empty string', () {
        const String value = '';
        expect(value.nullIfEmpty, isNull);
      });

      test('preserves whitespace-only string', () {
        const String value = '   ';
        expect(value.nullIfEmpty, equals('   '));
      });

      test('returns the string for non-empty value', () {
        const String value = 'hello';
        expect(value.nullIfEmpty, equals('hello'));
      });

      test('preserves surrounding whitespace in non-empty string', () {
        const String value = '  hello  ';
        expect(value.nullIfEmpty, equals('  hello  '));
      });
    });

    group('nullIfBlank', () {
      test('returns null for null', () {
        const String? value = null;
        expect(value.nullIfBlank, isNull);
      });

      test('returns null for empty string', () {
        const String value = '';
        expect(value.nullIfBlank, isNull);
      });

      test('returns null for whitespace-only string (spaces)', () {
        const String value = '   ';
        expect(value.nullIfBlank, isNull);
      });

      test('returns null for whitespace-only string (tabs and newlines)', () {
        const String value = '\t\n\r';
        expect(value.nullIfBlank, isNull);
      });

      test('returns the string for non-blank value', () {
        const String value = 'hello';
        expect(value.nullIfBlank, equals('hello'));
      });

      test('preserves surrounding whitespace in non-blank string', () {
        const String value = '  hello  ';
        expect(value.nullIfBlank, equals('  hello  '));
      });
    });

    group('orIfNullOrEmpty', () {
      test('returns fallback for null', () {
        const String? value = null;
        expect(value.orIfNullOrEmpty('N/A'), equals('N/A'));
      });

      test('returns fallback for empty string', () {
        const String value = '';
        expect(value.orIfNullOrEmpty('N/A'), equals('N/A'));
      });

      test('preserves whitespace-only string', () {
        const String value = '   ';
        expect(value.orIfNullOrEmpty('N/A'), equals('   '));
      });

      test('returns the string for non-empty value', () {
        const String value = 'hello';
        expect(value.orIfNullOrEmpty('N/A'), equals('hello'));
      });

      test('preserves surrounding whitespace in non-empty string', () {
        const String value = '  hello  ';
        expect(value.orIfNullOrEmpty('N/A'), equals('  hello  '));
      });
    });

    group('orIfNullOrBlank', () {
      test('returns fallback for null', () {
        const String? value = null;
        expect(value.orIfNullOrBlank('N/A'), equals('N/A'));
      });

      test('returns fallback for empty string', () {
        const String value = '';
        expect(value.orIfNullOrBlank('N/A'), equals('N/A'));
      });

      test('returns fallback for whitespace-only string (spaces)', () {
        const String value = '   ';
        expect(value.orIfNullOrBlank('N/A'), equals('N/A'));
      });

      test('returns fallback for whitespace-only string (tabs and newlines)',
          () {
        const String value = '\t\n\r';
        expect(value.orIfNullOrBlank('N/A'), equals('N/A'));
      });

      test('returns the string for non-blank value', () {
        const String value = 'hello';
        expect(value.orIfNullOrBlank('N/A'), equals('hello'));
      });

      test('preserves surrounding whitespace in non-blank string', () {
        const String value = '  hello  ';
        expect(value.orIfNullOrBlank('N/A'), equals('  hello  '));
      });
    });

    group('consistency between helpers', () {
      test('isNullOrBlank is the negation of isNotNullOrBlank', () {
        const cases = <String?>[null, '', '   ', '\t\n', 'hello', '  x  '];
        for (final value in cases) {
          expect(
            value.isNullOrBlank,
            equals(!value.isNotNullOrBlank),
            reason: 'isNullOrBlank should be negation of isNotNullOrBlank '
                'for "$value"',
          );
        }
      });

      test('nullIfBlank converts all orIfNullOrBlank-fallback cases to null',
          () {
        const blankCases = <String?>[null, '', '   ', '\t\n\r'];
        for (final value in blankCases) {
          expect(
            value.nullIfBlank,
            isNull,
            reason: 'nullIfBlank should be null for "$value"',
          );
          expect(
            value.orIfNullOrBlank('fallback'),
            equals('fallback'),
            reason: 'orIfNullOrBlank should return fallback for "$value"',
          );
        }
      });

      test('nullIfEmpty is stricter than nullIfBlank', () {
        const String whitespace = '   ';
        // nullIfEmpty preserves whitespace, nullIfBlank converts to null.
        expect(whitespace.nullIfEmpty, equals('   '));
        expect(whitespace.nullIfBlank, isNull);
      });

      test('orIfNullOrEmpty is stricter than orIfNullOrBlank', () {
        const String whitespace = '   ';
        // orIfNullOrEmpty preserves whitespace, orIfNullOrBlank returns fallback.
        expect(whitespace.orIfNullOrEmpty('fallback'), equals('   '));
        expect(whitespace.orIfNullOrBlank('fallback'), equals('fallback'));
      });
    });
  });
}
