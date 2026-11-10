import 'package:flutter_test/flutter_test.dart';
import 'package:playx_core/playx_core.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/handler/exception_mapper.dart';
import 'package:playx_network/src/handler/handler_logger.dart';
import 'package:playx_network/src/models/exceptions/message/arabic_exception_message.dart';

const _quiet = PlayxNetworkClientSettings(
  logSettings: PlayxNetworkLoggerSettings(enabled: false),
);

ExceptionMapper _mapper({
  ErrorMapper? errorMapper,
  ErrorExtraMapper? errorExtraMapper,
  UnauthorizedRequestHandler? onUnauthorized,
  PlayxNetworkClientSettings settings = _quiet,
}) => ExceptionMapper(
  errorMapper: errorMapper ?? ExceptionMapper.defaultErrorMessage,
  errorExtraMapper: errorExtraMapper,
  settings: settings,
  onUnauthorizedRequestReceived: onUnauthorized,
  log: HandlerLogger(
    logger: PlayxLogger.initLogger(name: 'mapper-test', setAsDefault: false),
    settings: settings,
  ),
);

Response<dynamic> _response(int status, [dynamic data]) => Response<dynamic>(
  requestOptions: RequestOptions(path: '/x'),
  statusCode: status,
  data: data,
);

DioException _dio(DioExceptionType type, {Response<dynamic>? response}) =>
    DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
      response: response,
    );

void main() {
  group('defaultErrorMessage', () {
    test('reads the message of a default API error', () {
      expect(ExceptionMapper.defaultErrorMessage({'message': 'boom'}), 'boom');
    });

    test('is null for a null body', () {
      expect(ExceptionMapper.defaultErrorMessage(null), isNull);
    });
  });

  group('fromResponse', () {
    test('maps status codes to exceptions', () {
      final mapper = _mapper();
      expect(
        mapper.fromResponse(response: _response(404)),
        isA<NotFoundException>(),
      );
      expect(
        mapper.fromResponse(response: _response(409)),
        isA<ConflictException>(),
      );
      expect(
        mapper.fromResponse(response: _response(500)),
        isA<InternalServerErrorException>(),
      );
      expect(
        mapper.fromResponse(response: _response(418)),
        isA<DefaultApiException>(),
      );
    });

    test('unauthorized codes invoke the callback unless disabled', () {
      Response<dynamic>? received;
      final mapper = _mapper(onUnauthorized: (r) => received = r);

      final response = _response(401);
      expect(
        mapper.fromResponse(response: response),
        isA<UnauthorizedRequestException>(),
      );
      expect(received, same(response));

      received = null;
      mapper.fromResponse(
        response: response,
        shouldHandleUnauthorizedRequest: false,
      );
      expect(received, isNull);
    });

    test('a throwing errorMapper keeps the exception without a message', () {
      final mapper = _mapper(errorMapper: (_) => throw StateError('bad'));
      final error =
          mapper.fromResponse(response: _response(404, {'a': 1}))
              as ApiException;
      expect(error.apiErrorMessage, isNull);
    });

    test('a throwing errorExtraMapper leaves extra null', () {
      final mapper = _mapper(errorExtraMapper: (_) => throw StateError('bad'));
      final error =
          mapper.fromResponse(response: _response(404, {'a': 1}))
              as ApiException;
      expect(error.extra, isNull);
    });

    test('per-request mappers override the client-level ones', () {
      final mapper = _mapper(errorMapper: (_) => 'client');
      final error =
          mapper.fromResponse(
                response: _response(404, {}),
                errorMapper: (_) => 'request',
                errorExtraMapper: (_) => 'extra',
              )
              as ApiException;
      expect(error.apiErrorMessage, 'request');
      expect(error.extra, 'extra');
    });

    test('per-request settings override client-level settings', () {
      final arabic = DefaultArabicExceptionMessage();
      final error = _mapper().fromResponse(
        response: _response(404),
        settings: PlayxNetworkClientSettings(exceptionMessages: arabic),
      );
      expect(error.errorMessage, arabic.notFound);
    });
  });

  group('fromError', () {
    final mapper = _mapper();

    test('maps every DioExceptionType', () {
      expect(
        mapper.fromError(error: _dio(DioExceptionType.cancel)),
        isA<RequestCanceledException>(),
      );
      expect(
        mapper.fromError(error: _dio(DioExceptionType.connectionTimeout)),
        isA<RequestTimeoutException>(),
      );
      expect(
        mapper.fromError(error: _dio(DioExceptionType.sendTimeout)),
        isA<SendTimeoutException>(),
      );
      expect(
        mapper.fromError(error: _dio(DioExceptionType.receiveTimeout)),
        isA<ReceiveTimeoutException>(),
      );
      expect(
        mapper.fromError(error: _dio(DioExceptionType.transformTimeout)),
        isA<UnableToProcessException>(),
      );
      expect(
        mapper.fromError(error: _dio(DioExceptionType.badCertificate)),
        isA<SecureConnectionException>(),
      );
      expect(
        mapper.fromError(error: _dio(DioExceptionType.unknown)),
        isA<UnexpectedErrorException>(),
      );
    });

    test('badResponse maps the response and honours per-request settings', () {
      final arabic = DefaultArabicExceptionMessage();
      final error = mapper.fromError(
        error: _dio(DioExceptionType.badResponse, response: _response(404)),
        settings: PlayxNetworkClientSettings(exceptionMessages: arabic),
      );
      expect(error, isA<NotFoundException>());
      expect(error.errorMessage, arabic.notFound);
    });

    test('non-Dio errors', () {
      expect(
        mapper.fromError(error: const FormatException('x')),
        isA<UnexpectedErrorException>(),
      );
      expect(
        mapper.fromError(error: "type 'X' is not a subtype of type 'Y'"),
        isA<UnableToProcessException>(),
      );
      expect(
        mapper.fromError(error: 'something'),
        isA<UnexpectedErrorException>(),
      );
      expect(mapper.fromError(), isA<UnexpectedErrorException>());
    });
  });

  group('checkOnline', () {
    DioException connectionError() => _dio(DioExceptionType.connectionError);

    test('is null without a callback', () async {
      expect(await _mapper().checkOnline(connectionError()), isNull);
    });

    test('asks the callback only for connection failures', () async {
      var calls = 0;
      final mapper = ExceptionMapper(
        errorMapper: ExceptionMapper.defaultErrorMessage,
        settings: _quiet,
        hasInternetConnection: () {
          calls++;
          return true;
        },
        log: HandlerLogger(
          logger: PlayxLogger.initLogger(
            name: 'mapper-test',
            setAsDefault: false,
          ),
          settings: _quiet,
        ),
      );
      expect(mapper.willCheckOnline(connectionError()), isTrue);
      expect(
        mapper.willCheckOnline(_dio(DioExceptionType.sendTimeout)),
        isFalse,
      );
      expect(await mapper.checkOnline(connectionError()), isTrue);
      expect(
        await mapper.checkOnline(_dio(DioExceptionType.sendTimeout)),
        isNull,
      );
      expect(calls, 1);
    });
  });
}
