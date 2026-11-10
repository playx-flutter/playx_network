import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/models/exceptions/message/arabic_exception_message.dart';
import 'package:playx_network/src/utils/connection_utils.dart';

SocketException _socket(String message, int code, [String os = '']) =>
    SocketException(message, osError: OSError(os, code));

final _refusedLinux = _socket('Connection failed', 111, 'Connection refused');
final _refusedMac = _socket('Connection failed', 61, 'Connection refused');
final _refusedWindows = _socket('Connection failed', 10061);
final _resetLinux = _socket('Connection reset by peer', 104);
final _timedOut = _socket('Connection timed out', 110);
final _networkUnreachable = _socket(
  'Connection failed',
  101,
  'Network is unreachable',
);
final _networkUnreachableMac = _socket('Connection failed', 51);
final _hostLookup = _socket(
  "Failed host lookup: 'api.example.com'",
  7,
  'No address associated with hostname',
);
const _unknownSocket = SocketException('Something odd');

DioException _dioError(Object cause, {DioExceptionType? type}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: type ?? DioExceptionType.connectionError,
  error: cause,
);

const _messages = DefaultEnglishExceptionMessage();

NetworkException _build(
  Object cause, {
  bool? isOnline,
  bool isWeb = false,
  bool? browserOnline,
}) => buildConnectionException(
  error: _dioError(cause),
  messages: _messages,
  isOnline: isOnline,
  isWeb: isWeb,
  browserOnline: () => browserOnline,
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
          response: error.response,
        ),
      );
}

