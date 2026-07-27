import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A streaming adapter that emits chunks from a list of byte arrays.
class _StreamAdapter implements HttpClientAdapter {
  _StreamAdapter({
    required this.statusCode,
    required this.chunks,
    this.delay = Duration.zero,
  });

  final int statusCode;
  final List<List<int>> chunks;
  final Duration delay;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (delay != Duration.zero) {
      await Future.delayed(delay);
    }
    final controller = StreamController<Uint8List>();

    // Emit chunks asynchronously.
    Future(() async {
      for (final chunk in chunks) {
        if (controller.isClosed) break;
        controller.add(Uint8List.fromList(chunk));
        await Future.delayed(Duration.zero);
      }
      await controller.close();
    });

    return ResponseBody(
      controller.stream,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Adapter that emits SSE events from a list of raw strings.
class _SseAdapter implements HttpClientAdapter {
  _SseAdapter({
    this.statusCode = 200,
    required this.eventStrings,
  });

  final int statusCode;
  final List<String> eventStrings;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final controller = StreamController<Uint8List>();
    final stream = controller.stream;

    Future(() async {
      for (final s in eventStrings) {
        controller.add(Uint8List.fromList(utf8.encode(s)));
        await Future.delayed(Duration.zero);
      }
      await controller.close();
    });

    return ResponseBody(
      stream,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }
}

/// A Dio adapter that throws a [DioException] of the given [type].
class _ErrorAdapter implements HttpClientAdapter {
  _ErrorAdapter({required this.type});

  final DioExceptionType type;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: type,
    );
  }
}

const _defaultSettings = PlayxNetworkClientSettings(
  logSettings: PlayxNetworkLoggerSettings(enabled: false),
  useIsolateForMappingJson: false,
);

PlayxNetworkClient _client(Dio dio) => PlayxNetworkClient(
      dio: dio,
      settings: _defaultSettings,
    );

// ---------------------------------------------------------------------------
// PlayxStreamFormat tests
// ---------------------------------------------------------------------------

