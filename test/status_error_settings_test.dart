import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/models/exceptions/message/arabic_exception_message.dart';

class _StatusInterceptor extends Interceptor {
  _StatusInterceptor(this.statusCode);

  final int statusCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) =>
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: statusCode,
          data: {'message': 'server says no'},
        ),
      );
}

PlayxNetworkClient _client(int statusCode) => PlayxNetworkClient(
  dio: Dio(BaseOptions(baseUrl: 'https://example.com/'))
    ..interceptors.add(_StatusInterceptor(statusCode)),
  settings: const PlayxNetworkClientSettings(
    useIsolateForMappingJson: false,
    useWorkMangerForMappingJsonInIsolate: false,
  ),
);

String _fromJson(dynamic json) => '$json';

/// Error responses must honour the per-request `settings`, exactly like every
/// other part of the result handling.
void main() {
  final arabic = DefaultArabicExceptionMessage();
  final perRequest = PlayxNetworkClientSettings(
    exceptionMessages: arabic,
    useIsolateForMappingJson: false,
    useWorkMangerForMappingJsonInIsolate: false,
  );

  group('per-request settings on error status codes', () {
    test('custom exception messages are used by get', () async {
      final result = await _client(
        404,
      ).get<String>('x', fromJson: _fromJson, settings: perRequest);
      expect(result.error, isA<NotFoundException>());
      expect(result.error!.errorMessage, arabic.notFound);
    });

    test('custom exception messages are used by getList', () async {
      final result = await _client(
        500,
      ).getList<String>('x', fromJson: _fromJson, settings: perRequest);
      expect(result.error!.errorMessage, arabic.internalServerError);
    });

    test('custom exception messages are used by delete', () async {
      final result = await _client(409).delete<void>('x', settings: perRequest);
      expect(result.error!.errorMessage, arabic.conflict);
    });

    test('shouldShowApiErrors can be turned off per request', () async {
      final client = PlayxNetworkClient(
        dio: Dio(BaseOptions(baseUrl: 'https://example.com/'))
          ..interceptors.add(_StatusInterceptor(404)),
        errorMapper: (json) => json['message'] as String?,
        settings: const PlayxNetworkClientSettings(),
      );
      final shown = await client.get<String>('x', fromJson: _fromJson);
      expect(shown.error!.message, 'server says no');

      final hidden = await client.get<String>(
        'x',
        fromJson: _fromJson,
        settings: const PlayxNetworkClientSettings(shouldShowApiErrors: false),
      );
      expect(hidden.error!.message, isNot('server says no'));
    });

    test('unauthorizedRequestCodes can be overridden per request', () async {
      final defaults = await _client(404).get<String>('x', fromJson: _fromJson);
      expect(defaults.error, isA<NotFoundException>());

      final overridden = await _client(404).get<String>(
        'x',
        fromJson: _fromJson,
        settings: const PlayxNetworkClientSettings(
          unauthorizedRequestCodes: [404],
          useIsolateForMappingJson: false,
          useWorkMangerForMappingJsonInIsolate: false,
        ),
      );
      expect(overridden.error, isA<UnauthorizedRequestException>());
    });
  });
}
