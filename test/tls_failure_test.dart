import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/models/exceptions/message/arabic_exception_message.dart';
import 'package:playx_network/src/utils/connection_utils.dart';

DioException _dioError(DioExceptionType type, [Object? cause]) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type,
  error: cause,
);

class _FailingInterceptor extends Interceptor {
  _FailingInterceptor(this.error);

  final DioException error;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) =>
      handler.reject(
        DioException(
          requestOptions: options,
          type: error.type,
          error: error.error,
        ),
      );
}

PlayxNetworkClient _client(
  DioException error, {
  FutureOr<bool> Function()? hasInternetConnection,
}) => PlayxNetworkClient(
  dio: Dio(BaseOptions(baseUrl: 'https://example.com/'))
    ..interceptors.add(_FailingInterceptor(error)),
  hasInternetConnection: hasInternetConnection,
  settings: const PlayxNetworkClientSettings(),
);

String _fromJson(dynamic json) => '$json';

void main() {
  group('isTlsFailure', () {
    test('detects TLS errors however Dio wraps them', () {
      expect(isTlsFailure(const HandshakeException('bad')), isTrue);
      expect(isTlsFailure(const CertificateException('expired')), isTrue);
      expect(isTlsFailure(_dioError(DioExceptionType.badCertificate)), isTrue);
      expect(
        isTlsFailure(
          _dioError(DioExceptionType.unknown, const HandshakeException('bad')),
        ),
        isTrue,
      );
      expect(
        isTlsFailure(
          _dioError(
            DioExceptionType.connectionError,
            const HandshakeException('x'),
          ),
        ),
        isTrue,
      );
    });

    test('ignores everything else', () {
      expect(isTlsFailure(const SocketException('x')), isFalse);
      expect(
        isTlsFailure(_dioError(DioExceptionType.connectionTimeout)),
        isFalse,
      );
      expect(isTlsFailure(_dioError(DioExceptionType.unknown, 'x')), isFalse);
      expect(isTlsFailure(null), isFalse);
    });

    test('a TLS failure is not a connection failure', () {
      expect(
        isConnectionFailure(
          _dioError(
            DioExceptionType.connectionError,
            const HandshakeException('x'),
          ),
        ),
        isFalse,
      );
      expect(
        isConnectionFailure(
          _dioError(
            DioExceptionType.connectionError,
            const SocketException('x'),
          ),
        ),
        isTrue,
      );
    });
  });

  group('PlayxNetworkClient', () {
    test('badCertificate is a SecureConnectionException', () async {
      final result = await _client(
        _dioError(DioExceptionType.badCertificate),
      ).get<String>('x', fromJson: _fromJson);
      expect(result.error, isA<SecureConnectionException>());
      expect(
        result.error!.message,
        const DefaultEnglishExceptionMessage().secureConnectionError,
      );
    });

    test(
      'a failed handshake reported as unknown is a SecureConnection error',
      () async {
        final result = await _client(
          _dioError(DioExceptionType.unknown, const HandshakeException('x')),
        ).get<String>('x', fromJson: _fromJson);
        expect(result.error, isA<SecureConnectionException>());
      },
    );

    test(
      'a failed handshake reported as connectionError is not "no internet"',
      () async {
        final result = await _client(
          _dioError(
            DioExceptionType.connectionError,
            const HandshakeException('x'),
          ),
        ).get<String>('x', fromJson: _fromJson);
        expect(result.error, isA<SecureConnectionException>());
        expect(result.error, isNot(isA<NoInternetConnectionException>()));
      },
    );

    test('hasInternetConnection is not called for TLS failures', () async {
      var calls = 0;
      await _client(
        _dioError(
          DioExceptionType.connectionError,
          const HandshakeException('x'),
        ),
        hasInternetConnection: () {
          calls++;
          return false;
        },
      ).get<String>('x', fromJson: _fromJson);
      expect(calls, 0);
    });

    test('other unknown errors are still UnexpectedErrorException', () async {
      final result = await _client(
        _dioError(DioExceptionType.unknown, StateError('x')),
      ).get<String>('x', fromJson: _fromJson);
      expect(result.error, isA<UnexpectedErrorException>());
    });

    test('works for list, delete and stream requests', () async {
      final client = _client(_dioError(DioExceptionType.badCertificate));
      expect(
        (await client.getList<String>('x', fromJson: _fromJson)).error,
        isA<SecureConnectionException>(),
      );
      expect(
        (await client.delete<void>('x')).error,
        isA<SecureConnectionException>(),
      );
      expect(
        (await client.getStream<String>(
          'x',
          format: PlayxStreamFormat.text,
        )).error,
        isA<SecureConnectionException>(),
      );
    });
  });

  group('secureConnectionError message', () {
    test('English and Arabic are specific', () {
      const english = DefaultEnglishExceptionMessage();
      expect(english.secureConnectionError, isNot(english.defaultError));
      final arabic = DefaultArabicExceptionMessage();
      expect(arabic.secureConnectionError, isNot(arabic.defaultError));
    });
  });
}
