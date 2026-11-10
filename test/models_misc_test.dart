import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/models/exceptions/message/arabic_exception_message.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

void main() {
  group('PlayxCancelTokenManager', () {
    late PlayxCancelTokenManager manager;
    setUp(() => manager = PlayxCancelTokenManager());

    test('returns a fresh token for a new tag', () {
      final token = manager.getToken('a');
      expect(token.isCancelled, isFalse);
    });

    test('cancels the previous request with the same tag by default', () {
      final first = manager.getToken('a');
      final second = manager.getToken('a');
      expect(first.isCancelled, isTrue);
      expect(second.isCancelled, isFalse);
      expect(second, isNot(same(first)));
    });

    test('cancelOld: false shares the running token', () {
      final first = manager.getToken('a');
      final second = manager.getToken('a', cancelOld: false);
      expect(second, same(first));
      expect(first.isCancelled, isFalse);
    });

    test('replaces a token that was already cancelled', () {
      final first = manager.getToken('a')..cancel();
      final second = manager.getToken('a', cancelOld: false);
      expect(second, isNot(same(first)));
      expect(second.isCancelled, isFalse);
    });

    test('tags are independent', () {
      final a = manager.getToken('a');
      final b = manager.getToken('b');
      manager.cancelRequests('a');
      expect(a.isCancelled, isTrue);
      expect(b.isCancelled, isFalse);
    });

    test('cancelRequests passes the reason and forgets the tag', () {
      final token = manager.getToken('a');
      manager.cancelRequests('a', reason: 'screen closed');
      expect(token.isCancelled, isTrue);
      expect(token.cancelError!.error, 'screen closed');
      // The tag is gone, so a new token is created without cancelling anything.
      expect(manager.getToken('a').isCancelled, isFalse);
    });

    test('cancelRequests ignores unknown and already cancelled tags', () {
      manager.cancelRequests('missing');
      final token = manager.getToken('a')..cancel('first');
      manager.cancelRequests('a', reason: 'second');
      expect(token.cancelError!.error, 'first');
    });

    test('cancelAllRequests cancels every token', () {
      final a = manager.getToken('a');
      final b = manager.getToken('b');
      final done = manager.getToken('c')..cancel();
      manager.cancelAllRequests(reason: 'logout');
      expect(a.isCancelled && b.isCancelled && done.isCancelled, isTrue);
      expect(a.cancelError!.error, 'logout');
      expect(manager.getToken('a').isCancelled, isFalse);
    });
  });

  group('PlayxNetworkLoggerSettings', () {
    test('equal settings are equal and unequal ones are not', () {
      expect(
        const PlayxNetworkLoggerSettings(),
        const PlayxNetworkLoggerSettings(),
      );
      expect(
        const PlayxNetworkLoggerSettings(enabled: false),
        isNot(const PlayxNetworkLoggerSettings()),
      );
      expect(
        const PlayxNetworkLoggerSettings().toString(),
        contains('PlayxNetworkLoggerSettings'),
      );
    });

    test('copyWith changes only the given fields', () {
      const base = PlayxNetworkLoggerSettings();
      final changed = base.copyWith(
        enabled: false,
        printResponseData: false,
        printResponseHeaders: true,
        printResponseMessage: false,
        printResponseRedirects: true,
        printResponseTime: true,
        printErrorData: false,
        printErrorHeaders: true,
        printErrorMessage: false,
        printRequestData: false,
        printRequestHeaders: true,
        printRequestExtra: true,
        enableColors: false,
        hiddenHeaders: {'authorization'},
      );
      expect(changed, isNot(base));
      expect(changed.enabled, isFalse);
      expect(changed.printResponseHeaders, isTrue);
      expect(changed.hiddenHeaders, {'authorization'});
      expect(changed.enableColors, isFalse);
      expect(base.copyWith(), base);
    });

    test('copyWith keeps and replaces filters and the talker', () {
      bool request(RequestOptions options) => true;
      bool response(Response response) => true;
      bool error(DioException error) => true;
      final talker = Talker();
      final changed = const PlayxNetworkLoggerSettings().copyWith(
        requestFilter: request,
        responseFilter: response,
        errorFilter: error,
        talker: talker,
      );
      expect(changed.requestFilter, same(request));
      expect(changed.responseFilter, same(response));
      expect(changed.errorFilter, same(error));
      expect(changed.talker, same(talker));
      expect(changed.copyWith().talker, same(talker));
    });

    test('builds a TalkerDioLogger, with or without a custom talker', () {
      expect(
        const PlayxNetworkLoggerSettings().buildTalkerDioLogger(),
        isA<TalkerDioLogger>(),
      );
      expect(
        PlayxNetworkLoggerSettings(talker: Talker()).buildTalkerDioLogger(),
        isA<TalkerDioLogger>(),
      );
    });
  });

  group('ApiException.fromStatusCode', () {
    const messages = DefaultEnglishExceptionMessage();

    ApiException forCode(int code) => ApiException.fromStatusCode(
      statusCode: code,
      exceptionMessages: messages,
      apiErrorMessage: 'from api',
    );

    test('maps known status codes to their exception', () {
      expect(forCode(400), isA<DefaultApiException>());
      expect(forCode(404), isA<NotFoundException>());
      expect(forCode(408), isA<RequestTimeoutException>());
      expect(forCode(409), isA<ConflictException>());
      expect(forCode(422), isA<UnableToProcessException>());
      expect(forCode(500), isA<InternalServerErrorException>());
      expect(forCode(503), isA<ServiceUnavailableException>());
    });

    test('unknown status codes are a DefaultApiException', () {
      expect(forCode(418), isA<DefaultApiException>());
      expect(forCode(-1).statusCode, -1);
    });

    test('keeps the status code, messages and extra data', () {
      final error = ApiException.fromStatusCode(
        statusCode: 404,
        exceptionMessages: messages,
        apiErrorMessage: 'user missing',
        extra: {'id': 1},
      );
      expect(error.statusCode, 404);
      expect(error.errorMessage, messages.notFound);
      expect(error.apiErrorMessage, 'user missing');
      expect(error.extra, {'id': 1});
    });

    test('message prefers the API message only when it may be shown', () {
      expect(forCode(404).message, 'from api');
      final hidden = ApiException.fromStatusCode(
        statusCode: 404,
        exceptionMessages: messages,
        apiErrorMessage: 'from api',
        shouldShowApiErrors: false,
      );
      expect(hidden.message, messages.notFound);
      final noApiMessage = ApiException.fromStatusCode(
        statusCode: 404,
        exceptionMessages: messages,
      );
      expect(noApiMessage.message, messages.notFound);
    });
  });

  group('exception defaults', () {
    test('API exceptions have their conventional status codes', () {
      expect(
        const UnauthorizedRequestException(errorMessage: '').statusCode,
        401,
      );
      expect(const NotFoundException(errorMessage: '').statusCode, 404);
      expect(const ConflictException(errorMessage: '').statusCode, 409);
      expect(const RequestTimeoutException(errorMessage: '').statusCode, 408);
      expect(const UnableToProcessException(errorMessage: '').statusCode, 422);
      expect(
        const InternalServerErrorException(errorMessage: '').statusCode,
        500,
      );
      expect(
        const ServiceUnavailableException(errorMessage: '').statusCode,
        503,
      );
      expect(const EmptyResponseException(errorMessage: '').statusCode, 204);
      expect(const DefaultApiException(errorMessage: '').statusCode, 400);
    });

    test('every exception exposes its message', () {
      const exceptions = <NetworkException>[
        SendTimeoutException(errorMessage: 'a'),
        ReceiveTimeoutException(errorMessage: 'a'),
        RequestCanceledException(errorMessage: 'a'),
        NoInternetConnectionException(errorMessage: 'a'),
        ServerUnreachableException(errorMessage: 'a'),
        CorsException(errorMessage: 'a'),
        SecureConnectionException(errorMessage: 'a'),
        InvalidFormatException(errorMessage: 'a'),
        UnexpectedErrorException(errorMessage: 'a'),
      ];
      for (final exception in exceptions) {
        expect(exception.message, 'a', reason: '${exception.runtimeType}');
        expect(exception.shouldShowApiError, isTrue);
        expect(exception.extraAs<Object>(), isNull);
      }
    });
  });

  group('exception messages', () {
    List<String> all(ExceptionMessage m) => [
      m.requestCancelled,
      m.unauthorizedRequest,
      m.badRequest,
      m.notFound,
      m.notAcceptable,
      m.requestTimeout,
      m.sendTimeout,
      m.receiveTimeout,
      m.conflict,
      m.internalServerError,
      m.serviceUnavailable,
      m.noInternetConnection,
      m.serverUnreachable,
      m.corsError,
      m.secureConnectionError,
      m.formatException,
      m.unableToProcess,
      m.defaultError,
      m.unexpectedError,
      m.emptyResponse,
    ];

    test('English messages are all provided', () {
      for (final message in all(const DefaultEnglishExceptionMessage())) {
        expect(message.trim(), isNotEmpty);
      }
    });

    test('Arabic messages are all provided and differ from English', () {
      final arabic = DefaultArabicExceptionMessage();
      final english = all(const DefaultEnglishExceptionMessage());
      final translated = all(arabic);
      for (var i = 0; i < translated.length; i++) {
        expect(translated[i].trim(), isNotEmpty);
        expect(translated[i], isNot(english[i]), reason: 'message #$i');
      }
    });
  });
}
