import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/models/error/message.dart';

String? _message(dynamic json) => DefaultApiError.fromJson(json).message;

void main() {
  group('DefaultApiError.fromJson', () {
    test('reads message, name and statusCode', () {
      final error = DefaultApiError.fromJson({
        'statusCode': 404,
        'name': 'NotFound',
        'message': 'No such user',
      });
      expect(error.statusCode, 404);
      expect(error.name, 'NotFound');
      expect(error.message, 'No such user');
    });

    test('reads a message-only body', () {
      expect(_message({'message': 'boom'}), 'boom');
    });

    test('joins a list of validation messages', () {
      expect(
        _message({
          'statusCode': 400,
          'message': ['name must be a string', 'age must be a number'],
          'error': 'Bad Request',
        }),
        'name must be a string\nage must be a number',
      );
    });

    test('ignores blank entries of a message list', () {
      expect(
        _message({
          'message': ['', 'only this', '  '],
        }),
        'only this',
      );
      expect(_message({'message': <String>[]}), isNull);
    });

    test('reads Strapi style nested messages', () {
      expect(
        _message({
          'statusCode': 400,
          'error': 'Bad Request',
          'message': [
            {
              'messages': [
                {
                  'id': 'Auth.form.error.invalid',
                  'message': 'Identifier invalid',
                },
              ],
            },
          ],
        }),
        'Identifier invalid',
      );
    });

    test('a Strapi list without messages has no message', () {
      expect(
        _message({
          'message': [
            {'messages': <dynamic>[]},
          ],
        }),
        isNull,
      );
      expect(
        _message({
          'message': [
            {'other': 1},
          ],
        }),
        isNull,
      );
    });

    test('falls back to a plain error string', () {
      expect(_message({'error': 'Invalid token'}), 'Invalid token');
    });

    test('falls back to a nested error object', () {
      final error = DefaultApiError.fromJson({
        'error': {'name': 'AuthError', 'message': 'Token expired'},
      });
      expect(error.message, 'Token expired');
      expect(error.name, 'AuthError');
    });

    test('message wins over error', () {
      expect(
        _message({'message': 'specific', 'error': 'Bad Request'}),
        'specific',
      );
    });

    test('a blank message falls back to error', () {
      expect(
        _message({'message': '  ', 'error': 'Bad Request'}),
        'Bad Request',
      );
    });

    test('a field with an unexpected type does not discard the rest', () {
      final error = DefaultApiError.fromJson({
        'statusCode': 'oops',
        'name': 42,
        'message': 'still readable',
      });
      expect(error.message, 'still readable');
      expect(error.statusCode, isNull);
      expect(error.name, isNull);
    });

    test('a numeric status code sent as a string is parsed', () {
      expect(DefaultApiError.fromJson({'statusCode': '422'}).statusCode, 422);
    });

    test('a non-string, non-list message is ignored', () {
      expect(_message({'message': 123}), isNull);
      expect(
        _message({
          'message': {'a': 1},
        }),
        isNull,
      );
    });

    test('accepts maps with non-string keys', () {
      expect(
        _message(<dynamic, dynamic>{'message': 'dynamic map'}),
        'dynamic map',
      );
    });

    test('anything that is not a map yields an empty error', () {
      for (final body in [
        null,
        'Internal Server Error',
        42,
        [1, 2],
        true,
      ]) {
        final error = DefaultApiError.fromJson(body);
        expect(error.message, isNull, reason: '$body');
        expect(error.name, isNull, reason: '$body');
        expect(error.statusCode, isNull, reason: '$body');
      }
    });

    test('an empty map yields an empty error', () {
      expect(DefaultApiError.fromJson(<String, dynamic>{}).message, isNull);
    });
  });

  group('the default error mapper', () {
    test('turns common bodies into the exception message', () async {
      String? viaMapper(dynamic json) =>
          json == null ? null : DefaultApiError.fromJson(json).message;
      expect(
        viaMapper({
          'message': ['a', 'b'],
        }),
        'a\nb',
      );
      expect(viaMapper(null), isNull);
    });
  });

  group('ApiMessage and Messages', () {
    test('parse the Strapi message structure', () {
      final parsed = ApiMessage.fromJson({
        'messages': [
          {'id': 'a', 'message': 'first'},
          {'id': 'b', 'message': 'second'},
        ],
      });
      expect(parsed.messages, hasLength(2));
      expect(parsed.messages!.first.id, 'a');
      expect(parsed.messages!.last.message, 'second');
    });

    test('tolerate missing or malformed data', () {
      expect(ApiMessage.fromJson({}).messages, isNull);
      expect(ApiMessage.fromJson('text').messages, isNull);
      expect(ApiMessage.fromJson({'messages': 'nope'}).messages, isNull);
      final messages = Messages.fromJson({'id': 1, 'message': 2});
      expect(messages.id, isNull);
      expect(messages.message, isNull);
      expect(Messages.fromJson('x').message, isNull);
    });

    test('Messages.toJson round-trips', () {
      final json = Messages(id: 'x', message: 'y').toJson();
      expect(json, {'id': 'x', 'message': 'y'});
      expect(Messages.fromJson(json).message, 'y');
    });

    test('constructors keep their values', () {
      expect(
        ApiMessage(messages: [Messages(id: 'i')]).messages!.single.id,
        'i',
      );
      final error = DefaultApiError(statusCode: 1, name: 'n', message: 'm');
      expect([error.statusCode, error.name, error.message], [1, 'n', 'm']);
    });
  });
}
