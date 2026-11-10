import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:playx_core/playx_core.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/handler/api_handler.dart';

const _quiet = PlayxNetworkClientSettings(
  logSettings: PlayxNetworkLoggerSettings(enabled: false),
  useIsolateForMappingJson: false,
  useWorkMangerForMappingJsonInIsolate: false,
);

// Isolates can only run top-level or static functions.
int _double(dynamic json) => (json['id'] as int) * 2;
String _label(dynamic json) => 'item-${json['id']}';
int _boom(dynamic json) => throw StateError('mapper failed');

ApiHandler _handler([PlayxNetworkClientSettings settings = _quiet]) =>
    ApiHandler(
      errorMapper: (json) => json is Map ? json['message'] as String? : null,
      settings: settings,
      logger: PlayxLogger.initLogger(name: 'handler-test', setAsDefault: false),
    );

Response<dynamic> _response(dynamic data, {int status = 200}) =>
    Response<dynamic>(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: status,
      data: data,
    );

/// A response whose body cannot be read, to reach the outermost safety net.
class _BrokenResponse extends Response<dynamic> {
  _BrokenResponse() : super(requestOptions: RequestOptions(path: '/x'));

  @override
  int? get statusCode => 200;

  @override
  dynamic get data => throw StateError('body exploded');
}

const _isolateSettings = PlayxNetworkClientSettings(
  logSettings: PlayxNetworkLoggerSettings(enabled: false),
  useIsolateForMappingJson: true,
  useWorkMangerForMappingJsonInIsolate: false,
);