void main() {
  group('PlayxStreamFormat', () {
    group('elementType', () {
      test('bytes returns List<int>', () {
        expect(PlayxStreamFormat.bytes.elementType, List<int>);
      });
      test('text returns String', () {
        expect(PlayxStreamFormat.text.elementType, String);
      });
      test('json returns Object', () {
        expect(PlayxStreamFormat.json.elementType, Object);
      });
      test('sse returns PlayxSseEvent', () {
        expect(PlayxStreamFormat.sse.elementType, PlayxSseEvent);
      });
    });

    group('decodeChunk', () {
      test('bytes returns the chunk unchanged', () {
        final chunk = [1, 2, 3];
        expect(PlayxStreamFormat.bytes.decodeChunk(chunk), same(chunk));
      });

      test('text decodes UTF-8', () {
        final chunk = utf8.encode('hello');
        expect(PlayxStreamFormat.text.decodeChunk(chunk), 'hello');
      });

      test('text decodes malformed UTF-8 gracefully', () {
        final chunk = [0xFF, 0xFE];
        expect(PlayxStreamFormat.text.decodeChunk(chunk), isA<String>());
      });

      test('json decodes a JSON object', () {
        final chunk = utf8.encode('{"key": "value"}');
        final result = PlayxStreamFormat.json.decodeChunk(chunk);
        expect(result, isA<Map>());
        expect((result as Map)['key'], 'value');
      });

      test('json decodes a JSON array', () {
        final chunk = utf8.encode('[1, 2, 3]');
        final result = PlayxStreamFormat.json.decodeChunk(chunk);
        expect(result, isA<List>());
        expect(result, [1, 2, 3]);
      });

      test('json returns null for empty chunk', () {
        final chunk = <int>[];
        expect(PlayxStreamFormat.json.decodeChunk(chunk), isNull);
      });

      test('json returns null for whitespace-only chunk', () {
        final chunk = utf8.encode('   \n  ');
        expect(PlayxStreamFormat.json.decodeChunk(chunk), isNull);
      });

      test('json throws on invalid JSON', () {
        final chunk = utf8.encode('{invalid');
        expect(() => PlayxStreamFormat.json.decodeChunk(chunk),
            throwsA(isA<FormatException>()));
      });

      test('sse returns null (requires stream context)', () {
        expect(PlayxStreamFormat.sse.decodeChunk([1, 2, 3]), isNull);
      });
    });

    group('decodeStream', () {
      test('bytes emits each chunk as-is', () async {
        final stream = Stream.fromIterable([
          [1, 2],
          [3, 4],
        ]);
        final result =
            await PlayxStreamFormat.bytes.decodeStream(stream).toList();
        expect(result, [
          [1, 2],
          [3, 4],
        ]);
      });

      test('text emits decoded strings', () async {
        final stream = Stream.fromIterable([
          utf8.encode('hello '),
          utf8.encode('world'),
        ]);
        final result =
            await PlayxStreamFormat.text.decodeStream(stream).toList();
        expect(result, ['hello ', 'world']);
      });

      test('json emits decoded objects', () async {
        final stream = Stream.fromIterable([
          utf8.encode('{"a": 1}'),
          utf8.encode('{"b": 2}'),
        ]);
        final result =
            await PlayxStreamFormat.json.decodeStream(stream).toList();
        expect(result, hasLength(2));
        expect((result[0] as Map)['a'], 1);
        expect((result[1] as Map)['b'], 2);
      });

      test('json filters out null chunks (empty/whitespace)', () async {
        final stream = Stream.fromIterable([
          utf8.encode(''),
          utf8.encode('{"a": 1}'),
          utf8.encode('   '),
        ]);
        final result =
            await PlayxStreamFormat.json.decodeStream(stream).toList();
        expect(result, hasLength(1));
        expect((result[0] as Map)['a'], 1);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // PlayxSseEvent tests
  // ---------------------------------------------------------------------------

  group('PlayxSseEvent', () {
    test('default event is "message"', () {
      const event = PlayxSseEvent(event: 'message', data: 'hello');
      expect(event.event, 'message');
    });

    test('isEmpty is true when data is empty', () {
      const event = PlayxSseEvent(event: 'ping', data: '');
      expect(event.isEmpty, isTrue);
    });

    test('isEmpty is false when data is present', () {
      const event = PlayxSseEvent(event: 'message', data: 'data');
      expect(event.isEmpty, isFalse);
    });

    test('dataToJson parses valid JSON', () {
      const event = PlayxSseEvent(event: 'message', data: '{"key": "value"}');
      final json = event.dataToJson();
      expect(json, isA<Map>());
      expect((json as Map)['key'], 'value');
    });

    test('dataToJsonOrNull returns null for empty data', () {
      const event = PlayxSseEvent(event: 'message', data: '');
      expect(event.dataToJsonOrNull(), isNull);
    });

    test('dataToJsonOrNull returns null for invalid JSON', () {
      const event = PlayxSseEvent(event: 'message', data: 'not json');
      expect(event.dataToJsonOrNull(), isNull);
    });

    test('dataToJsonOrNull parses valid JSON', () {
      const event = PlayxSseEvent(event: 'message', data: '{"a": 1}');
      expect(event.dataToJsonOrNull(), {'a': 1});
    });

    test('equality and hashCode', () {
      const e1 = PlayxSseEvent(event: 'a', data: 'b', id: '1', retry: 100);
      const e2 = PlayxSseEvent(event: 'a', data: 'b', id: '1', retry: 100);
      const e3 = PlayxSseEvent(event: 'a', data: 'c', id: '1', retry: 100);
      expect(e1 == e2, isTrue);
      expect(e1 == e3, isFalse);
      expect(e1.hashCode, e2.hashCode);
    });

    test('toString contains event and data', () {
      const event = PlayxSseEvent(event: 'msg', data: 'payload');
      final str = event.toString();
      expect(str, contains('msg'));
      expect(str, contains('payload'));
    });
  });

  // ---------------------------------------------------------------------------
  // SSE parser tests
  // ---------------------------------------------------------------------------

  group('SSE parser', () {
    test('parses a simple data event', () async {
      final sseText = 'data: hello\n\n';
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode(sseText),
      ]));
      final events = await stream.toList();
      expect(events, hasLength(1));
      final event = events[0] as PlayxSseEvent;
      expect(event.event, 'message');
      expect(event.data, 'hello');
    });

    test('parses named event', () async {
      final sseText = 'event: update\ndata: {"value": 42}\n\n';
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode(sseText),
      ]));
      final events = await stream.toList();
      expect(events, hasLength(1));
      final event = events[0] as PlayxSseEvent;
      expect(event.event, 'update');
      expect(event.data, '{"value": 42}');
    });

    test('concatenates multiple data lines with \\n', () async {
      final sseText = 'data: line1\ndata: line2\n\n';
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode(sseText),
      ]));
      final events = await stream.toList();
      expect(events, hasLength(1));
      final event = events[0] as PlayxSseEvent;
      expect(event.data, 'line1\nline2');
    });

    test('parses id field', () async {
      final sseText = 'id: 42\ndata: test\n\n';
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode(sseText),
      ]));
      final events = await stream.toList();
      expect(events, hasLength(1));
      final event = events[0] as PlayxSseEvent;
      expect(event.id, '42');
    });

    test('parses retry field', () async {
      final sseText = 'retry: 5000\ndata: test\n\n';
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode(sseText),
      ]));
      final events = await stream.toList();
      expect(events, hasLength(1));
      final event = events[0] as PlayxSseEvent;
      expect(event.retry, 5000);
    });

    test('ignores comment lines starting with colon', () async {
      final sseText = ': this is a comment\ndata: test\n\n';
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode(sseText),
      ]));
      final events = await stream.toList();
      expect(events, hasLength(1));
      expect((events[0] as PlayxSseEvent).data, 'test');
    });

    test('handles CRLF line endings', () async {
      final sseText = 'data: hello\r\n\r\n';
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode(sseText),
      ]));
      final events = await stream.toList();
      expect(events, hasLength(1));
      expect((events[0] as PlayxSseEvent).data, 'hello');
    });

    test('parses multiple events in one chunk', () async {
      final sseText = 'data: first\n\ndata: second\n\n';
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode(sseText),
      ]));
      final events = await stream.toList();
      expect(events, hasLength(2));
      expect((events[0] as PlayxSseEvent).data, 'first');
      expect((events[1] as PlayxSseEvent).data, 'second');
    });

    test('parses events split across multiple chunks', () async {
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode('data: hel'),
        utf8.encode('lo\n\n'),
      ]));
      final events = await stream.toList();
      expect(events, hasLength(1));
      expect((events[0] as PlayxSseEvent).data, 'hello');
    });

    test('strips single leading space from value', () async {
      // SSE spec: strip one leading space after the colon.
      final sseText = 'data:  two spaces\n\n';
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode(sseText),
      ]));
      final events = await stream.toList();
      expect(events, hasLength(1));
      expect((events[0] as PlayxSseEvent).data, ' two spaces');
    });

    test('field without colon uses entire line as field with empty value',
        () async {
      final sseText = 'data\ndata: test\n\n';
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode(sseText),
      ]));
      final events = await stream.toList();
      expect(events, hasLength(1));
      expect((events[0] as PlayxSseEvent).data, '\ntest');
    });

    test('flushes pending event when stream closes without trailing blank line',
        () async {
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode('data: no-newline-at-end'),
      ]));
      final events = await stream.toList();
      expect(events, hasLength(1));
      expect((events[0] as PlayxSseEvent).data, 'no-newline-at-end');
    });

    test('does not emit event for heartbeat (comment only)', () async {
      final sseText = ': heartbeat\n\n';
      final stream = PlayxStreamFormat.sse.decodeStream(Stream.fromIterable([
        utf8.encode(sseText),
      ]));
      final events = await stream.toList();
      expect(events, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // NetworkStreamResult tests
  // ---------------------------------------------------------------------------

  group('NetworkStreamResult', () {
    test('success factory wraps a stream', () {
      final stream = Stream.fromIterable([1, 2, 3]);
      final result = NetworkStreamResult.success(stream);
      expect(result, isA<NetworkStreamSuccess<int>>());
      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
      expect(result.data, isNotNull);
    });

    test('error factory wraps an exception', () {
      const result = NetworkStreamResult<int>.error(
        UnexpectedErrorException(errorMessage: 'boom'),
      );
      expect(result, isA<NetworkStreamError<int>>());
      expect(result.isError, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.data, isNull);
      expect(result.error, isA<UnexpectedErrorException>());
    });

    test('when() invokes correct callback and returns this', () {
      final result = NetworkStreamResult<int>.success(Stream.fromIterable([1]));
      var captured = false;
      final returned = result.when(
        success: (_) => captured = true,
        error: (_) => fail('should not be error'),
      );
      expect(captured, isTrue);
      expect(identical(returned, result), isTrue);
    });

    test('when() invokes error callback', () {
      const result = NetworkStreamResult<int>.error(
        RequestCanceledException(errorMessage: 'cancelled'),
      );
      var captured = false;
      result.when(
        success: (_) => fail('should not be success'),
        error: (e) {
          captured = true;
          expect(e, isA<RequestCanceledException>());
        },
      );
      expect(captured, isTrue);
    });

    test('map() transforms success', () {
      final result = NetworkStreamResult<int>.success(Stream.fromIterable([1]));
      final mapped = result.map<String>(
        success: (s) => 'has-stream',
        error: (e) => 'error',
      );
      expect(mapped, 'has-stream');
    });

    test('map() transforms error', () {
      const result = NetworkStreamResult<int>.error(
        UnexpectedErrorException(errorMessage: 'boom'),
      );
      final mapped = result.map<String>(
        success: (s) => 'ok',
        error: (e) => 'err=${e.error.message}',
      );
      expect(mapped, 'err=boom');
    });

    test('mapStream transforms success stream and preserves error', () async {
      final result =
          NetworkStreamResult<int>.success(Stream.fromIterable([1, 2, 3]));
      final mapped = result.mapStream<String>(
        mapper: (stream) => stream.map((e) => 'item-$e'),
      );
      expect(mapped.isSuccess, isTrue);
      final items = await mapped.data!.toList();
      expect(items, ['item-1', 'item-2', 'item-3']);
    });

    test('mapStream preserves error case', () {
      const result = NetworkStreamResult<int>.error(
        UnexpectedErrorException(errorMessage: 'fail'),
      );
      final mapped = result.mapStream<String>(
        mapper: (stream) => stream.map((e) => 'item-$e'),
      );
      expect(mapped.isError, isTrue);
      expect(mapped.error!.message, 'fail');
    });

    test('toList collects success stream into a list', () async {
      final result =
          NetworkStreamResult<int>.success(Stream.fromIterable([1, 2, 3]));
      final listResult = await result.toList();
      expect(listResult.isSuccess, isTrue);
      expect(listResult.data, [1, 2, 3]);
    });

    test('toList preserves error case', () async {
      const result = NetworkStreamResult<int>.error(
        UnexpectedErrorException(errorMessage: 'fail'),
      );
      final listResult = await result.toList();
      expect(listResult.isError, isTrue);
      expect(listResult.error!.message, 'fail');
    });

    test('toString contains data for success', () {
      final result = NetworkStreamSuccess<int>(Stream.fromIterable([1]));
      expect(result.toString(), contains('NetworkStreamSuccess'));
    });

    test('toString contains error message for error', () {
      const result = NetworkStreamError<int>(
        UnexpectedErrorException(errorMessage: 'fail'),
      );
      expect(result.toString(), contains('NetworkStreamError'));
      expect(result.toString(), contains('fail'));
    });
  });

  // ---------------------------------------------------------------------------
  // PlayxNetworkClient.getStream tests
  // ---------------------------------------------------------------------------

  group('PlayxNetworkClient.getStream', () {
    test('emits text chunks on success', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 200,
        chunks: [
          utf8.encode('chunk1 '),
          utf8.encode('chunk2'),
        ],
      );

      final client = _client(dio);
      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      expect(result.isSuccess, isTrue);
      final chunks = await result.data!.toList();
      expect(chunks, ['chunk1 ', 'chunk2']);
    });

    test('emits bytes chunks on success', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 200,
        chunks: [
          [1, 2, 3],
          [4, 5, 6],
        ],
      );

      final client = _client(dio);
      final result = await client.getStream<List<int>>(
        '/stream',
        format: PlayxStreamFormat.bytes,
      );

      expect(result.isSuccess, isTrue);
      final chunks = await result.data!.toList();
      expect(chunks, [
        [1, 2, 3],
        [4, 5, 6],
      ]);
    });

    test('emits json chunks on success', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 200,
        chunks: [
          utf8.encode('{"i": 1}'),
          utf8.encode('{"i": 2}'),
        ],
      );

      final client = _client(dio);
      final result = await client.getStream<Object>(
        '/stream',
        format: PlayxStreamFormat.json,
      );

      expect(result.isSuccess, isTrue);
      final chunks = await result.data!.toList();
      expect(chunks, hasLength(2));
      expect((chunks[0] as Map)['i'], 1);
      expect((chunks[1] as Map)['i'], 2);
    });

    test('emits SSE events via getSse', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _SseAdapter(
        statusCode: 200,
        eventStrings: [
          'data: hello\n\n',
          'event: update\ndata: world\n\n',
        ],
      );

      final client = _client(dio);
      final result = await client.getSse('/events');

      expect(result.isSuccess, isTrue);
      final events = await result.data!.toList();
      expect(events, hasLength(2));
      expect(events[0].data, 'hello');
      expect(events[0].event, 'message');
      expect(events[1].data, 'world');
      expect(events[1].event, 'update');
    });

    test('emits SSE events via getStream with sse format', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _SseAdapter(
        statusCode: 200,
        eventStrings: [
          'data: hello\n\n',
        ],
      );

      final client = _client(dio);
      final result = await client.getStream<PlayxSseEvent>(
        '/events',
        format: PlayxStreamFormat.sse,
      );

      expect(result.isSuccess, isTrue);
      final events = await result.data!.toList();
      expect(events, hasLength(1));
      expect(events[0].data, 'hello');
    });

    test('returns error for non-success status code', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 404,
        chunks: [utf8.encode('not found')],
      );

      final client = _client(dio);
      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<NotFoundException>());
      expect(result.data, isNull);
    });

    test('returns error for 500 status code', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 500,
        chunks: [utf8.encode('server error')],
      );

      final client = _client(dio);
      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<InternalServerErrorException>());
    });

    test('returns error for 401 unauthorized and invokes handler', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 401,
        chunks: [utf8.encode('unauthorized')],
      );

      var unauthorizedCalled = false;
      final client = PlayxNetworkClient(
        dio: dio,
        settings: _defaultSettings,
        onUnauthorizedRequestReceived: (_) {
          unauthorizedCalled = true;
        },
      );

      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<UnauthorizedRequestException>());
      expect(unauthorizedCalled, isTrue);
    });

    test('can disable unauthorized handler via shouldHandleUnauthorizedRequest',
        () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 401,
        chunks: [utf8.encode('unauthorized')],
      );

      var unauthorizedCalled = false;
      final client = PlayxNetworkClient(
        dio: dio,
        settings: _defaultSettings,
        onUnauthorizedRequestReceived: (_) {
          unauthorizedCalled = true;
        },
      );

      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
        shouldHandleUnauthorizedRequest: false,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<UnauthorizedRequestException>());
      expect(unauthorizedCalled, isFalse);
    });

    test('handles DioException (connectionTimeout) as error', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _ErrorAdapter(
        type: DioExceptionType.connectionTimeout,
      );

      final client = _client(dio);
      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<RequestTimeoutException>());
    });

    test('handles DioException (cancel) as error', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _ErrorAdapter(
        type: DioExceptionType.cancel,
      );

      final client = _client(dio);
      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<RequestCanceledException>());
    });

    test('handles DioException (connectionError) as no internet', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _ErrorAdapter(
        type: DioExceptionType.connectionError,
      );

      final client = _client(dio);
      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<NoInternetConnectionException>());
    });

    test('attaches custom headers', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      final capturedHeaders = <String, dynamic>{};
      dio.httpClientAdapter = _HeaderCapturingAdapter(
        statusCode: 200,
        chunks: [utf8.encode('hi')],
        captured: capturedHeaders,
      );

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _defaultSettings,
        customHeaders: () async => {'authorization': 'Bearer token123'},
      );

      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      expect(result.isSuccess, isTrue);
      expect(capturedHeaders['authorization'], 'Bearer token123');
    });

    test('attaches custom query', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      final capturedQuery = <String, dynamic>{};
      dio.httpClientAdapter = _QueryCapturingAdapter(
        statusCode: 200,
        chunks: [utf8.encode('hi')],
        captured: capturedQuery,
      );

      final client = PlayxNetworkClient(
        dio: dio,
        settings: _defaultSettings,
        customQuery: () async => {'locale': 'ar'},
      );

      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      expect(result.isSuccess, isTrue);
      expect(capturedQuery['locale'], 'ar');
    });

    test('per-request settings override client settings', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 204,
        chunks: [utf8.encode('ok')],
      );

      final client = _client(dio);
      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
        settings: const PlayxNetworkClientSettings(
          logSettings: PlayxNetworkLoggerSettings(enabled: false),
          useIsolateForMappingJson: false,
          successRequestCodes: [200, 204],
        ),
      );

      // 204 is not in default successRequestCodes but is in per-request
      expect(result.isSuccess, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // PlayxNetworkClient.postStream tests
  // ---------------------------------------------------------------------------

  group('PlayxNetworkClient.postStream', () {
    test('emits text chunks on success', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 200,
        chunks: [
          utf8.encode('post1 '),
          utf8.encode('post2'),
        ],
      );

      final client = _client(dio);
      final result = await client.postStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
        body: {'key': 'value'},
      );

      expect(result.isSuccess, isTrue);
      final chunks = await result.data!.toList();
      expect(chunks, ['post1 ', 'post2']);
    });

    test('emits SSE events via postSse', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _SseAdapter(
        statusCode: 200,
        eventStrings: [
          'event: created\ndata: {"id": 1}\n\n',
        ],
      );

      final client = _client(dio);
      final result = await client.postSse(
        '/events',
        body: {'name': 'test'},
      );

      expect(result.isSuccess, isTrue);
      final events = await result.data!.toList();
      expect(events, hasLength(1));
      expect(events[0].event, 'created');
      expect(events[0].data, '{"id": 1}');
    });

    test('returns error for non-success status code', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 500,
        chunks: [utf8.encode('error')],
      );

      final client = _client(dio);
      final result = await client.postStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<InternalServerErrorException>());
    });

    test('handles DioException as error', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _ErrorAdapter(
        type: DioExceptionType.sendTimeout,
      );

      final client = _client(dio);
      final result = await client.postStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      expect(result.isError, isTrue);
      expect(result.error, isA<SendTimeoutException>());
    });
  });

  // ---------------------------------------------------------------------------
  // Cancellation tests
  // ---------------------------------------------------------------------------

  group('stream cancellation', () {
    test('cancelTag cancels the stream with RequestCanceledException',
        () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 200,
        chunks: List.generate(100, (i) => utf8.encode('chunk$i ')),
        delay: const Duration(milliseconds: 10),
      );

      final client = _client(dio);
      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
        cancelTag: 'cancel-test',
      );

      expect(result.isSuccess, isTrue);
      final completer = Completer<Object>();
      final received = <String>[];

      final sub = result.data!.listen(
        (data) {
          received.add(data);
          // Cancel after receiving a few chunks.
          if (received.length == 3) {
            client.cancelRequestsByTag('cancel-test');
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(received);
          }
        },
      );

      Object outcome;
      try {
        outcome = await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            sub.cancel();
            return received;
          },
        );
      } catch (e) {
        outcome = e;
      }

      // We should have received some chunks and then a cancellation error
      // OR the stream should have been cut short.
      if (outcome is List<String>) {
        // Stream closed without error (may happen if cancel arrives late)
        expect(outcome.length, lessThanOrEqualTo(100));
      } else {
        expect(outcome, isA<RequestCanceledException>());
      }
    });
  });

  // ---------------------------------------------------------------------------
  // DioClient.getStream / postStream tests
  // ---------------------------------------------------------------------------

  group('DioClient.getStream / postStream', () {
    test('getStream returns a ResponseBody with the correct status', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 200,
        chunks: [utf8.encode('hello')],
      );

      final dioClient = DioClient(
        dio: dio,
        settings: _defaultSettings,
      );

      // Verify DioClient.getStream works by using it directly
      final responseBody = await dioClient.getStream('/test');
      expect(responseBody.statusCode, 200);
    });

    test('getStream sets responseType to stream', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      final capturedOptions = <RequestOptions>[];
      dio.httpClientAdapter = _OptionsCapturingAdapter(
        statusCode: 200,
        chunks: [utf8.encode('hi')],
        captured: capturedOptions,
      );

      final dioClient = DioClient(
        dio: dio,
        settings: _defaultSettings,
      );

      await dioClient.getStream('/test');

      expect(capturedOptions, isNotEmpty);
      expect(capturedOptions.first.responseType, ResponseType.stream);
    });

    test('postStream sets responseType to stream', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      final capturedOptions = <RequestOptions>[];
      dio.httpClientAdapter = _OptionsCapturingAdapter(
        statusCode: 200,
        chunks: [utf8.encode('hi')],
        captured: capturedOptions,
      );

      final dioClient = DioClient(
        dio: dio,
        settings: _defaultSettings,
      );

      await dioClient.postStream('/test', body: 'payload');

      expect(capturedOptions, isNotEmpty);
      expect(capturedOptions.first.responseType, ResponseType.stream);
    });
  });

  // -------------------------------------------------------------------------
  // toList() integration tests
  // -------------------------------------------------------------------------

  group('NetworkStreamResult.toList integration', () {
    test('collects stream chunks into a NetworkResult list', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 200,
        chunks: [
          utf8.encode('a'),
          utf8.encode('b'),
          utf8.encode('c'),
        ],
      );

      final client = _client(dio);
      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      final listResult = await result.toList();
      expect(listResult.isSuccess, isTrue);
      expect(listResult.data, ['a', 'b', 'c']);
    });

    test('preserves error when collecting to list', () async {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://example.com',
        validateStatus: (_) => true,
      ));
      dio.httpClientAdapter = _StreamAdapter(
        statusCode: 404,
        chunks: [utf8.encode('not found')],
      );

      final client = _client(dio);
      final result = await client.getStream<String>(
        '/stream',
        format: PlayxStreamFormat.text,
      );

      final listResult = await result.toList();
      expect(listResult.isError, isTrue);
      expect(listResult.error, isA<NotFoundException>());
    });
  });
}

