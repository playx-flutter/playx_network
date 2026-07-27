import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';

/// A simple [HttpClientAdapter] that returns a canned [ResponseBody] for every
/// request, allowing tests to run without real network access.
class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._handler);

  /// Function that receives the [RequestOptions] and returns the [ResponseBody]
  /// that should be delivered.
  final Future<ResponseBody> Function(RequestOptions) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }
}

/// Creates a [ResponseBody] from a JSON-encodable [data] and [statusCode].
ResponseBody _jsonBody(
  dynamic data,
  int statusCode, {
  Map<String, List<String>>? headers,
}) {
  final bytes = utf8.encode(json.encode(data));
  return ResponseBody.fromBytes(
    bytes,
    statusCode,
    headers: {
      Headers.contentLengthHeader: ['${bytes.length}'],
      Headers.contentTypeHeader: ['application/json'],
      ...?headers,
    },
  );
}

/// Creates a [Dio] instance whose responses are driven by [handler].
Dio _createDio(
  Future<ResponseBody> Function(RequestOptions) handler, {
  BaseOptions? baseOptions,
}) {
  final dio = Dio(baseOptions ??
      BaseOptions(
        baseUrl: 'https://test.example.com',
        validateStatus: (_) => true,
      ));
  dio.httpClientAdapter = _MockAdapter(handler);
  return dio;
}

/// Default test settings that disable logging and isolate mapping for speed.
const _testSettings = PlayxNetworkClientSettings(
  logSettings: PlayxNetworkLoggerSettings(enabled: false),
  useIsolateForMappingJson: false,
);

