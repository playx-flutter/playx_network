import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/utils/browser_connectivity.dart';

/// Answers every request with [body] and remembers what was asked.
class _EchoAdapter implements HttpClientAdapter {
  _EchoAdapter(this.body, {this.status = 200, this.delay = Duration.zero});

  final Object body;
  final int status;
  final Duration delay;

  final requests = <RequestOptions>[];
  final bodies = <String>[];

  RequestOptions get last => requests.last;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      bodies.add(utf8.decode(await requestStream.expand((c) => c).toList()));
    }
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    final bytes = body is List<int>
        ? body as List<int>
        : utf8.encode(body is String ? body as String : jsonEncode(body));
    return ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );
  }
}

PlayxNetworkClient _client(_EchoAdapter adapter) => PlayxNetworkClient(
  dio: Dio(BaseOptions(baseUrl: 'https://example.com/'))
    ..httpClientAdapter = adapter,
  settings: const PlayxNetworkClientSettings(
    useIsolateForMappingJson: false,
    useWorkMangerForMappingJsonInIsolate: false,
  ),
);

String _item(dynamic json) => '${json['id']}';

void main() {
  group('single-object requests', () {
    final adapter = _EchoAdapter({'id': 1});
    final client = _client(adapter);

    test('post sends the body with the content type', () async {
      final result = await client.post<String>(
        'items',
        body: {'name': 'a'},
        contentType: Headers.jsonContentType,
        fromJson: _item,
      );
      expect(result.data, '1');
      expect(adapter.last.method, 'POST');
      expect(adapter.last.path, 'items');
      expect(adapter.bodies.last, '{"name":"a"}');
    });

    test('put sends the body', () async {
      final result = await client.put<String>(
        'items/{id}',
        pathParameters: {'id': 3},
        body: {'name': 'b'},
        fromJson: _item,
      );
      expect(result.data, '1');
      expect(adapter.last.method, 'PUT');
      expect(adapter.last.path, 'items/3');
      expect(adapter.bodies.last, '{"name":"b"}');
    });

    test('patch sends the body', () async {
      final result = await client.patch<String>(
        'items/3',
        body: {'name': 'c'},
        fromJson: _item,
      );
      expect(result.data, '1');
      expect(adapter.last.method, 'PATCH');
      expect(adapter.bodies.last, '{"name":"c"}');
    });

    test('delete sends the body and maps the response', () async {
      final result = await client.delete<String>(
        'items/3',
        body: {'reason': 'x'},
        fromJson: _item,
      );
      expect(result.data, '1');
      expect(adapter.last.method, 'DELETE');
      expect(adapter.bodies.last, '{"reason":"x"}');
    });

    test('get reads a nested value with dataKey', () async {
      final nested = _EchoAdapter({
        'data': {'id': 9},
      });
      final result = await _client(
        nested,
      ).get<String>('x', fromJson: _item, dataKey: 'data');
      expect(result.data, '9');
    });
  });

  group('list requests', () {
    final adapter = _EchoAdapter([
      {'id': 1},
      {'id': 2},
    ]);
    final client = _client(adapter);

    test('every HTTP method maps a list', () async {
      final results = {
        'GET': await client.getList<String>('x', fromJson: _item),
        'POST': await client.postList<String>('x', fromJson: _item),
        'PUT': await client.putList<String>('x', fromJson: _item),
        'PATCH': await client.patchList<String>('x', fromJson: _item),
        'DELETE': await client.deleteList<String>('x', fromJson: _item),
      };
      for (final entry in results.entries) {
        expect(entry.value.data, ['1', '2'], reason: entry.key);
      }
      expect(adapter.requests.map((r) => r.method), [
        'GET',
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
      ]);
    });

    test('list requests support path parameters and bodies', () async {
      await client.postList<String>(
        'users/{id}/items',
        pathParameters: {'id': 5},
        body: {'q': 1},
        fromJson: _item,
      );
      expect(adapter.last.path, 'users/5/items');
      expect(adapter.bodies.last, '{"q":1}');
    });

    test('list requests surface errors', () async {
      final failing = _EchoAdapter({'message': 'nope'}, status: 404);
      final client = _client(failing);
      for (final result in [
        await client.postList<String>('x', fromJson: _item),
        await client.putList<String>('x', fromJson: _item),
        await client.patchList<String>('x', fromJson: _item),
        await client.deleteList<String>('x', fromJson: _item),
      ]) {
        expect(result.error, isA<NotFoundException>());
        expect(result.error!.message, 'nope');
      }
    });
  });

  group('download', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('playx_dl'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('saves the file and returns the response', () async {
      final adapter = _EchoAdapter(utf8.encode('file contents'));
      final path = '${dir.path}/file.txt';
      final result = await _client(
        adapter,
      ).download('files/{id}', pathParameters: {'id': 2}, savePath: path);
      expect(result.isSuccess, isTrue);
      expect(adapter.last.path, 'files/2');
      expect(File(path).readAsStringSync(), 'file contents');
    });

    test('reports progress', () async {
      final adapter = _EchoAdapter(utf8.encode('0123456789'));
      var received = 0;
      await _client(adapter).download(
        'x',
        savePath: '${dir.path}/p.txt',
        onReceiveProgress: (count, total) => received = count,
      );
      expect(received, 10);
    });

    test('maps an error status', () async {
      final adapter = _EchoAdapter({'message': 'gone'}, status: 404);
      final result = await _client(
        adapter,
      ).download('x', savePath: '${dir.path}/missing.txt');
      expect(result.error, isA<NotFoundException>());
    });
  });

  group('cancellation by tag', () {
    test('a new request with the same tag cancels the previous one', () async {
      final adapter = _EchoAdapter({
        'id': 1,
      }, delay: const Duration(milliseconds: 100));
      final client = _client(adapter);
      final first = client.get<String>('x', fromJson: _item, cancelTag: 'a');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final second = client.get<String>('x', fromJson: _item, cancelTag: 'a');
      expect((await first).error, isA<RequestCanceledException>());
      expect((await second).data, '1');
    });

    test('cancelOld: false lets both requests finish', () async {
      final adapter = _EchoAdapter({
        'id': 1,
      }, delay: const Duration(milliseconds: 50));
      final client = _client(adapter);
      final first = client.get<String>(
        'x',
        fromJson: _item,
        cancelTag: 'a',
        cancelOld: false,
      );
      final second = client.get<String>(
        'x',
        fromJson: _item,
        cancelTag: 'a',
        cancelOld: false,
      );
      expect((await first).data, '1');
      expect((await second).data, '1');
    });

    test('cancelRequestsByTag cancels only that tag', () async {
      final adapter = _EchoAdapter({
        'id': 1,
      }, delay: const Duration(milliseconds: 100));
      final client = _client(adapter);
      final a = client.get<String>('x', fromJson: _item, cancelTag: 'a');
      final b = client.get<String>('x', fromJson: _item, cancelTag: 'b');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      client.cancelRequestsByTag('a', reason: 'left the screen');
      expect((await a).error, isA<RequestCanceledException>());
      expect((await b).data, '1');
    });

    test('cancelAllRequests cancels every tagged request', () async {
      final adapter = _EchoAdapter({
        'id': 1,
      }, delay: const Duration(milliseconds: 100));
      final client = _client(adapter);
      final a = client.get<String>('x', fromJson: _item, cancelTag: 'a');
      final b = client.getList<String>('x', fromJson: _item, cancelTag: 'b');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      client.cancelAllRequests();
      expect((await a).error, isA<RequestCanceledException>());
      expect((await b).error, isA<RequestCanceledException>());
    });

    test('an explicit cancel token cancels the request', () async {
      final adapter = _EchoAdapter({
        'id': 1,
      }, delay: const Duration(milliseconds: 100));
      final token = CancelToken();
      final future = _client(
        adapter,
      ).get<String>('x', fromJson: _item, cancelToken: token);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      token.cancel();
      expect((await future).error, isA<RequestCanceledException>());
    });
  });

  group('malformed responses', () {
    test('invalid JSON is an InvalidFormatException', () async {
      final adapter = _EchoAdapter('{not json');
      final result = await _client(adapter).get<String>('x', fromJson: _item);
      expect(result.error, isA<InvalidFormatException>());
    });

    test('a body of the wrong shape is an UnableToProcessException', () async {
      final adapter = _EchoAdapter(<Object>[1, 2, 3]);
      final result = await _client(adapter).get<String>('x', fromJson: _item);
      expect(result.error, isA<UnableToProcessException>());
    });
  });

  group('client exception messages', () {
    test('are registered for use by result helpers', () {
      final first = _client(_EchoAdapter({}));
      expect(first, isNotNull);
      // Creating another client replaces the registration without throwing.
      expect(() => _client(_EchoAdapter({})), returnsNormally);
    });
  });

  group('streams', () {
    PlayxNetworkClient streamClient(List<int> bytes, {int status = 200}) =>
        PlayxNetworkClient(
          dio: Dio(
            BaseOptions(
              baseUrl: 'https://example.com/',
              validateStatus: (_) => true,
            ),
          )..httpClientAdapter = _EchoAdapter(bytes, status: status),
          settings: const PlayxNetworkClientSettings(),
        );

    test(
      'an element of the wrong type is reported and the stream goes on',
      () async {
        // Text chunks are Strings, but the caller asked for ints.
        final result = await streamClient(
          utf8.encode('hello'),
        ).getStream<int>('x', format: PlayxStreamFormat.text);
        final errors = <Object>[];
        final done = Completer<void>();
        result.data!.listen((_) {}, onError: errors.add, onDone: done.complete);
        await done.future.timeout(const Duration(seconds: 2));
        expect(errors.single, isA<UnableToProcessException>());
      },
    );

    test('an oversized error body is cut off and still mapped', () async {
      final huge = utf8.encode(jsonEncode({'message': 'x' * (70 * 1024)}));
      final result = await streamClient(
        huge,
        status: 500,
      ).getStream<String>('x', format: PlayxStreamFormat.text);
      expect(result.error, isA<InternalServerErrorException>());
    });

    test('a plain text error body reaches the error mapper', () async {
      Object? received;
      final client = PlayxNetworkClient(
        dio:
            Dio(
                BaseOptions(
                  baseUrl: 'https://example.com/',
                  validateStatus: (_) => true,
                ),
              )
              ..httpClientAdapter = _EchoAdapter(
                utf8.encode('Bad gateway'),
                status: 502,
              ),
        errorMapper: (json) {
          received = json;
          return '$json';
        },
        settings: const PlayxNetworkClientSettings(),
      );
      final result = await client.getStream<String>(
        'x',
        format: PlayxStreamFormat.text,
      );
      expect(received, 'Bad gateway');
      expect((result.error as ApiException).apiErrorMessage, 'Bad gateway');
    });

    test('an empty error body gives no API message', () async {
      final result = await streamClient(
        <int>[],
        status: 500,
      ).getStream<String>('x', format: PlayxStreamFormat.text);
      expect((result.error as ApiException).apiErrorMessage, isNull);
    });
  });

  group('platform helpers', () {
    test('browserIsOnline is unknown outside the web', () {
      expect(browserIsOnline(), isNull);
    });
  });
}
