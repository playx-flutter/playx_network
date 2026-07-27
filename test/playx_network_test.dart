import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/handler/api_handler.dart';

/// A simple Dio [HttpClientAdapter] that returns a canned [ResponseBody]
/// for a given status code and body. This lets us drive [PlayxNetworkClient]
/// through the real Dio pipeline (including `validateStatus: (_) => true`)
/// so that the [ApiHandler] is the one deciding success/error.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({
    this.statusCode = 200,
    this.data,
  });

  int statusCode;
  Object? data;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = data is String
        ? data as String
        : data == null
            ? ''
            : jsonEncode(data);
    return ResponseBody(
      Stream.fromIterable([utf8.encode(body)]),
      statusCode,
      headers: const {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

/// An adapter that always throws a given [DioException].
class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.exception);

  final DioException exception;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw exception;
  }
}

/// A custom error model used to verify that the [ErrorMapper] can return a
/// structured object instead of just a [String].
class CustomError {
  final int code;
  final String detail;
  final List<String> fieldErrors;

  const CustomError({
    required this.code,
    required this.detail,
    this.fieldErrors = const [],
  });

  factory CustomError.fromJson(Map<String, dynamic> json) {
    return CustomError(
      code: json['code'] as int? ?? -1,
      detail: json['detail'] as String? ?? '',
      fieldErrors: (json['field_errors'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomError &&
          code == other.code &&
          detail == other.detail &&
          _listEquals(fieldErrors, other.fieldErrors);

  @override
  int get hashCode => Object.hash(code, detail, Object.hashAll(fieldErrors));

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Convenience builder for a [PlayxNetworkClient] backed by a [_StubAdapter].
PlayxNetworkClient _buildClient({
  required _StubAdapter adapter,
  ErrorMapper? errorMapper,
  PlayxNetworkClientSettings? settings,
  UnauthorizedRequestHandler? onUnauthorizedRequestReceived,
}) {
  final dio =
      PlayxNetworkClient.createDefaultDioClient(baseUrl: 'https://test.local');
  dio.httpClientAdapter = adapter;
  return PlayxNetworkClient(
    dio: dio,
    errorMapper: errorMapper,
    settings: settings ?? const PlayxNetworkClientSettings(),
    onUnauthorizedRequestReceived: onUnauthorizedRequestReceived,
  );
}

void main() {
  group('NetworkException.errorData', () {
    test('NetworkException stores errorData and defaults to null', () {
      const exception = UnexpectedErrorException(
        errorMessage: 'something went wrong',
      );
      expect(exception.errorData, isNull);
      expect(exception.errorMessage, 'something went wrong');
      expect(exception.message, 'something went wrong');
    });

    test('NetworkException.errorDataAs<E> returns typed object', () {
      const custom = CustomError(code: 42, detail: 'boom');
      final exception = UnexpectedErrorException(
        errorMessage: 'fallback',
        errorData: custom,
      );
      expect(exception.errorData, custom);
      expect(exception.errorDataAs<CustomError>(), custom);
      expect(exception.errorDataAs<String>(), isNull);
    });

    test('ApiException.message uses apiErrorMessage when shouldShowApiError',
        () {
      const exception = DefaultApiException(
        errorMessage: 'fallback',
        apiErrorMessage: 'api msg',
      );
      expect(exception.message, 'api msg');
      expect(exception.errorData, isNull);
    });

    test('ApiException.message falls back to errorMessage when apiError null',
        () {
      const exception = DefaultApiException(
        errorMessage: 'fallback',
        apiErrorMessage: null,
      );
      expect(exception.message, 'fallback');
    });

    test('ApiException.message uses errorMessage when shouldShowApiError false',
        () {
      const exception = DefaultApiException(
        errorMessage: 'fallback',
        apiErrorMessage: 'api msg',
        shouldShowApiError: false,
      );
      expect(exception.message, 'fallback');
    });

    test('ApiException stores structured errorData object', () {
      const custom = CustomError(code: 7, detail: 'invalid');
      const exception = DefaultApiException(
        errorMessage: 'fallback',
        apiErrorMessage: null,
        errorData: custom,
      );
      expect(exception.errorData, custom);
      expect(exception.errorDataAs<CustomError>(), custom);
      // message falls back since apiErrorMessage is null.
      expect(exception.message, 'fallback');
    });

    test('ApiException.fromStatusCode forwards errorData to all subclasses',
        () {
      const messages = DefaultEnglishExceptionMessage();
      const custom = CustomError(code: 1, detail: 'd');

      final notFound = ApiException.fromStatusCode(
        statusCode: 404,
        exceptionMessages: messages,
        errorData: custom,
      );
      expect(notFound, isA<NotFoundException>());
      expect(notFound.errorData, custom);

      final conflict = ApiException.fromStatusCode(
        statusCode: 409,
        exceptionMessages: messages,
        errorData: custom,
      );
      expect(conflict, isA<ConflictException>());
      expect(conflict.errorData, custom);

      final timeout = ApiException.fromStatusCode(
        statusCode: 408,
        exceptionMessages: messages,
        errorData: custom,
      );
      expect(timeout, isA<RequestTimeoutException>());
      expect(timeout.errorData, custom);

      final unable = ApiException.fromStatusCode(
        statusCode: 422,
        exceptionMessages: messages,
        errorData: custom,
      );
      expect(unable, isA<UnableToProcessException>());
      expect(unable.errorData, custom);

      final serverError = ApiException.fromStatusCode(
        statusCode: 500,
        exceptionMessages: messages,
        errorData: custom,
      );
      expect(serverError, isA<InternalServerErrorException>());
      expect(serverError.errorData, custom);

      final unavailable = ApiException.fromStatusCode(
        statusCode: 503,
        exceptionMessages: messages,
        errorData: custom,
      );
      expect(unavailable, isA<ServiceUnavailableException>());
      expect(unavailable.errorData, custom);

      final unknown = ApiException.fromStatusCode(
        statusCode: 418,
        exceptionMessages: messages,
        errorData: custom,
      );
      expect(unknown, isA<DefaultApiException>());
      expect(unknown.errorData, custom);
    });

    test('non-Api exceptions also carry errorData', () {
      const sendTimeout = SendTimeoutException(
        errorMessage: 'timeout',
        errorData: 'raw-send-timeout',
      );
      expect(sendTimeout.errorData, 'raw-send-timeout');

      const canceled = RequestCanceledException(
        errorMessage: 'canceled',
        errorData: 'raw-cancel',
      );
      expect(canceled.errorData, 'raw-cancel');

      const noInternet = NoInternetConnectionException(
        errorMessage: 'no net',
        errorData: 'raw-no-net',
      );
      expect(noInternet.errorData, 'raw-no-net');
    });
  });

  group('ErrorMapper', () {
    test('default ErrorMapper returns String? from json', () {
      expect(ApiHandler.getErrorMessageFromResponse(null), isNull);

      const json = <String, dynamic>{
        'message': 'Email is invalid',
      };
      expect(ApiHandler.getErrorMessageFromResponse(json), 'Email is invalid');
    });

    test('default ErrorMapper handles nested error object', () {
      const json = <String, dynamic>{
        'error': {'message': 'Not authorized'},
      };
      expect(ApiHandler.getErrorMessageFromResponse(json), 'Not authorized');
    });

    test('custom ErrorMapper can return structured object', () {
      Object? mapper(dynamic json) {
        if (json is Map<String, dynamic>) {
          return CustomError.fromJson(json);
        }
        return null;
      }

      final result = mapper(const <String, dynamic>{
        'code': 1001,
        'detail': 'validation failed',
        'field_errors': ['name is required', 'email is invalid'],
      });

      expect(result, isA<CustomError>());
      final err = result as CustomError;
      expect(err.code, 1001);
      expect(err.detail, 'validation failed');
      expect(err.fieldErrors, ['name is required', 'email is invalid']);
    });
  });

  group('ApiHandler.handleNetworkResult - error as string by default', () {
    test('returns NetworkError with String errorData by default', () async {
      final adapter = _StubAdapter(
        statusCode: 404,
        data: const <String, dynamic>{'message': 'User not found'},
      );
      final client = _buildClient(adapter: adapter);

      final result = await client.get<Map<String, dynamic>>(
        '/users/1',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      expect(result.isError, isTrue);
      final error = result.error!;
      expect(error, isA<NotFoundException>());
      // Default mapper returns String, so errorData is a String.
      expect(error.errorData, 'User not found');
      expect(error.errorData, isA<String>());
      // apiErrorMessage is populated from the String errorData.
      expect(error.message, 'User not found');
      expect(error.errorDataAs<String>(), 'User not found');
      // Structured access returns null since errorData is String.
      expect(error.errorDataAs<CustomError>(), isNull);
    });

    test('returns NetworkError with String errorData for 400', () async {
      final adapter = _StubAdapter(
        statusCode: 400,
        data: const <String, dynamic>{'message': 'Bad request body'},
      );
      final client = _buildClient(adapter: adapter);

      final result = await client.get<Map<String, dynamic>>(
        '/items',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      expect(result.isError, isTrue);
      final error = result.error!;
      expect(error, isA<DefaultApiException>());
      expect(error.errorData, 'Bad request body');
      expect(error.message, 'Bad request body');
    });

    test('returns NetworkError with String errorData for nested error',
        () async {
      final adapter = _StubAdapter(
        statusCode: 500,
        data: const <String, dynamic>{
          'error': {'message': 'Database down'},
        },
      );
      final client = _buildClient(adapter: adapter);

      final result = await client.get<Map<String, dynamic>>(
        '/items',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      expect(result.isError, isTrue);
      final error = result.error!;
      expect(error, isA<InternalServerErrorException>());
      expect(error.errorData, 'Database down');
      expect(error.message, 'Database down');
    });

    test('falls back to errorMessage when mapper returns null', () async {
      final adapter = _StubAdapter(
        statusCode: 404,
        data: const <String, dynamic>{'unrecognized': 'shape'},
      );
      final client = _buildClient(adapter: adapter);

      final result = await client.get<Map<String, dynamic>>(
        '/users/1',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      expect(result.isError, isTrue);
      final error = result.error!;
      expect(error, isA<NotFoundException>());
      // Default mapper can't extract a message -> errorData is null.
      expect(error.errorData, isNull);
      // message falls back to the localized errorMessage.
      expect(error.message, DefaultEnglishExceptionMessage().notFound);
    });
  });

  group('ApiHandler.handleNetworkResult - error as custom object', () {
    test('custom ErrorMapper returns object and populates errorData', () async {
      final adapter = _StubAdapter(
        statusCode: 422,
        data: const <String, dynamic>{
          'code': 422,
          'detail': 'Validation failed',
          'field_errors': ['name is required'],
        },
      );
      Object? mapper(dynamic json) {
        if (json is Map<String, dynamic>) {
          return CustomError.fromJson(json);
        }
        return null;
      }

      final client = _buildClient(adapter: adapter, errorMapper: mapper);

      final result = await client.get<Map<String, dynamic>>(
        '/items',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      expect(result.isError, isTrue);
      final error = result.error!;
      expect(error, isA<UnableToProcessException>());
      // errorData is the structured object, not a String.
      expect(error.errorData, isA<CustomError>());
      final custom = error.errorDataAs<CustomError>();
      expect(custom, isNotNull);
      expect(custom!.code, 422);
      expect(custom.detail, 'Validation failed');
      expect(custom.fieldErrors, ['name is required']);
      // apiErrorMessage is null since errorData is not a String.
      // message falls back to the localized errorMessage.
      expect(error.message, DefaultEnglishExceptionMessage().unableToProcess);
      expect(error.errorDataAs<String>(), isNull);
    });

    test('per-request errorMapper overrides client errorMapper', () async {
      final adapter = _StubAdapter(
        statusCode: 409,
        data: const <String, dynamic>{'code': 9, 'detail': 'conflict!'},
      );

      // Client-level mapper returns a String.
      Object? clientMapper(dynamic json) => 'client-string';

      final client = _buildClient(adapter: adapter, errorMapper: clientMapper);

      final result = await client.get<Map<String, dynamic>>(
        '/items',
        fromJson: (json) => json as Map<String, dynamic>,
        errorMapper: (json) =>
            json is Map<String, dynamic> ? CustomError.fromJson(json) : null,
      );

      expect(result.isError, isTrue);
      final error = result.error!;
      expect(error, isA<ConflictException>());
      // The per-request mapper wins.
      expect(error.errorData, isA<CustomError>());
      final custom = error.errorDataAs<CustomError>();
      expect(custom, isNotNull);
      expect(custom!.code, 9);
      expect(custom.detail, 'conflict!');
    });

    test('custom mapper returning String works like default', () async {
      final adapter = _StubAdapter(
        statusCode: 400,
        data: const <String, dynamic>{'code': 400, 'detail': 'bad input'},
      );

      // A custom mapper that returns a String should populate apiErrorMessage.
      Object? mapper(dynamic json) => 'custom string msg';

      final client = _buildClient(adapter: adapter, errorMapper: mapper);

      final result = await client.get<Map<String, dynamic>>(
        '/items',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      expect(result.isError, isTrue);
      final error = result.error!;
      expect(error.errorData, 'custom string msg');
      expect(error.errorData, isA<String>());
      expect(error.message, 'custom string msg');
    });

    test('custom mapper returning null falls back to errorMessage', () async {
      final adapter = _StubAdapter(
        statusCode: 500,
        data: const <String, dynamic>{'foo': 'bar'},
      );

      Object? mapper(dynamic json) => null;

      final client = _buildClient(adapter: adapter, errorMapper: mapper);

      final result = await client.get<Map<String, dynamic>>(
        '/items',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      expect(result.isError, isTrue);
      final error = result.error!;
      expect(error, isA<InternalServerErrorException>());
      expect(error.errorData, isNull);
      expect(
          error.message, DefaultEnglishExceptionMessage().internalServerError);
    });
  });

  group('NetworkResult error propagation', () {
    test('NetworkError exposes errorData via the exception', () {
      const result = NetworkResult<String>.error(
        UnauthorizedRequestException(
          errorMessage: 'unauthorized',
          apiErrorMessage: 'token expired',
          errorData: 'token-expired-string',
        ),
      );
      expect(result.isError, isTrue);
      final error = result.error!;
      expect(error.errorData, 'token-expired-string');
      expect(error.message, 'token expired');
    });

    test('NetworkResult.when receives the exception with errorData', () async {
      final adapter = _StubAdapter(
        statusCode: 404,
        data: const <String, dynamic>{'message': 'gone'},
      );
      final client = _buildClient(adapter: adapter);

      final result = await client.get<String>(
        '/x',
        fromJson: (json) => json.toString(),
      );

      String? capturedData;
      NetworkException? capturedError;
      result.when(
        success: (data) => capturedData = data,
        error: (e) => capturedError = e,
      );

      expect(capturedData, isNull);
      expect(capturedError, isNotNull);
      expect(capturedError!.errorData, 'gone');
    });

    test('NetworkResult.map transforms error with errorData available',
        () async {
      final adapter = _StubAdapter(
        statusCode: 422,
        data: const <String, dynamic>{
          'code': 422,
          'detail': 'bad',
          'field_errors': ['f1'],
        },
      );
      final client = _buildClient(
        adapter: adapter,
        errorMapper: (json) =>
            json is Map<String, dynamic> ? CustomError.fromJson(json) : null,
      );

      final result = await client.get<Map<String, dynamic>>(
        '/x',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      final mapped = result.map<String>(
        success: (s) => 'ok',
        error: (e) => e.error.errorDataAs<CustomError>()?.detail ?? 'unknown',
      );

      expect(mapped, 'bad');
    });
  });

  group('Success path unaffected by errorData', () {
    test('successful response returns NetworkSuccess with data', () async {
      final adapter = _StubAdapter(
        statusCode: 200,
        data: const <String, dynamic>{'id': 1, 'name': 'Item'},
      );
      final client = _buildClient(adapter: adapter);

      final result = await client.get<Map<String, dynamic>>(
        '/items/1',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!['name'], 'Item');
      expect(result.error, isNull);
    });

    test('successful list response returns NetworkSuccess with list', () async {
      final adapter = _StubAdapter(
        statusCode: 200,
        data: [
          {'id': 1, 'name': 'A'},
          {'id': 2, 'name': 'B'},
        ],
      );
      final client = _buildClient(adapter: adapter);

      final result = await client.getList<Map<String, dynamic>>(
        '/items',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!.length, 2);
      expect(result.data![0]['name'], 'A');
    });
  });

  group('DioException path populates errorData', () {
    test('connection error returns NoInternetConnectionException', () async {
      final dio = PlayxNetworkClient.createDefaultDioClient(
        baseUrl: 'https://nonexistent.invalid',
      );
      // Force a connection error via an adapter that throws.
      dio.httpClientAdapter = _ThrowingAdapter(
        DioException(
          type: DioExceptionType.connectionError,
          requestOptions: RequestOptions(path: '/x'),
          error: const SocketException('failed'),
        ),
      );
      final client = PlayxNetworkClient(dio: dio);

      final result = await client.get<String>(
        '/x',
        fromJson: (json) => json.toString(),
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<NoInternetConnectionException>());
      expect(result.error!.message,
          DefaultEnglishExceptionMessage().noInternetConnection);
    });

    test('badResponse DioException delegates to _handleResponse with errorData',
        () async {
      final adapter = _StubAdapter(
        statusCode: 403,
        data: const <String, dynamic>{'message': 'Forbidden resource'},
      );
      final dio = PlayxNetworkClient.createDefaultDioClient(
        baseUrl: 'https://test.local',
      );
      dio.httpClientAdapter = adapter;
      // Use validateStatus that rejects 403 so Dio raises a badResponse
      // DioException, which ApiHandler._getDioException then re-routes through
      // _handleResponse.
      dio.options = dio.options.copyWith(
        validateStatus: (status) => status != null && status < 300,
      );
      final client = PlayxNetworkClient(dio: dio);

      final result = await client.get<String>(
        '/secret',
        fromJson: (json) => json.toString(),
      );

      expect(result.isError, isTrue);
      final error = result.error!;
      expect(error, isA<UnauthorizedRequestException>());
      expect(error.errorData, 'Forbidden resource');
      expect(error.message, 'Forbidden resource');
    });
  });
}