void main() {
  // ---------------------------------------------------------------------------
  // PlayxNetworkClientSettings
  // ---------------------------------------------------------------------------
  group('PlayxNetworkClientSettings', () {
    test('defaults are sensible', () {
      const settings = PlayxNetworkClientSettings();

      expect(settings.shouldShowApiErrors, isTrue);
      expect(settings.unauthorizedRequestCodes, [401, 403]);
      expect(settings.successRequestCodes, [200, 201]);
      expect(settings.useIsolateForMappingJson, isTrue);
      expect(settings.useWorkMangerForMappingJsonInIsolate, isTrue);
      expect(settings.interceptors, isEmpty);
      expect(settings.interceptorsBuilder, isNull);
      expect(settings.validateStatus, isNull);
    });

    test('copyWith preserves un-overridden fields and applies overrides', () {
      final interceptor = _DummyInterceptor();
      final builder = () => [_DummyInterceptor()];

      final original = PlayxNetworkClientSettings(
        shouldShowApiErrors: false,
        successRequestCodes: const [200],
        unauthorizedRequestCodes: const [401],
        interceptors: [interceptor],
        interceptorsBuilder: builder,
      );

      final copied = original.copyWith(
        shouldShowApiErrors: true,
        successRequestCodes: const [200, 201, 204],
      );

      // Overridden
      expect(copied.shouldShowApiErrors, isTrue);
      expect(copied.successRequestCodes, [200, 201, 204]);

      // Preserved
      expect(copied.unauthorizedRequestCodes, [401]);
      expect(copied.interceptors, same(original.interceptors));
      expect(copied.interceptorsBuilder, same(original.interceptorsBuilder));
      expect(copied.validateStatus, isNull);
    });

    test(
        'copyWith can override interceptors, interceptorsBuilder and validateStatus',
        () {
      final interceptor = _DummyInterceptor();
      final builder = () => <Interceptor>[];
      bool validate(Response? r) => true;

      const original = PlayxNetworkClientSettings();

      final copied = original.copyWith(
        interceptors: [interceptor],
        interceptorsBuilder: builder,
        validateStatus: validate,
      );

      expect(copied.interceptors, hasLength(1));
      expect(copied.interceptors.first, isA<_DummyInterceptor>());
      expect(copied.interceptorsBuilder, same(builder));
      expect(copied.validateStatus, same(validate));
    });
  });

  // ---------------------------------------------------------------------------
  // Interceptors support
  // ---------------------------------------------------------------------------
  group('Interceptors', () {
    test('interceptors from settings are attached to DioClient', () {
      final interceptor = _RecordingInterceptor();
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 200);
      });

      PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          interceptors: [interceptor],
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      expect(dio.interceptors, contains(interceptor));
    });

    test('interceptorsBuilder interceptors are attached lazily', () {
      final interceptor = _RecordingInterceptor();
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 200);
      });

      PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          interceptorsBuilder: () => [interceptor],
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      expect(dio.interceptors, contains(interceptor));
    });

    test('interceptor receives request and response during a call', () async {
      final interceptor = _RecordingInterceptor();
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 200);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          interceptors: [interceptor],
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(interceptor.onRequestCalls, 1);
      expect(interceptor.onResponseCalls, 1);
      expect(interceptor.onErrorCalls, 0);
    });

    test('interceptor receives error when response is an error status',
        () async {
      final interceptor = _RecordingInterceptor();
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'bad request'}, 400);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          interceptors: [interceptor],
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      // Since validateStatus: (_) => true is set on BaseOptions, Dio won't
      // throw — so onResponse is called, not onError.
      expect(interceptor.onRequestCalls, 1);
      expect(interceptor.onResponseCalls, 1);
    });

    test('multiple interceptors are all attached', () {
      final i1 = _RecordingInterceptor();
      final i2 = _RecordingInterceptor();
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 200);
      });

      PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          interceptors: [i1, i2],
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      expect(dio.interceptors, containsAll([i1, i2]));
    });
  });

  // ---------------------------------------------------------------------------
  // validateStatus — settings-level
  // ---------------------------------------------------------------------------
  group('validateStatus (settings-level)', () {
    test('returns success when validateStatus returns true for non-2xx code',
        () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'created'}, 202);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          validateStatus: (response) => response?.statusCode == 202,
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'created');
    });

    test('returns error when validateStatus returns false for 200', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 200);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          validateStatus: (response) => response?.statusCode != 200,
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<DefaultApiException>());
    });

    test('falls back to successRequestCodes when validateStatus returns null',
        () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 204);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          // Return null → fall back to successRequestCodes
          validateStatus: (response) => null,
          successRequestCodes: const [200, 201, 204],
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'ok');
    });

    test('uses successRequestCodes when validateStatus is null', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 201);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          validateStatus: null,
          successRequestCodes: [200, 201],
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isSuccess, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // validateStatus — per-request override
  // ---------------------------------------------------------------------------
  group('validateStatus (per-request override)', () {
    test('per-request validateStatus overrides settings-level callback',
        () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 200);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          // Settings says: always error.
          validateStatus: (response) => false,
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      // Per-request says: 200 is success.
      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
        validateStatus: (response) => response?.statusCode == 200,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'ok');
    });

    test('per-request not passed falls back to settings-level validateStatus',
        () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 202);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          validateStatus: (response) => response?.statusCode == 202,
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      // When per-request validateStatus is not passed (null), the
      // settings-level callback is used.
      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'ok');
    });

    test(
        'per-request validateStatus returning null falls back to successRequestCodes',
        () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 202);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          // Settings-level says: 202 is success.
          validateStatus: (response) => response?.statusCode == 202,
          // But when per-request returns null, the fallback is
          // successRequestCodes (which doesn't include 202), NOT the
          // settings-level callback.
          successRequestCodes: const [200, 201],
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
        // Per-request callback returns null → falls back to successRequestCodes.
        validateStatus: (response) => null,
      );

      // 202 is not in successRequestCodes [200, 201], so it's an error.
      expect(result.isError, isTrue);
    });

    test('per-request validateStatus works on post request', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'created'}, 201);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          successRequestCodes: [200],
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      // Default successRequestCodes is [200], so 201 would normally be an error.
      // Per-request validateStatus overrides to accept 201.
      final result = await client.post(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
        validateStatus: (response) => response?.statusCode == 201,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'created');
    });

    test('per-request validateStatus works on delete request', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'deleted'}, 204);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          successRequestCodes: [200],
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.delete(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
        validateStatus: (response) => response?.statusCode == 204,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'deleted');
    });

    test('per-request validateStatus works on put request', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'updated'}, 200);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          successRequestCodes: [201],
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      // successRequestCodes is [201], so 200 would normally be an error.
      final result = await client.put(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
        validateStatus: (response) => response?.statusCode == 200,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'updated');
    });

    test('per-request validateStatus works on patch request', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'patched'}, 200);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          successRequestCodes: [201],
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.patch(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
        validateStatus: (response) => response?.statusCode == 200,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'patched');
    });

    test('per-request validateStatus returning false produces error', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 200);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
        validateStatus: (response) => false,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<DefaultApiException>());
    });
  });

  // ---------------------------------------------------------------------------
  // Default successRequestCodes behaviour (no validateStatus)
  // ---------------------------------------------------------------------------
  group('default successRequestCodes behaviour', () {
    test('returns success for 200 without validateStatus', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 200);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'ok');
    });

    test('returns success for 201 without validateStatus', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'created'}, 201);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'created');
    });

    test('returns error for 404 without validateStatus', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'not found'}, 404);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<NotFoundException>());
    });

    test('returns error for 400 without validateStatus', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'bad request'}, 400);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<DefaultApiException>());
    });

    test('returns error for 500 without validateStatus', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'server error'}, 500);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<InternalServerErrorException>());
    });

    test('returns error for 409 without validateStatus', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'conflict'}, 409);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<ConflictException>());
    });

    test('returns error for 503 without validateStatus', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'unavailable'}, 503);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<ServiceUnavailableException>());
    });
  });

  // ---------------------------------------------------------------------------
  // Per-request settings override for validateStatus
  // ---------------------------------------------------------------------------
  group('per-request settings override', () {
    test('per-request settings validateStatus overrides client-level',
        () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 202);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          // Client-level: only 200/201 are success.
          successRequestCodes: [200, 201],
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      // Pass per-request settings that accept 202 via successRequestCodes.
      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
        settings: const PlayxNetworkClientSettings(
          validateStatus: null,
          successRequestCodes: [200, 201, 202],
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'ok');
    });

    test('per-request settings with validateStatus callback works', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'ok'}, 202);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
        settings: PlayxNetworkClientSettings(
          validateStatus: (response) => response?.statusCode == 202,
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, 'ok');
    });
  });

  // ---------------------------------------------------------------------------
  // Unauthorized request handling with validateStatus
  // ---------------------------------------------------------------------------
  group('unauthorized request with validateStatus', () {
    test('validateStatus returning false for 401 triggers unauthorized handler',
        () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'unauthorized'}, 401);
      });

      var unauthorizedCalled = false;

      final client = PlayxNetworkClient(
        dio: dio,
        onUnauthorizedRequestReceived: (response) {
          unauthorizedCalled = true;
        },
        settings: PlayxNetworkClientSettings(
          validateStatus: (response) => false,
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<UnauthorizedRequestException>());
      expect(unauthorizedCalled, isTrue);
    });

    test(
        'validateStatus returning true for 401 treats it as success and skips unauthorized handler',
        () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'unauthorized'}, 401);
      });

      var unauthorizedCalled = false;

      final client = PlayxNetworkClient(
        dio: dio,
        onUnauthorizedRequestReceived: (response) {
          unauthorizedCalled = true;
        },
        settings: PlayxNetworkClientSettings(
          validateStatus: (response) => response?.statusCode == 401,
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isSuccess, isTrue);
      expect(unauthorizedCalled, isFalse);
    });

    test('403 triggers unauthorized handler by default', () async {
      final dio = _createDio((options) async {
        return _jsonBody({'message': 'forbidden'}, 403);
      });

      var unauthorizedCalled = false;

      final client = PlayxNetworkClient(
        dio: dio,
        onUnauthorizedRequestReceived: (response) {
          unauthorizedCalled = true;
        },
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => (json as Map<String, dynamic>)['message'] as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<UnauthorizedRequestException>());
      expect(unauthorizedCalled, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // DioException handling
  // ---------------------------------------------------------------------------
  group('DioException handling', () {
    test('connection timeout produces RequestTimeoutException', () async {
      final dio = _createDio((options) async {
        throw DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: options,
        );
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => json as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<RequestTimeoutException>());
    });

    test('cancel produces RequestCanceledException', () async {
      final dio = _createDio((options) async {
        throw DioException(
          type: DioExceptionType.cancel,
          requestOptions: options,
        );
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => json as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<RequestCanceledException>());
    });

    test('send timeout produces SendTimeoutException', () async {
      final dio = _createDio((options) async {
        throw DioException(
          type: DioExceptionType.sendTimeout,
          requestOptions: options,
        );
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => json as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<SendTimeoutException>());
    });

    test('connection error produces NoInternetConnectionException', () async {
      final dio = _createDio((options) async {
        throw DioException(
          type: DioExceptionType.connectionError,
          requestOptions: options,
        );
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => json as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<NoInternetConnectionException>());
    });

    test(
        'badResponse DioException uses _handleResponse with per-request settings',
        () async {
      final dio = _createDio((options) async {
        throw DioException(
          type: DioExceptionType.badResponse,
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 404,
            data: {'message': 'not found'},
          ),
        );
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => json as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<NotFoundException>());
    });

    test('badResponse DioException for 401 triggers unauthorized handler',
        () async {
      final dio = _createDio((options) async {
        throw DioException(
          type: DioExceptionType.badResponse,
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 401,
            data: {'message': 'unauthorized'},
          ),
        );
      });

      var unauthorizedCalled = false;

      final client = PlayxNetworkClient(
        dio: dio,
        onUnauthorizedRequestReceived: (response) {
          unauthorizedCalled = true;
        },
        settings: _testSettings,
      );

      final result = await client.get(
        '/test',
        fromJson: (json) => json as String,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<UnauthorizedRequestException>());
      expect(unauthorizedCalled, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Download with validateStatus
  // ---------------------------------------------------------------------------
  group('download with validateStatus', () {
    test('download succeeds when validateStatus returns true for non-2xx',
        () async {
      final dio = _createDio((options) async {
        return _jsonBody({'file': 'data'}, 202);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          validateStatus: (response) => response?.statusCode == 202,
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.download(
        '/file',
        savePath: '/tmp/test_download.json',
        validateStatus: (response) => response?.statusCode == 202,
      );

      expect(result.isSuccess, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // getList with validateStatus
  // ---------------------------------------------------------------------------
  group('getList with validateStatus', () {
    test('getList succeeds for non-2xx when validateStatus returns true',
        () async {
      final dio = _createDio((options) async {
        return _jsonBody([
          {'id': 1, 'name': 'item1'},
          {'id': 2, 'name': 'item2'},
        ], 202);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          validateStatus: (response) => response?.statusCode == 202,
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.getList(
        '/list',
        fromJson: (json) => TestItem.fromJson(json as Map<String, dynamic>),
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, hasLength(2));
      expect(result.data?.first.name, 'item1');
    });

    test('getList returns error when validateStatus returns false', () async {
      final dio = _createDio((options) async {
        return _jsonBody([
          {'id': 1, 'name': 'item1'},
        ], 200);
      });

      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          validateStatus: (response) => false,
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.getList(
        '/list',
        fromJson: (json) => TestItem.fromJson(json as Map<String, dynamic>),
      );

      expect(result.isError, isTrue);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// A minimal interceptor that records the number of onRequest / onResponse /
/// onError invocations.
class _RecordingInterceptor extends Interceptor {
  int onRequestCalls = 0;
  int onResponseCalls = 0;
  int onErrorCalls = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    onRequestCalls++;
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    onResponseCalls++;
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    onErrorCalls++;
    handler.next(err);
  }
}

/// A no-op interceptor used to test that interceptors are attached.
class _DummyInterceptor extends Interceptor {}

/// Simple model used in list tests.
class TestItem {
  final int id;
  final String name;

  const TestItem({required this.id, required this.name});

  factory TestItem.fromJson(Map<String, dynamic> json) {
    return TestItem(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}