void main() {
  group('handleNetworkResult', () {
    test('maps a successful body', () async {
      final result = await _handler().handleNetworkResult<int>(
        response: _response({'id': 21}),
        fromJson: _double,
      );
      expect(result.data, 42);
    });

    test('supports async mappers', () async {
      final result = await _handler().handleNetworkResult<String>(
        response: _response({'id': 1}),
        fromJson: (json) async => 'async-${json['id']}',
      );
      expect(result.data, 'async-1');
    });

    test('extracts nested data with dataKey', () async {
      final result = await _handler().handleNetworkResult<int>(
        response: _response({
          'payload': {
            'user': {'id': 5},
          },
        }),
        fromJson: _double,
        dataKey: 'payload.user',
      );
      expect(result.data, 10);
    });

    test('a missing dataKey hands null to the mapper', () async {
      Object? received = 'unset';
      final result = await _handler().handleNetworkResult<String>(
        response: _response({'other': 1}),
        fromJson: (json) {
          received = json;
          return 'ok';
        },
        dataKey: 'data',
      );
      expect(received, isNull);
      expect(result.data, 'ok');
    });

    test('a throwing mapper is an UnableToProcessException', () async {
      final result = await _handler().handleNetworkResult<int>(
        response: _response({'id': 1}),
        fromJson: _boom,
      );
      expect(result.error, isA<UnableToProcessException>());
      expect((result.error as ApiException).statusCode, -1);
    });

    test(
      'a mapper that fails asynchronously is an UnableToProcessException',
      () async {
        final result = await _handler().handleNetworkResult<int>(
          response: _response({'id': 1}),
          fromJson: (json) async => throw StateError('late failure'),
        );
        expect(result.error, isA<UnableToProcessException>());
      },
    );

    test(
      'the unable-to-process exception follows shouldShowApiErrors',
      () async {
        for (final show in [true, false]) {
          final result = await _handler().handleNetworkResult<int>(
            response: _response({'id': 1}),
            fromJson: _boom,
            settings: _quiet.copyWith(shouldShowApiErrors: show),
          );
          expect((result.error as ApiException).shouldShowApiError, show);
        }
      },
    );

    test('a body that cannot be read is an UnexpectedErrorException', () async {
      final result = await _handler().handleNetworkResult<int>(
        response: _BrokenResponse(),
        fromJson: _double,
      );
      expect(result.error, isA<UnexpectedErrorException>());
    });

    test(
      'an already cancelled token gives a RequestCanceledException',
      () async {
        final token = CancelToken()..cancel('stop');
        final result = await _handler().handleNetworkResult<int>(
          response: _response({'id': 1}),
          fromJson: _double,
          cancelToken: token,
        );
        expect(result.error, isA<RequestCanceledException>());
      },
    );

    test(
      'cancelling while the mapper runs gives a RequestCanceledException',
      () async {
        final token = CancelToken();
        final future = _handler().handleNetworkResult<String>(
          response: _response({'id': 1}),
          fromJson: (json) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return 'late';
          },
          cancelToken: token,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        token.cancel();
        final result = await future.timeout(const Duration(seconds: 2));
        expect(result.error, isA<RequestCanceledException>());
      },
    );

    test('an untouched token does not interfere', () async {
      final result = await _handler().handleNetworkResult<int>(
        response: _response({'id': 3}),
        fromJson: _double,
        cancelToken: CancelToken(),
      );
      expect(result.data, 6);
    });

    test('maps in an isolate when enabled', () async {
      final result = await _handler(_isolateSettings).handleNetworkResult<int>(
        response: _response({'id': 4}),
        fromJson: _double,
      );
      expect(result.data, 8);
    });

    test(
      'a failing mapper in an isolate is an UnableToProcessException',
      () async {
        final result = await _handler(_isolateSettings)
            .handleNetworkResult<int>(
              response: _response({'id': 4}),
              fromJson: _boom,
            );
        expect(result.error, isA<UnableToProcessException>());
      },
    );

    test('per-request settings can turn the isolate on', () async {
      final result = await _handler().handleNetworkResult<int>(
        response: _response({'id': 6}),
        fromJson: _double,
        settings: _isolateSettings,
      );
      expect(result.data, 12);
    });
  });

  group('cancellation racing the mapping', () {
    // Cancelling right as the mapper finishes used to throw "Bad state:
    // Future already completed" as an uncaught async error. flutter_test fails
    // a test when one escapes, so just exercise many timings.
    test('never throws, whichever finishes first', () async {
      for (var offset = 0; offset <= 12; offset++) {
        final token = CancelToken();
        final future = _handler().handleNetworkResult<String>(
          response: _response({'id': 1}),
          fromJson: (json) async {
            await Future<void>.delayed(const Duration(milliseconds: 6));
            return 'done';
          },
          cancelToken: token,
        );
        Timer(Duration(milliseconds: offset), token.cancel);
        final result = await future.timeout(const Duration(seconds: 2));
        expect(
          result.isSuccess || result.error is RequestCanceledException,
          isTrue,
          reason: 'offset $offset: ${result.error}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('a mapper failing after the cancel does not leak an error', () async {
      final token = CancelToken();
      final future = _handler().handleNetworkResult<String>(
        response: _response({'id': 1}),
        fromJson: (json) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          throw StateError('failed after cancel');
        },
        cancelToken: token,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      token.cancel();
      final result = await future.timeout(const Duration(seconds: 2));
      expect(result.error, isA<RequestCanceledException>());
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
  });

  group('handleNetworkResultForList', () {
    test('maps every item', () async {
      final result = await _handler().handleNetworkResultForList<String>(
        response: _response([
          {'id': 1},
          {'id': 2},
        ]),
        fromJson: _label,
      );
      expect(result.data, ['item-1', 'item-2']);
    });

    test('reads the list from dataKey', () async {
      final result = await _handler().handleNetworkResultForList<String>(
        response: _response({
          'data': {
            'items': [
              {'id': 7},
            ],
          },
        }),
        fromJson: _label,
        dataKey: 'data.items',
      );
      expect(result.data, ['item-7']);
    });

    test('unwraps each item with itemDataKey', () async {
      final result = await _handler().handleNetworkResultForList<String>(
        response: _response([
          {
            'attributes': {'id': 1},
          },
          {'id': 2}, // no wrapper: used as is
        ]),
        fromJson: _label,
        itemDataKey: 'attributes',
      );
      expect(result.data, ['item-1', 'item-2']);
    });

    test('a body that is not a list is an UnableToProcessException', () async {
      final result = await _handler().handleNetworkResultForList<String>(
        response: _response({'id': 1}),
        fromJson: _label,
      );
      expect(result.error, isA<UnableToProcessException>());
    });

    test('a missing dataKey is an UnableToProcessException', () async {
      final result = await _handler().handleNetworkResultForList<String>(
        response: _response({'other': []}),
        fromJson: _label,
        dataKey: 'data',
      );
      expect(result.error, isA<UnableToProcessException>());
    });

    test('an item that fails to map fails the whole list', () async {
      final result = await _handler().handleNetworkResultForList<int>(
        response: _response([
          {'id': 1},
        ]),
        fromJson: _boom,
      );
      expect(result.error, isA<UnableToProcessException>());
    });

    test('an empty list is an EmptyResponseException by default', () async {
      final result = await _handler().handleNetworkResultForList<String>(
        response: _response(<dynamic>[]),
        fromJson: _label,
      );
      expect(result.error, isA<EmptyResponseException>());
    });

    test('a body that cannot be read is an UnexpectedErrorException', () async {
      final result = await _handler().handleNetworkResultForList<String>(
        response: _BrokenResponse(),
        fromJson: _label,
      );
      expect(result.error, isA<UnexpectedErrorException>());
    });

    test(
      'an already cancelled token gives a RequestCanceledException',
      () async {
        final token = CancelToken()..cancel();
        final result = await _handler().handleNetworkResultForList<String>(
          response: _response([
            {'id': 1},
          ]),
          fromJson: _label,
          cancelToken: token,
        );
        expect(result.error, isA<RequestCanceledException>());
      },
    );

    test(
      'cancelling while items are mapped is a RequestCanceledException',
      () async {
        final token = CancelToken();
        final future = _handler().handleNetworkResultForList<String>(
          response: _response([
            {'id': 1},
          ]),
          fromJson: (json) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return 'late';
          },
          cancelToken: token,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        token.cancel();
        final result = await future.timeout(const Duration(seconds: 2));
        expect(result.error, isA<RequestCanceledException>());
      },
    );

    test('maps in an isolate when enabled', () async {
      final result = await _handler(_isolateSettings)
          .handleNetworkResultForList<String>(
            response: _response([
              {'id': 1},
              {'id': 2},
            ]),
            fromJson: _label,
          );
      expect(result.data, ['item-1', 'item-2']);
    });

    test('an isolate failure is an UnableToProcessException', () async {
      final result = await _handler(_isolateSettings)
          .handleNetworkResultForList<int>(
            response: _response([
              {'id': 1},
            ]),
            fromJson: _boom,
          );
      expect(result.error, isA<UnableToProcessException>());
    });
  });

  group('handleNetworkResultForDownload', () {
    test('returns the response on success', () async {
      final response = _response('file bytes');
      final result = await _handler().handleNetworkResultForDownload(
        response: response,
        shouldHandleUnauthorizedRequest: true,
      );
      expect(result.data, same(response));
    });

    test('maps error statuses', () async {
      final result = await _handler().handleNetworkResultForDownload(
        response: _response({'message': 'gone'}, status: 404),
        shouldHandleUnauthorizedRequest: true,
      );
      expect(result.error, isA<NotFoundException>());
      expect(result.error!.message, 'gone');
    });

    test('a cancelled token is a RequestCanceledException', () async {
      final result = await _handler().handleNetworkResultForDownload(
        response: _response('bytes'),
        shouldHandleUnauthorizedRequest: true,
        cancelToken: CancelToken()..cancel(),
      );
      expect(result.error, isA<RequestCanceledException>());
    });

    test('an unreadable response is an UnexpectedErrorException', () async {
      final result = await _handler().handleNetworkResultForDownload(
        response: _response('bytes'),
        shouldHandleUnauthorizedRequest: true,
        cancelToken: _ThrowingToken(),
      );
      expect(result.error, isA<UnexpectedErrorException>());
    });
  });

  group('handleDioException', () {
    test('maps a DioException', () async {
      final result = await _handler().handleDioException<String>(
        error: DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      expect(result.error, isA<RequestTimeoutException>());
    });
  });
}

class _ThrowingToken extends CancelToken {
  @override
  bool get isCancelled => throw StateError('token exploded');
}