PlayxNetworkClient _client(
  DioException error, {
  FutureOr<bool> Function()? hasInternetConnection,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/'))
    ..interceptors.add(_FailingInterceptor(error));
  return PlayxNetworkClient(
    dio: dio,
    hasInternetConnection: hasInternetConnection,
    settings: const PlayxNetworkClientSettings(
      useIsolateForMappingJson: false,
      useWorkMangerForMappingJsonInIsolate: false,
    ),
  );
}

String _fromJson(dynamic json) => json.toString();

class _MidStreamFailureAdapter implements HttpClientAdapter {
  final controller = StreamController<Uint8List>();

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody(controller.stream, 200);
}

void main() {
  group('classifyConnectionFailure', () {
    test('connection refused / reset / timed out on every platform', () {
      for (final e in [
        _refusedLinux,
        _refusedMac,
        _refusedWindows,
        _resetLinux,
        _timedOut,
      ]) {
        expect(
          classifyConnectionFailure(e),
          ConnectionFailure.serverUnreachable,
          reason: e.toString(),
        );
      }
    });

    test('network unreachable means no internet', () {
      expect(
        classifyConnectionFailure(_networkUnreachable),
        ConnectionFailure.noInternet,
      );
      expect(
        classifyConnectionFailure(_networkUnreachableMac),
        ConnectionFailure.noInternet,
      );
    });

    test('host lookup failures are reported separately', () {
      expect(
        classifyConnectionFailure(_hostLookup),
        ConnectionFailure.hostLookup,
      );
    });

    test('anything else is unknown', () {
      expect(
        classifyConnectionFailure(_unknownSocket),
        ConnectionFailure.unknown,
      );
      expect(
        classifyConnectionFailure(StateError('x')),
        ConnectionFailure.unknown,
      );
      expect(classifyConnectionFailure(null), ConnectionFailure.unknown);
    });
  });

  group('isConnectionFailure', () {
    test('detects connection errors only', () {
      expect(isConnectionFailure(_unknownSocket), isTrue);
      expect(isConnectionFailure(_dioError(_unknownSocket)), isTrue);
      expect(
        isConnectionFailure(
          _dioError(_unknownSocket, type: DioExceptionType.unknown),
        ),
        isTrue,
      );
      expect(
        isConnectionFailure(
          _dioError('x', type: DioExceptionType.connectionTimeout),
        ),
        isFalse,
      );
      expect(
        isConnectionFailure(_dioError('x', type: DioExceptionType.unknown)),
        isFalse,
      );
      expect(isConnectionFailure(StateError('x')), isFalse);
    });
  });

  group('buildConnectionException (native)', () {
    test('refused connection is ServerUnreachable', () {
      expect(_build(_refusedLinux), isA<ServerUnreachableException>());
    });

    test('network unreachable stays NoInternet', () {
      expect(_build(_networkUnreachable), isA<NoInternetConnectionException>());
    });

    test('host lookup failure defaults to NoInternet', () {
      expect(_build(_hostLookup), isA<NoInternetConnectionException>());
    });

    test('unidentified failures keep the previous NoInternet mapping', () {
      expect(_build(_unknownSocket), isA<NoInternetConnectionException>());
      expect(_build(StateError('x')), isA<NoInternetConnectionException>());
    });

    test('isOnline == false always wins', () {
      expect(
        _build(_refusedLinux, isOnline: false),
        isA<NoInternetConnectionException>(),
      );
    });

    test('isOnline == true means the server is unreachable', () {
      for (final e in [_networkUnreachable, _hostLookup, _unknownSocket]) {
        expect(
          _build(e, isOnline: true),
          isA<ServerUnreachableException>(),
          reason: e.toString(),
        );
      }
    });

    test('messages come from ExceptionMessage', () {
      expect(_build(_refusedLinux).message, _messages.serverUnreachable);
      expect(_build(_unknownSocket).message, _messages.noInternetConnection);
    });
  });

  group('buildConnectionException (web)', () {
    test('a blocked request is a CorsException', () {
      expect(
        _build(_unknownSocket, isWeb: true, browserOnline: true),
        isA<CorsException>(),
      );
      expect(_build(_unknownSocket, isWeb: true), isA<CorsException>());
    });

    test('an offline browser is NoInternet', () {
      expect(
        _build(_unknownSocket, isWeb: true, browserOnline: false),
        isA<NoInternetConnectionException>(),
      );
    });

    test('the app callback overrides the browser', () {
      expect(
        _build(
          _unknownSocket,
          isWeb: true,
          browserOnline: true,
          isOnline: false,
        ),
        isA<NoInternetConnectionException>(),
      );
      expect(
        _build(
          _unknownSocket,
          isWeb: true,
          browserOnline: false,
          isOnline: true,
        ),
        isA<CorsException>(),
      );
    });
  });

  group('ExceptionMessage defaults', () {
    test(
      'custom messages without the new getters fall back to defaultError',
      () {
        const custom = _LegacyMessages();
        expect(custom.serverUnreachable, custom.defaultError);
        expect(custom.corsError, custom.defaultError);
      },
    );

    test('English and Arabic messages are specific', () {
      expect(_messages.serverUnreachable, isNot(_messages.defaultError));
      expect(_messages.corsError, contains('CORS'));
      final arabic = DefaultArabicExceptionMessage();
      expect(arabic.serverUnreachable, isNot(arabic.defaultError));
      expect(arabic.corsError, isNot(arabic.defaultError));
    });
  });

  group('PlayxNetworkClient', () {
    test('refused connection is ServerUnreachable', () async {
      final result = await _client(
        _dioError(_refusedLinux),
      ).get<String>('x', fromJson: _fromJson);
      expect(result.error, isA<ServerUnreachableException>());
    });

    test('offline device is still NoInternet', () async {
      final result = await _client(
        _dioError(_networkUnreachable),
      ).get<String>('x', fromJson: _fromJson);
      expect(result.error, isA<NoInternetConnectionException>());
    });

    test('hasInternetConnection == false makes it NoInternet', () async {
      final result = await _client(
        _dioError(_refusedLinux),
        hasInternetConnection: () async => false,
      ).get<String>('x', fromJson: _fromJson);
      expect(result.error, isA<NoInternetConnectionException>());
    });

    test('hasInternetConnection == true makes it ServerUnreachable', () async {
      final result = await _client(
        _dioError(_unknownSocket),
        hasInternetConnection: () => true,
      ).get<String>('x', fromJson: _fromJson);
      expect(result.error, isA<ServerUnreachableException>());
    });

    test('a throwing callback falls back to inspecting the error', () async {
      final result = await _client(
        _dioError(_refusedLinux),
        hasInternetConnection: () => throw StateError('plugin failed'),
      ).get<String>('x', fromJson: _fromJson);
      expect(result.error, isA<ServerUnreachableException>());
    });

    test('the callback is only used for connection failures', () async {
      var calls = 0;
      Future<bool> check() async {
        calls++;
        return false;
      }

      final timeout = await _client(
        _dioError('x', type: DioExceptionType.connectionTimeout),
        hasInternetConnection: check,
      ).get<String>('x', fromJson: _fromJson);
      expect(timeout.error, isA<RequestTimeoutException>());
      expect(calls, 0);

      await _client(
        _dioError(_refusedLinux),
        hasInternetConnection: check,
      ).get<String>('x', fromJson: _fromJson);
      expect(calls, 1);
    });

    test('works for list and delete requests', () async {
      final client = _client(_dioError(_refusedLinux));
      expect(
        (await client.getList<String>('x', fromJson: _fromJson)).error,
        isA<ServerUnreachableException>(),
      );
      expect(
        (await client.delete<void>('x')).error,
        isA<ServerUnreachableException>(),
      );
    });

    test('stream request failing to connect is classified', () async {
      final result = await _client(
        _dioError(_refusedLinux),
        hasInternetConnection: () async => true,
      ).getStream<String>('x', format: PlayxStreamFormat.text);
      expect(result.error, isA<ServerUnreachableException>());
    });

    test(
      'a stream that drops mid-way uses the callback and still completes',
      () async {
        final adapter = _MidStreamFailureAdapter();
        final dio = Dio(
          BaseOptions(
            baseUrl: 'https://example.com/',
            validateStatus: (_) => true,
          ),
        )..httpClientAdapter = adapter;
        final client = PlayxNetworkClient(
          dio: dio,
          hasInternetConnection: () async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return false;
          },
          settings: const PlayxNetworkClientSettings(),
        );

        final result = await client.getStream<String>(
          'x',
          format: PlayxStreamFormat.text,
        );
        final errors = <Object>[];
        final done = Completer<void>();
        result.data!.listen((_) {}, onError: errors.add, onDone: done.complete);

        adapter.controller.add(Uint8List.fromList([97]));
        adapter.controller.addError(_resetLinux);
        await adapter.controller.close();

        await done.future.timeout(const Duration(seconds: 2));
        expect(errors, hasLength(1));
        expect(errors.single, isA<NoInternetConnectionException>());
      },
    );
  });
}

class _LegacyMessages extends ExceptionMessage {
  const _LegacyMessages();

  @override
  String get badRequest => 'a';
  @override
  String get conflict => 'a';
  @override
  String get defaultError => 'legacy default';
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
  String get sendTimeout => 'a';
  @override
  String get serviceUnavailable => 'a';
  @override
  String get unableToProcess => 'a';
  @override
  String get unauthorizedRequest => 'a';
  @override
  String get unexpectedError => 'a';
}
