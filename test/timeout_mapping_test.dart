import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/models/exceptions/message/arabic_exception_message.dart';

class _FailingInterceptor extends Interceptor {
  _FailingInterceptor(this.type);

  final DioExceptionType type;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) =>
      handler.reject(DioException(requestOptions: options, type: type));
}

Future<NetworkException?> _errorFor(DioExceptionType type) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/'))
    ..interceptors.add(_FailingInterceptor(type));
  final client = PlayxNetworkClient(
    dio: dio,
    settings: const PlayxNetworkClientSettings(),
  );
  final result = await client.get<String>('x', fromJson: (j) => '$j');
  return result.error;
}

void main() {
  group('timeout mapping', () {
    test('connectionTimeout is a RequestTimeoutException', () async {
      expect(
        await _errorFor(DioExceptionType.connectionTimeout),
        isA<RequestTimeoutException>(),
      );
    });

    test('sendTimeout is a SendTimeoutException', () async {
      expect(
        await _errorFor(DioExceptionType.sendTimeout),
        isA<SendTimeoutException>(),
      );
    });

    test('receiveTimeout is a ReceiveTimeoutException', () async {
      final error = await _errorFor(DioExceptionType.receiveTimeout);
      expect(error, isA<ReceiveTimeoutException>());
      expect(error, isNot(isA<SendTimeoutException>()));
      expect(
        error!.message,
        const DefaultEnglishExceptionMessage().receiveTimeout,
      );
    });

    test('transformTimeout is an UnableToProcessException', () async {
      final error = await _errorFor(DioExceptionType.transformTimeout);
      expect(error, isA<UnableToProcessException>());
      expect(error, isNot(isA<SendTimeoutException>()));
      expect(
        error!.message,
        const DefaultEnglishExceptionMessage().unableToProcess,
      );
    });
  });

  group('receiveTimeout message', () {
    test(
      'defaults to sendTimeout for existing ExceptionMessage subclasses',
      () {
        const legacy = _Legacy();
        expect(legacy.receiveTimeout, legacy.sendTimeout);
      },
    );

    test('English and Arabic have a specific message', () {
      const english = DefaultEnglishExceptionMessage();
      expect(english.receiveTimeout, isNot(english.sendTimeout));
      final arabic = DefaultArabicExceptionMessage();
      expect(arabic.receiveTimeout, isNot(arabic.sendTimeout));
    });
  });
}

class _Legacy extends ExceptionMessage {
  const _Legacy();

  @override
  String get badRequest => 'a';
  @override
  String get conflict => 'a';
  @override
  String get defaultError => 'a';
  @override
  String get emptyResponse => 'a';
  @override
  String get formatException => 'a';
  @override
  String get internalServerError => 'a';
  @override
  String get noInternetConnection => 'a';
  @override
  String get notAcceptable => 'a';
  @override
  String get notFound => 'a';
  @override
  String get requestCancelled => 'a';
  @override
  String get requestTimeout => 'a';
  @override
  String get sendTimeout => 'legacy send timeout';
  @override
  String get serviceUnavailable => 'a';
  @override
  String get unableToProcess => 'a';
  @override
  String get unauthorizedRequest => 'a';
  @override
  String get unexpectedError => 'a';
}
