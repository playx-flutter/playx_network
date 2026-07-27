import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A simple model used across the tests.
class User {
  User({this.id, this.name});

  User.fromJson(dynamic json) {
    id = json['id'] as int?;
    name = json['name'] as String?;
  }

  int? id;
  String? name;

  @override
  bool operator ==(Object other) =>
      other is User && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'User(id: $id, name: $name)';
}

/// Builds a [Dio] instance whose [Dio.httpClientAdapter] is replaced with a
/// stub that returns the given [statusCode], [data] and [headers].
///
/// Like [PlayxNetworkClient.createDefaultDioClient], this sets
/// `validateStatus: (_) => true` so that Dio returns every response (even
/// 4xx/5xx) instead of throwing a [DioException]. This lets the [ApiHandler]
/// decide success vs. error using [PlayxValidateStatus] or
/// `successRequestCodes`.
Dio _createDio({
  required int statusCode,
  dynamic data,
  Map<String, List<String>> headers = const {},
  Duration delay = Duration.zero,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://example.com',
    validateStatus: (_) => true,
  ));
  dio.httpClientAdapter = _StubAdapter(
    statusCode: statusCode,
    data: data,
    headers: headers,
    delay: delay,
  );
  return dio;
}

/// Adapter that always responds with a pre-configured [Response].
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({
    required this.statusCode,
    this.data,
    this.headers = const {},
    this.delay = Duration.zero,
  });

  final int statusCode;
  final dynamic data;
  final Map<String, List<String>> headers;
  final Duration delay;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (delay != Duration.zero) {
      await Future.delayed(delay);
    }
    final bytes = _encode(data);
    return ResponseBody.fromString(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader:
            headers[Headers.contentTypeHeader] ?? [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  String _encode(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    // ignore: avoid_dynamic_calls
    return value.toString();
  }
}

/// A Dio adapter that throws a [DioException] of the given [type].
class _ErrorAdapter implements HttpClientAdapter {
  _ErrorAdapter({required this.type, this.error});

  final DioExceptionType type;
  final Object? error;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: type,
      error: error,
    );
  }
}

/// Matches a [NetworkSuccess] and returns its data, otherwise fails the test.
T _expectSuccess<T>(NetworkResult<T> result) {
  expect(result.isSuccess, isTrue, reason: 'Expected success but got $result');
  return result.data as T;
}

/// Matches a [NetworkError] and returns its exception.
NetworkException _expectError<T>(NetworkResult<T> result) {
  expect(result.isError, isTrue, reason: 'Expected error but got $result');
  return result.error!;
}

// ---------------------------------------------------------------------------
// Settings tests
// ---------------------------------------------------------------------------

