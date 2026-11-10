import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';

class CustomError {
  CustomError(this.code, this.detail);

  factory CustomError.fromJson(dynamic json) =>
      CustomError(json['code'] as String, json['detail'] as String);

  final String code;
  final String detail;
}

/// Short-circuits every request with a fixed response, or rejects it with a
/// [DioException] of type `badResponse` when [reject] is set.
class _FixedResponseInterceptor extends Interceptor {
  _FixedResponseInterceptor(this.data, this.statusCode, {this.reject = false});

  final dynamic data;
  final int statusCode;
  final bool reject;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final response = Response<dynamic>(
      requestOptions: options,
      statusCode: statusCode,
      data: data,
    );
    if (reject) {
      handler.reject(
        DioException.badResponse(
          statusCode: statusCode,
          requestOptions: options,
          response: response,
        ),
      );
    } else {
      handler.resolve(response);
    }
  }
}

class _ErrorStreamAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    utf8.encode(jsonEncode({'code': 'S1', 'detail': 'stream failed'})),
    422,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

const _errorBody = {
  'code': 'E42',
  'detail': 'Name is taken',
  'message': 'bad request',
};

PlayxNetworkClient _client({
  int statusCode = 400,
  dynamic data = _errorBody,
  bool reject = false,
  ErrorMapper? errorMapper,
  ErrorExtraMapper? errorExtraMapper,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/'))
    ..interceptors.add(
      _FixedResponseInterceptor(data, statusCode, reject: reject),
    );
  return PlayxNetworkClient(
    dio: dio,
    errorMapper: errorMapper,
    errorExtraMapper: errorExtraMapper,
    settings: const PlayxNetworkClientSettings(
      useIsolateForMappingJson: false,
      useWorkMangerForMappingJsonInIsolate: false,
    ),
  );
}

String _fromJson(dynamic json) => json.toString();

void main() {
  test('ErrorMapper keeps its String? signature', () {
    // Source compatibility: existing mappers and callers must keep compiling.
    String? messageOf(dynamic json) => json['message'] as String?;
    final ErrorMapper mapper = messageOf;
    final String? message = mapper(_errorBody);
    expect(message, 'bad request');
  });

  group('errorExtraMapper', () {
    test('client-level mapper fills ApiException.extra', () async {
      final result = await _client(
        errorExtraMapper: CustomError.fromJson,
      ).get<String>('x', fromJson: _fromJson);
      final error = result.error as ApiException;
      expect(error.extra, isA<CustomError>());
      expect(error.extraAs<CustomError>()!.code, 'E42');
      expect(error.extraAs<CustomError>()!.detail, 'Name is taken');
    });

    test('the String errorMapper still produces the message', () async {
      final result = await _client(
        errorMapper: (json) => json['message'] as String?,
        errorExtraMapper: CustomError.fromJson,
      ).get<String>('x', fromJson: _fromJson);
      final error = result.error as ApiException;
      expect(error.apiErrorMessage, 'bad request');
      expect(error.message, 'bad request');
      expect(error.extraAs<CustomError>(), isNotNull);
    });

    test('per-request mapper overrides the client-level one', () async {
      final result = await _client(errorExtraMapper: CustomError.fromJson)
          .get<String>(
            'x',
            fromJson: _fromJson,
            errorExtraMapper: (json) => 'override-${json['code']}',
          );
      expect((result.error as ApiException).extra, 'override-E42');
    });

    test('is null when no mapper is provided', () async {
      final result = await _client().get<String>('x', fromJson: _fromJson);
      final error = result.error as ApiException;
      expect(error.extra, isNull);
      expect(error.extraAs<CustomError>(), isNull);
    });

    test('is null and the message is kept when the mapper throws', () async {
      final result = await _client(
        errorMapper: (json) => json['message'] as String?,
        errorExtraMapper: (json) => throw const FormatException('bad'),
      ).get<String>('x', fromJson: _fromJson);
      final error = result.error as ApiException;
      expect(error.extra, isNull);
      expect(error.apiErrorMessage, 'bad request');
    });

    test('extraAs returns null for a different type', () async {
      final result = await _client(
        errorExtraMapper: CustomError.fromJson,
      ).get<String>('x', fromJson: _fromJson);
      expect(result.error!.extraAs<String>(), isNull);
    });

    test('is exposed on unauthorized requests', () async {
      final result = await _client(
        statusCode: 401,
        errorExtraMapper: CustomError.fromJson,
      ).get<String>('x', fromJson: _fromJson);
      expect(result.error, isA<UnauthorizedRequestException>());
      expect(result.error!.extraAs<CustomError>()!.code, 'E42');
    });

    test('is exposed when Dio rejects with badResponse', () async {
      final result = await _client(
        statusCode: 422,
        reject: true,
        errorExtraMapper: CustomError.fromJson,
      ).get<String>('x', fromJson: _fromJson);
      expect(result.error, isA<UnableToProcessException>());
      expect(result.error!.extraAs<CustomError>()!.code, 'E42');
    });

    test('works for list requests', () async {
      final result = await _client(
        errorExtraMapper: CustomError.fromJson,
      ).getList<String>('x', fromJson: _fromJson);
      expect(result.error!.extraAs<CustomError>(), isNotNull);
    });

    test('works for delete requests', () async {
      final result = await _client(
        errorExtraMapper: CustomError.fromJson,
      ).delete<void>('x');
      expect(result.error!.extraAs<CustomError>(), isNotNull);
    });

    test('works for post requests', () async {
      final result = await _client().post<String>(
        'x',
        fromJson: _fromJson,
        errorExtraMapper: CustomError.fromJson,
      );
      expect(result.error!.extraAs<CustomError>(), isNotNull);
    });

    test('result.errorExtraAs gives direct typed access', () async {
      final failed = await _client(
        errorExtraMapper: CustomError.fromJson,
      ).get<String>('x', fromJson: _fromJson);
      expect(failed.errorExtraAs<CustomError>()!.code, 'E42');
      expect(failed.errorExtraAs<String>(), isNull);

      final ok = await _client(
        statusCode: 200,
        data: {'ok': true},
      ).get<String>('x', fromJson: _fromJson);
      expect(ok.errorExtraAs<CustomError>(), isNull);
    });

    test('extraAs is null for non-API exceptions', () {
      const exception = SendTimeoutException(errorMessage: 'timeout');
      expect(exception.extraAs<Object>(), isNull);
      const NetworkException api = DefaultApiException(
        errorMessage: 'x',
        extra: 'data',
      );
      expect(api.extraAs<String>(), 'data');
    });

    test('is not applied to successful responses', () async {
      final result = await _client(
        statusCode: 200,
        data: {'ok': true},
        errorExtraMapper: (_) => throw StateError('must not be called'),
      ).get<String>('x', fromJson: _fromJson);
      expect(result.isSuccess, isTrue);
    });

    test('is exposed on streaming requests', () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://example.com/',
          validateStatus: (_) => true,
        ),
      )..httpClientAdapter = _ErrorStreamAdapter();
      final client = PlayxNetworkClient(
        dio: dio,
        errorExtraMapper: CustomError.fromJson,
        settings: const PlayxNetworkClientSettings(),
      );
      final result = await client.getStream<String>(
        'x',
        format: PlayxStreamFormat.text,
      );
      expect(result.isError, isTrue);
      expect(result.error!.extraAs<CustomError>()!.code, 'S1');
    });
  });
}
