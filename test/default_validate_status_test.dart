import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';

/// Answers every request with [status] and a small JSON body.
class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.status, this.body);

  final int status;
  final Object body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

const _errorBody = {'message': 'server says no', 'code': 'E1'};

/// A client over a plain [Dio]: it keeps Dio's default `validateStatus`, which
/// throws for anything outside 200-299.
PlayxNetworkClient _client(
  int status, {
  Object body = _errorBody,
  List<int> successRequestCodes = const [200, 201],
  UnauthorizedRequestHandler? onUnauthorized,
}) => PlayxNetworkClient(
  dio: Dio(BaseOptions(baseUrl: 'https://example.com/'))
    ..httpClientAdapter = _JsonAdapter(status, body),
  errorExtraMapper: (json) => json['code'],
  onUnauthorizedRequestReceived: onUnauthorized,
  settings: PlayxNetworkClientSettings(
    successRequestCodes: successRequestCodes,
    useIsolateForMappingJson: false,
    useWorkMangerForMappingJsonInIsolate: false,
  ),
);

String _fromJson(dynamic json) => '$json';

void main() {
  group('default validateStatus: error responses', () {
    for (final status in [404, 422, 500]) {
      test('get $status keeps the API message and extra data', () async {
        final result = await _client(
          status,
        ).get<String>('x', fromJson: _fromJson);
        final error = result.error as ApiException;
        expect(error.statusCode, status);
        expect(error.apiErrorMessage, 'server says no');
        expect(error.extra, 'E1');
      });
    }

    test('stream requests keep the API message and extra data', () async {
      final result = await _client(
        422,
      ).getStream<String>('x', format: PlayxStreamFormat.text);
      final error = result.error as ApiException;
      expect(error, isA<UnableToProcessException>());
      expect(error.apiErrorMessage, 'server says no');
      expect(error.extra, 'E1');
    });

    test('postStream and SSE do too', () async {
      final client = _client(404);
      final post = await client.postStream<String>(
        'x',
        format: PlayxStreamFormat.text,
      );
      final sse = await client.getSse('x');
      for (final result in [post, sse]) {
        final error = result.error as ApiException;
        expect(error, isA<NotFoundException>());
        expect(error.apiErrorMessage, 'server says no');
      }
    });

    test('a 401 on a stream runs the unauthorized callback', () async {
      Response<dynamic>? received;
      final result = await _client(
        401,
        onUnauthorized: (r) => received = r,
      ).getStream<String>('x', format: PlayxStreamFormat.text);
      expect(result.error, isA<UnauthorizedRequestException>());
      expect(received, isNotNull);
    });

    test('a 401 on a stream can skip the callback', () async {
      var called = false;
      await _client(
        401,
        onUnauthorized: (_) => called = true,
      ).getStream<String>(
        'x',
        format: PlayxStreamFormat.text,
        shouldHandleUnauthorizedRequest: false,
      );
      expect(called, isFalse);
    });
  });

  group('default validateStatus: configured success codes', () {
    const codes = [200, 201, 304];
    const body = {'id': 7};

    test('get treats a configured status Dio rejects as a success', () async {
      final result = await _client(
        304,
        body: body,
        successRequestCodes: codes,
      ).get<String>('x', fromJson: (json) => '${json['id']}');
      expect(result.isSuccess, isTrue);
      expect(result.data, '7');
    });

    test('getList and delete do too', () async {
      final client = _client(304, body: [1, 2], successRequestCodes: codes);
      final list = await client.getList<String>('x', fromJson: _fromJson);
      expect(list.data, ['1', '2']);
      final deleted = await client.delete<void>('x');
      expect(deleted.isSuccess, isTrue);
    });

    test('a stream with a configured status produces a stream', () async {
      final result = await _client(
        304,
        body: body,
        successRequestCodes: codes,
      ).getStream<String>('x', format: PlayxStreamFormat.text);
      expect(result.isSuccess, isTrue);
      expect(await result.data!.join(), contains('"id":7'));
    });

    test('statuses that are not configured are still errors', () async {
      final result = await _client(
        500,
        successRequestCodes: codes,
      ).get<String>('x', fromJson: _fromJson);
      expect(result.error, isA<InternalServerErrorException>());
    });

    test('a 400 is always an error, even if configured', () async {
      final result = await _client(
        400,
        successRequestCodes: [200, 400],
      ).get<String>('x', fromJson: _fromJson);
      expect(result.isError, isTrue);
    });

    test('other Dio errors are unaffected', () async {
      final client = PlayxNetworkClient(
        dio: Dio(BaseOptions(baseUrl: 'https://example.com/'))
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) => handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionTimeout,
                ),
              ),
            ),
          ),
        settings: const PlayxNetworkClientSettings(),
      );
      final result = await client.get<String>('x', fromJson: _fromJson);
      expect(result.error, isA<RequestTimeoutException>());
    });
  });
}