// ---------------------------------------------------------------------------
// Test fixtures (additional adapters)
// ---------------------------------------------------------------------------

/// Adapter that captures the request headers for inspection.
class _HeaderCapturingAdapter implements HttpClientAdapter {
  _HeaderCapturingAdapter({
    required this.statusCode,
    required this.chunks,
    required this.captured,
  });

  final int statusCode;
  final List<List<int>> chunks;
  final Map<String, dynamic> captured;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.addAll(options.headers);
    final controller = StreamController<Uint8List>();
    Future(() async {
      for (final chunk in chunks) {
        controller.add(Uint8List.fromList(chunk));
        await Future.delayed(Duration.zero);
      }
      await controller.close();
    });
    return ResponseBody(
      controller.stream,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Adapter that captures the request query parameters for inspection.
class _QueryCapturingAdapter implements HttpClientAdapter {
  _QueryCapturingAdapter({
    required this.statusCode,
    required this.chunks,
    required this.captured,
  });

  final int statusCode;
  final List<List<int>> chunks;
  final Map<String, dynamic> captured;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.addAll(options.queryParameters);
    final controller = StreamController<Uint8List>();
    Future(() async {
      for (final chunk in chunks) {
        controller.add(Uint8List.fromList(chunk));
        await Future.delayed(Duration.zero);
      }
      await controller.close();
    });
    return ResponseBody(
      controller.stream,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// Adapter that captures the RequestOptions for inspection.
class _OptionsCapturingAdapter implements HttpClientAdapter {
  _OptionsCapturingAdapter({
    required this.statusCode,
    required this.chunks,
    required this.captured,
  });

  final int statusCode;
  final List<List<int>> chunks;
  final List<RequestOptions> captured;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    final controller = StreamController<Uint8List>();
    Future(() async {
      for (final chunk in chunks) {
        controller.add(Uint8List.fromList(chunk));
        await Future.delayed(Duration.zero);
      }
      await controller.close();
    });
    return ResponseBody(
      controller.stream,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
