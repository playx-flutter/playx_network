import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';
import 'package:talker/talker.dart';

/// Answers with a small JSON body and remembers the last request.
class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? last;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode({'ok': true})),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

String _fromJson(dynamic json) => '$json';

PlayxNetworkLoggerSettings _loggingTo(Talker talker, {bool enabled = true}) =>
    PlayxNetworkLoggerSettings(enabled: enabled, talker: talker);

void main() {
  group('Dio.copyWith', () {
    test('does not duplicate the default interceptors', () {
      final dio = Dio();
      final copy = dio.copyWith();
      expect(copy.interceptors.length, dio.interceptors.length);
      expect(copy.copyWith().interceptors.length, dio.interceptors.length);
    });

    test('keeps custom interceptors, options, adapter and transformer', () {
      final adapter = _RecordingAdapter();
      final transformer = BackgroundTransformer();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
        ..httpClientAdapter = adapter
        ..transformer = transformer
        ..interceptors.add(InterceptorsWrapper());
      final copy = dio.copyWith();
      expect(copy.options.baseUrl, 'https://example.com');
      expect(copy.httpClientAdapter, same(adapter));
      expect(copy.transformer, same(transformer));
      expect(copy.interceptors.length, dio.interceptors.length);
    });

    test('can replace each part', () {
      final dio = Dio();
      final adapter = _RecordingAdapter();
      final transformer = BackgroundTransformer();
      final interceptor = InterceptorsWrapper();
      final copy = dio.copyWith(
        options: BaseOptions(baseUrl: 'https://other.com'),
        httpClientAdapter: adapter,
        transformer: transformer,
        interceptors: [interceptor],
      );
      expect(copy.options.baseUrl, 'https://other.com');
      expect(copy.httpClientAdapter, same(adapter));
      expect(copy.transformer, same(transformer));
      expect(copy.interceptors.single, same(interceptor));
    });
  });

  group('createDefaultDioClient', () {
    test('accepts every status code so the library can decide', () {
      final dio = PlayxNetworkClient.createDefaultDioClient(
        baseUrl: 'https://example.com',
      );
      expect(dio.options.baseUrl, 'https://example.com');
      expect(dio.options.validateStatus(500), isTrue);
      expect(dio.options.validateStatus(null), isTrue);
      expect(dio.options.followRedirects, isTrue);
      expect(dio.options.connectTimeout, const Duration(seconds: 30));
    });
  });

  group('per-request log settings', () {
    PlayxNetworkClient clientLoggingTo(
      Talker talker,
      _RecordingAdapter adapter, {
      bool enabled = true,
    }) => PlayxNetworkClient(
      dio: Dio(BaseOptions(baseUrl: 'https://example.com/'))
        ..httpClientAdapter = adapter,
      settings: PlayxNetworkClientSettings(
        logSettings: _loggingTo(talker, enabled: enabled),
      ),
    );

    test('the client-level logger logs by default', () async {
      final talker = Talker();
      await clientLoggingTo(
        talker,
        _RecordingAdapter(),
      ).get<String>('x', fromJson: _fromJson);
      expect(talker.history, isNotEmpty);
    });

    test('a request can turn logging off', () async {
      final talker = Talker();
      await clientLoggingTo(talker, _RecordingAdapter()).get<String>(
        'x',
        fromJson: _fromJson,
        settings: PlayxNetworkClientSettings(
          logSettings: _loggingTo(talker, enabled: false),
        ),
      );
      expect(talker.history, isEmpty);
    });

    test('a request can log to its own talker', () async {
      final clientTalker = Talker();
      final requestTalker = Talker();
      await clientLoggingTo(clientTalker, _RecordingAdapter()).get<String>(
        'x',
        fromJson: _fromJson,
        settings: PlayxNetworkClientSettings(
          logSettings: _loggingTo(requestTalker),
        ),
      );
      expect(requestTalker.history, isNotEmpty);
      expect(clientTalker.history, isEmpty);
    });

    test(
      'a request can turn logging on for a client that has it off',
      () async {
        final clientTalker = Talker();
        final requestTalker = Talker();
        await clientLoggingTo(
          clientTalker,
          _RecordingAdapter(),
          enabled: false,
        ).get<String>(
          'x',
          fromJson: _fromJson,
          settings: PlayxNetworkClientSettings(
            logSettings: _loggingTo(requestTalker),
          ),
        );
        expect(requestTalker.history, isNotEmpty);
        expect(clientTalker.history, isEmpty);
      },
    );

    test(
      'the original Dio keeps its own logger after a per-request override',
      () async {
        final talker = Talker();
        final client = clientLoggingTo(talker, _RecordingAdapter());
        await client.get<String>(
          'x',
          fromJson: _fromJson,
          settings: PlayxNetworkClientSettings(
            logSettings: _loggingTo(Talker()),
          ),
        );
        expect(talker.history, isEmpty);
        await client.get<String>('x', fromJson: _fromJson);
        expect(talker.history, isNotEmpty);
      },
    );
  });

  group('custom headers and query', () {
    PlayxNetworkClient clientWith(_RecordingAdapter adapter) =>
        PlayxNetworkClient(
          dio: Dio(BaseOptions(baseUrl: 'https://example.com/'))
            ..httpClientAdapter = adapter,
          customHeaders: () async => {'authorization': 'token'},
          customQuery: () => {'lang': 'en'},
          settings: const PlayxNetworkClientSettings(),
        );

    test('are attached and can be overridden by the request', () async {
      final adapter = _RecordingAdapter();
      await clientWith(adapter).get<String>(
        'x',
        fromJson: _fromJson,
        headers: {'authorization': 'override', 'x-extra': '1'},
        query: {'lang': 'ar', 'page': 2},
      );
      expect(adapter.last!.headers['authorization'], 'override');
      expect(adapter.last!.headers['x-extra'], '1');
      expect(adapter.last!.queryParameters, {'lang': 'ar', 'page': 2});
    });

    test('can be skipped per request', () async {
      final adapter = _RecordingAdapter();
      await clientWith(adapter).get<String>(
        'x',
        fromJson: _fromJson,
        attachCustomHeaders: false,
        attachCustomQuery: false,
      );
      expect(adapter.last!.headers.containsKey('authorization'), isFalse);
      expect(adapter.last!.queryParameters, isEmpty);
    });

    test('caller options replace the headers instead of merging', () async {
      // Documented behaviour: "custom options which override headers and
      // custom headers". The custom query is still attached.
      final adapter = _RecordingAdapter();
      await clientWith(adapter).get<String>(
        'x',
        fromJson: _fromJson,
        options: Options(headers: {'only': 'mine'}),
      );
      expect(adapter.last!.headers['only'], 'mine');
      expect(adapter.last!.headers.containsKey('authorization'), isFalse);
      expect(adapter.last!.queryParameters, {'lang': 'en'});
    });

    test('every HTTP method attaches them', () async {
      final adapter = _RecordingAdapter();
      final client = clientWith(adapter);
      final calls = <String, Future<NetworkResult<Object?>>>{
        'POST': client.post<Object?>('x', fromJson: (j) => j),
        'PUT': client.put<Object?>('x', fromJson: (j) => j),
        'PATCH': client.patch<Object?>('x', fromJson: (j) => j),
        'DELETE': client.delete<Object?>('x', fromJson: (j) => j),
      };
      for (final entry in calls.entries) {
        await entry.value;
      }
      expect(adapter.last!.headers['authorization'], 'token');
      expect(adapter.last!.queryParameters, {'lang': 'en'});
    });
  });
}