void main() {
  group('PlayxNetworkClientSettings', () {
    test('validateStatus defaults to null', () {
      const settings = PlayxNetworkClientSettings();
      expect(settings.validateStatus, isNull);
    });

    test('validateStatus can be set via constructor', () {
      bool? validator(Response r) => r.statusCode == 200;
      final settings = PlayxNetworkClientSettings(validateStatus: validator);
      expect(settings.validateStatus, isNotNull);
    });

    test('copyWith preserves validateStatus when not overridden', () {
      bool? validator(Response r) => true;
      final settings = PlayxNetworkClientSettings(validateStatus: validator);
      final copy = settings.copyWith(shouldShowApiErrors: false);
      expect(copy.validateStatus, same(validator));
    });

    test('copyWith can replace validateStatus', () {
      bool? v1(Response r) => true;
      bool? v2(Response r) => false;
      final settings = PlayxNetworkClientSettings(validateStatus: v1);
      final copy = settings.copyWith(validateStatus: v2);
      expect(copy.validateStatus, same(v2));
    });
  });

  // -------------------------------------------------------------------------
  // Interceptors support
  // -------------------------------------------------------------------------

  group('PlayxNetworkClient interceptors', () {
    test('attaches provided interceptors to the dio instance', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      final executed = <String>[];
      dio.httpClientAdapter = _StubAdapter(
        statusCode: 200,
        data: '{"id": 1, "name": "Test"}',
      );

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
        interceptors: [
          InterceptorsWrapper(
            onRequest: (options, handler) {
              executed.add('request');
              handler.next(options);
            },
            onResponse: (response, handler) {
              executed.add('response');
              handler.next(response);
            },
          ),
        ],
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(_expectSuccess(result).name, 'Test');
      expect(executed, containsAll(['request', 'response']));
    });

    test('configureInterceptors callback is invoked with dio and settings',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter =
          _StubAdapter(statusCode: 200, data: '{"id": 1, "name": "A"}');

      var calledWithSettings = false;
      PlayxNetworkClientSettings? capturedSettings;

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
        configureInterceptors: (d, s) {
          calledWithSettings = true;
          capturedSettings = s;
          d.interceptors.add(InterceptorsWrapper(
            onRequest: (options, handler) {
              options.headers['x-injected'] = 'true';
              handler.next(options);
            },
          ));
        },
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(_expectSuccess(result).name, 'A');
      expect(calledWithSettings, isTrue);
      expect(capturedSettings, isNotNull);
    });

    test('both interceptors list and configureInterceptors are applied',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter =
          _StubAdapter(statusCode: 200, data: '{"id": 1, "name": "B"}');

      final order = <String>[];

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
        interceptors: [
          InterceptorsWrapper(
            onRequest: (options, handler) {
              order.add('list');
              handler.next(options);
            },
          ),
        ],
        configureInterceptors: (d, s) {
          d.interceptors.add(InterceptorsWrapper(
            onRequest: (options, handler) {
              order.add('configured');
              handler.next(options);
            },
          ));
        },
      );

      await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      // list interceptor is added first, configured second
      expect(order, ['list', 'configured']);
    });
  });

  // -------------------------------------------------------------------------
  // Validate status tests
  // -------------------------------------------------------------------------

  group('PlayxValidateStatus', () {
    test('validateStatus returning true treats response as success', () async {
      final dio = _createDio(statusCode: 422, data: '{"id": 1, "name": "X"}');
      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          validateStatus: (r) => true,
        ),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      // 422 is not in successRequestCodes, but validateStatus returns true
      expect(result.isSuccess, isTrue);
      expect(_expectSuccess(result).name, 'X');
    });

    test('validateStatus returning false treats 200 as error', () async {
      final dio =
          _createDio(statusCode: 200, data: '{"message": "business error"}');
      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          validateStatus: (r) => false,
        ),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      // 200 is normally success, but validateStatus forces error
      expect(result.isError, isTrue);
      final error = _expectError(result);
      expect(error, isA<ApiException>());
      expect(error.shouldShowApiError, isTrue);
    });

    test('validateStatus returning null falls back to successRequestCodes',
        () async {
      final dio =
          _createDio(statusCode: 200, data: '{"id": 1, "name": "Fall"}');
      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          validateStatus: (r) => null,
        ),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(result.isSuccess, isTrue);
      expect(_expectSuccess(result).name, 'Fall');
    });

    test(
        'validateStatus returning null falls back to successRequestCodes (error)',
        () async {
      final dio = _createDio(statusCode: 404, data: '{"message": "not found"}');
      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          validateStatus: (r) => null,
        ),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(result.isError, isTrue);
      expect(_expectError(result), isA<NotFoundException>());
    });

    test('validateStatus can inspect response body for business logic',
        () async {
      // Server returns 200 but the body contains { "success": false }
      final dio = _createDio(
        statusCode: 200,
        data: '{"success": false, "data": {"id": 1, "name": "A"}}',
      );
      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          validateStatus: (r) {
            final data = r.data;
            if (data is Map<String, dynamic>) {
              return data['success'] == true;
            }
            return null;
          },
        ),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
        dataKey: 'data',
      );

      // success is false → should be treated as error
      expect(result.isError, isTrue);
    });

    test('per-request settings validateStatus overrides client settings',
        () async {
      final dio = _createDio(statusCode: 200, data: '{"id": 1, "name": "Per"}');
      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          // No validateStatus at the client level
        ),
      );

      final perRequestSettings = const PlayxNetworkClientSettings(
        logSettings: PlayxNetworkLoggerSettings(enabled: false),
        useIsolateForMappingJson: false,
        validateStatus: PlayxAlwaysFalseValidator.alwaysFalse,
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
        settings: perRequestSettings,
      );

      // per-request validateStatus forces error
      expect(result.isError, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Validate status for list requests
  // -------------------------------------------------------------------------

  group('PlayxValidateStatus for list', () {
    test('validateStatus returning true treats non-success code as success',
        () async {
      final dio = _createDio(
        statusCode: 206,
        data: '[{"id": 1, "name": "A"}, {"id": 2, "name": "B"}]',
      );
      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          validateStatus: (r) => true,
        ),
      );

      final result = await client.getList<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(result.isSuccess, isTrue);
      final list = _expectSuccess(result);
      expect(list, hasLength(2));
      expect(list.first.name, 'A');
    });

    test('validateStatus returning false treats 200 as error for list',
        () async {
      final dio = _createDio(
        statusCode: 200,
        data: '[{"id": 1, "name": "A"}]',
      );
      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          validateStatus: (r) => false,
        ),
      );

      final result = await client.getList<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(result.isError, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Validate status for download
  // -------------------------------------------------------------------------

  group('PlayxValidateStatus for download', () {
    test('validateStatus returning true allows non-standard success code',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('playx_test');
      final savePath = '${tempDir.path}/downloaded.txt';
      addTearDown(() => tempDir.delete(recursive: true));

      final dio = _createDio(
        statusCode: 204,
        data: 'file-bytes',
        headers: {
          Headers.contentLengthHeader: ['9']
        },
      );
      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          validateStatus: (r) => true,
        ),
      );

      final result = await client.download(
        '/file',
        savePath: savePath,
      );

      expect(result.isSuccess, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Validate status for POST
  // -------------------------------------------------------------------------

  group('PlayxValidateStatus for post', () {
    test('validateStatus returns true for 201 created', () async {
      final dio =
          _createDio(statusCode: 201, data: '{"id": 1, "name": "Created"}');
      final client = PlayxNetworkClient(
        dio: dio,
        settings: PlayxNetworkClientSettings(
          logSettings: const PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          validateStatus: (r) => r.statusCode != null && r.statusCode! < 300,
        ),
      );

      final result = await client.post<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(result.isSuccess, isTrue);
      expect(_expectSuccess(result).name, 'Created');
    });
  });

  // -------------------------------------------------------------------------
  // Bug fix: per-request settings now propagated to _handleResponse
  // -------------------------------------------------------------------------

  group('per-request settings propagation', () {
    test('per-request exceptionMessages is used for error mapping', () async {
      final dio = _createDio(statusCode: 500, data: '{"message": "err"}');

      // Client-level uses default English messages
      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      // Per-request: use a custom ExceptionMessage
      const customMessages = _GermanExceptionMessage();

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          exceptionMessages: customMessages,
        ),
      );

      expect(result.isError, isTrue);
      final error = _expectError(result) as ApiException;
      // The German errorMessage proves per-request settings were propagated.
      // (message falls back to apiErrorMessage which is extracted from the body,
      //  but errorMessage itself must be the German one.)
      expect(error.errorMessage, 'Interner Serverfehler');
    });

    test('per-request unauthorizedRequestCodes is respected', () async {
      final dio = _createDio(statusCode: 418, data: '{"message": "teapot"}');

      var unauthorizedCalled = false;

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
        onUnauthorizedRequestReceived: (response) {
          unauthorizedCalled = true;
        },
      );

      // Per-request: treat 418 as unauthorized
      const perRequest = PlayxNetworkClientSettings(
        logSettings: PlayxNetworkLoggerSettings(enabled: false),
        useIsolateForMappingJson: false,
        unauthorizedRequestCodes: [418],
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
        settings: perRequest,
      );

      expect(result.isError, isTrue);
      expect(unauthorizedCalled, isTrue,
          reason:
              'per-request unauthorizedRequestCodes should trigger handler');
      expect(_expectError(result), isA<UnauthorizedRequestException>());
    });

    test('per-request shouldShowApiErrors=false hides apiErrorMessage',
        () async {
      final dio = _createDio(
        statusCode: 404,
        data: '{"message": "Custom not found"}',
      );

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      const perRequest = PlayxNetworkClientSettings(
        logSettings: PlayxNetworkLoggerSettings(enabled: false),
        useIsolateForMappingJson: false,
        shouldShowApiErrors: false,
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
        settings: perRequest,
      );

      expect(result.isError, isTrue);
      final error = _expectError(result) as ApiException;
      // shouldShowApiError=false → message falls back to errorMessage
      expect(error.message, error.errorMessage);
      expect(error.message, isNot('Custom not found'));
    });
  });

  // -------------------------------------------------------------------------
  // DioException handling with per-request settings
  // -------------------------------------------------------------------------

  group('DioException handling with per-request settings', () {
    test('per-request settings used when DioException.badResponse occurs',
        () async {
      // Use a custom adapter that returns a 500 response via DioException
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _BadResponseAdapter(
        statusCode: 500,
        data: '{"message": "server error"}',
      );

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      const perRequest = PlayxNetworkClientSettings(
        logSettings: PlayxNetworkLoggerSettings(enabled: false),
        useIsolateForMappingJson: false,
        exceptionMessages: _GermanExceptionMessage(),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
        settings: perRequest,
      );

      expect(result.isError, isTrue);
      final error = _expectError(result) as ApiException;
      // German errorMessage proves per-request settings propagated to _getDioException
      expect(error.errorMessage, 'Interner Serverfehler');
    });

    test('DioExceptionType.connectionTimeout uses per-request settings',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _ErrorAdapter(
        type: DioExceptionType.connectionTimeout,
      );

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      const perRequest = PlayxNetworkClientSettings(
        logSettings: PlayxNetworkLoggerSettings(enabled: false),
        useIsolateForMappingJson: false,
        exceptionMessages: _GermanExceptionMessage(),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
        settings: perRequest,
      );

      expect(result.isError, isTrue);
      final error = _expectError(result);
      expect(error, isA<RequestTimeoutException>());
      expect(error.message, 'Zeitüberschreitung der Anfrage');
    });

    test(
        'DioExceptionType.connectionError yields NoInternetConnectionException',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _ErrorAdapter(
        type: DioExceptionType.connectionError,
      );

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(result.isError, isTrue);
      expect(_expectError(result), isA<NoInternetConnectionException>());
    });

    test('DioExceptionType.cancel yields RequestCanceledException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _ErrorAdapter(
        type: DioExceptionType.cancel,
      );

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(result.isError, isTrue);
      expect(_expectError(result), isA<RequestCanceledException>());
    });

    test('SocketException (via unknown type) yields NoInternetConnection',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.httpClientAdapter = _ErrorAdapter(
        type: DioExceptionType.unknown,
        error: const SocketException('no network'),
      );

      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(result.isError, isTrue);
      expect(_expectError(result), isA<NoInternetConnectionException>());
    });
  });

  // -------------------------------------------------------------------------
  // Default successRequestCodes still work (no validateStatus)
  // -------------------------------------------------------------------------

  group('default successRequestCodes behavior', () {
    test('200 is success by default', () async {
      final dio = _createDio(statusCode: 200, data: '{"id": 1, "name": "Ok"}');
      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(result.isSuccess, isTrue);
    });

    test('custom successRequestCodes treats 204 as success', () async {
      final dio =
          _createDio(statusCode: 204, data: '{"id": 1, "name": "NoContent"}');
      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          successRequestCodes: [200, 204],
        ),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(result.isSuccess, isTrue);
      expect(_expectSuccess(result).name, 'NoContent');
    });

    test('404 is error by default', () async {
      final dio = _createDio(statusCode: 404, data: '{"message": "nf"}');
      final client = PlayxNetworkClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
        ),
      );

      final result = await client.get<User>(
        '/users',
        fromJson: (json) => User.fromJson(json),
      );

      expect(result.isError, isTrue);
      expect(_expectError(result), isA<NotFoundException>());
    });
  });

  // -------------------------------------------------------------------------
  // NetworkResult API
  // -------------------------------------------------------------------------

  group('NetworkResult', () {
    test('when() invokes correct callback and returns this', () {
      const result = NetworkResult<int>.success(42);
      var captured = -1;
      final returned = result.when(
        success: (data) => captured = data,
        error: (_) => fail('should not be error'),
      );
      expect(captured, 42);
      expect(identical(returned, result), isTrue);
    });

    test('map() transforms success', () {
      const result = NetworkResult<int>.success(42);
      final mapped = result.map<String>(
        success: (s) => 'value=${s.data}',
        error: (e) => 'error',
      );
      expect(mapped, 'value=42');
    });

    test('map() transforms error', () {
      const result = NetworkResult<int>.error(
        UnexpectedErrorException(errorMessage: 'boom'),
      );
      final mapped = result.map<String>(
        success: (s) => 'value=${s.data}',
        error: (e) => 'err=${e.error.message}',
      );
      expect(mapped, 'err=boom');
    });

    test('isSuccess / isError / data / error accessors', () {
      const ok = NetworkResult<int>.success(7);
      expect(ok.isSuccess, isTrue);
      expect(ok.isError, isFalse);
      expect(ok.data, 7);
      expect(ok.error, isNull);

      const fail = NetworkResult<int>.error(
        RequestCanceledException(errorMessage: 'cancelled'),
      );
      expect(fail.isError, isTrue);
      expect(fail.isSuccess, isFalse);
      expect(fail.data, isNull);
      expect(fail.error, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // PlayxCancelTokenManager
  // -------------------------------------------------------------------------

  group('PlayxCancelTokenManager', () {
    test('getToken creates new token for new tag', () {
      final mgr = PlayxCancelTokenManager();
      final t1 = mgr.getToken('a');
      expect(t1.isCancelled, isFalse);
    });

    test('getToken cancels old token when cancelOld is true', () {
      final mgr = PlayxCancelTokenManager();
      final t1 = mgr.getToken('a');
      final t2 = mgr.getToken('a');
      expect(t1.isCancelled, isTrue);
      expect(t2.isCancelled, isFalse);
      expect(identical(t1, t2), isFalse);
    });

    test('getToken does not cancel old when cancelOld is false', () {
      final mgr = PlayxCancelTokenManager();
      final t1 = mgr.getToken('a', cancelOld: false);
      final t2 = mgr.getToken('a', cancelOld: false);
      expect(identical(t1, t2), isTrue);
      expect(t1.isCancelled, isFalse);
    });

    test('cancelRequests cancels and removes tag', () {
      final mgr = PlayxCancelTokenManager();
      final t1 = mgr.getToken('a');
      mgr.cancelRequests('a');
      expect(t1.isCancelled, isTrue);
    });

    test('cancelAllRequests cancels all and clears pool', () {
      final mgr = PlayxCancelTokenManager();
      final t1 = mgr.getToken('a');
      final t2 = mgr.getToken('b');
      mgr.cancelAllRequests();
      expect(t1.isCancelled, isTrue);
      expect(t2.isCancelled, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // createDefaultDioClient
  // -------------------------------------------------------------------------

  group('PlayxNetworkClient.createDefaultDioClient', () {
    test('returns a Dio with validateStatus accepting all responses', () {
      final dio = PlayxNetworkClient.createDefaultDioClient(
        baseUrl: 'https://example.com',
      );
      // validateStatus should accept every status code
      final options = dio.options;
      expect(options.validateStatus(500), isTrue);
      expect(options.validateStatus(200), isTrue);
      expect(options.baseUrl, 'https://example.com');
    });
  });

  // -------------------------------------------------------------------------
  // ApiHandler.getErrorMessageFromResponse
  // -------------------------------------------------------------------------

  group('ApiHandler.getErrorMessageFromResponse', () {
    test('returns null for null json', () {
      expect(ApiHandler.getErrorMessageFromResponse(null), isNull);
    });

    test('extracts message field', () {
      final msg = ApiHandler.getErrorMessageFromResponse({
        'message': 'Something went wrong',
      });
      expect(msg, 'Something went wrong');
    });

    test('extracts nested error.message', () {
      final msg = ApiHandler.getErrorMessageFromResponse({
        'error': {
          'message': 'Nested error',
        },
      });
      expect(msg, 'Nested error');
    });
  });

  // -------------------------------------------------------------------------
  // NetworkException hierarchy
  // -------------------------------------------------------------------------

  group('NetworkException', () {
    test('ApiException.fromStatusCode returns correct types', () {
      const messages = DefaultEnglishExceptionMessage();

      expect(
        ApiException.fromStatusCode(
            statusCode: 400, exceptionMessages: messages),
        isA<DefaultApiException>(),
      );
      expect(
        ApiException.fromStatusCode(
            statusCode: 404, exceptionMessages: messages),
        isA<NotFoundException>(),
      );
      expect(
        ApiException.fromStatusCode(
            statusCode: 409, exceptionMessages: messages),
        isA<ConflictException>(),
      );
      expect(
        ApiException.fromStatusCode(
            statusCode: 408, exceptionMessages: messages),
        isA<RequestTimeoutException>(),
      );
      expect(
        ApiException.fromStatusCode(
            statusCode: 422, exceptionMessages: messages),
        isA<UnableToProcessException>(),
      );
      expect(
        ApiException.fromStatusCode(
            statusCode: 500, exceptionMessages: messages),
        isA<InternalServerErrorException>(),
      );
      expect(
        ApiException.fromStatusCode(
            statusCode: 503, exceptionMessages: messages),
        isA<ServiceUnavailableException>(),
      );
      // unknown code falls back to DefaultApiException
      expect(
        ApiException.fromStatusCode(
            statusCode: 999, exceptionMessages: messages),
        isA<DefaultApiException>(),
      );
    });

    test('ApiException.message respects shouldShowApiError', () {
      const ex = ApiException(
        apiErrorMessage: 'API said this',
        errorMessage: 'Fallback',
        shouldShowApiError: true,
      );
      expect(ex.message, 'API said this');

      const ex2 = ApiException(
        apiErrorMessage: 'API said this',
        errorMessage: 'Fallback',
        shouldShowApiError: false,
      );
      expect(ex2.message, 'Fallback');
    });
  });

  // -------------------------------------------------------------------------
  // DefaultApiError parsing
  // -------------------------------------------------------------------------

  group('DefaultApiError', () {
    test('parses statusCode, name, message', () {
      final error = DefaultApiError.fromJson({
        'statusCode': 400,
        'name': 'BadRequest',
        'message': 'Invalid input',
      });
      expect(error.statusCode, 400);
      expect(error.name, 'BadRequest');
      expect(error.message, 'Invalid input');
    });

    test('parses nested error.message', () {
      final error = DefaultApiError.fromJson({
        'error': {
          'message': 'Deep error',
          'name': 'DeepName',
        },
      });
      expect(error.message, 'Deep error');
      expect(error.name, 'DeepName');
    });

    test('handles invalid json gracefully', () {
      final error = DefaultApiError.fromJson('not a map');
      expect(error.statusCode, isNull);
      expect(error.message, isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// A top-level validator function used as a const-compatible function reference.
class PlayxAlwaysFalseValidator {
  const PlayxAlwaysFalseValidator();

  static bool? alwaysFalse(Response response) => false;
}

/// German exception messages for verifying per-request settings propagation.
class _GermanExceptionMessage implements ExceptionMessage {
  const _GermanExceptionMessage();

  @override
  String get badRequest => 'Ungültige Anfrage';

  @override
  String get conflict => 'Konflikt';

  @override
  String get defaultError => 'Etwas ist schief gelaufen';

  @override
  String get emptyResponse => 'Keine Antwort vom Server';

  @override
  String get formatException => 'Falsches Format';

  @override
  String get internalServerError => 'Interner Serverfehler';

  @override
  String get noInternetConnection => 'Keine Internetverbindung';

  @override
  String get notAcceptable => 'Nicht akzeptabel';

  @override
  String get notFound => 'Nicht gefunden';

  @override
  String get requestCancelled => 'Anfrage abgebrochen';

  @override
  String get requestTimeout => 'Zeitüberschreitung der Anfrage';

  @override
  String get sendTimeout => 'Senden-Zeitüberschreitung';

  @override
  String get serviceUnavailable => 'Dienst nicht verfügbar';

  @override
  String get unableToProcess => 'Verarbeitung fehlgeschlagen';

  @override
  String get unauthorizedRequest => 'Nicht autorisiert';

  @override
  String get unexpectedError => 'Unerwarteter Fehler';
}

/// Adapter that returns a response that will be treated as a DioException.badResponse
/// because the status code is outside Dio's default validateStatus range.
class _BadResponseAdapter implements HttpClientAdapter {
  _BadResponseAdapter({
    required this.statusCode,
    this.data,
  });

  final int statusCode;
  final dynamic data;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = data is String ? (data as String) : data.toString();
    return ResponseBody.fromString(body, statusCode, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}
