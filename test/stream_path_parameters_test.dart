import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';

/// Records the final request path and answers with an empty stream.
class _PathAdapter implements HttpClientAdapter {
  String? lastPath;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    return ResponseBody(const Stream<Uint8List>.empty(), 200);
  }
}

({PlayxNetworkClient client, _PathAdapter adapter}) _setup({
  Map<String, dynamic> Function()? customPathParameters,
}) {
  final adapter = _PathAdapter();
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/'))
    ..httpClientAdapter = adapter;
  final client = PlayxNetworkClient(
    dio: dio,
    customPathParameters: customPathParameters,
    settings: const PlayxNetworkClientSettings(),
  );
  return (client: client, adapter: adapter);
}

void main() {
  group('stream requests substitute path parameters', () {
    test('getStream', () async {
      final s = _setup();
      await s.client.getStream<String>(
        'users/{id}/events',
        pathParameters: {'id': 42},
        format: PlayxStreamFormat.text,
      );
      expect(s.adapter.lastPath, 'users/42/events');
    });

    test('postStream', () async {
      final s = _setup();
      await s.client.postStream<String>(
        'rooms/{room}/messages',
        pathParameters: {'room': 'a b'},
        format: PlayxStreamFormat.text,
      );
      expect(s.adapter.lastPath, 'rooms/a%20b/messages');
    });

    test('getSse', () async {
      final s = _setup();
      await s.client.getSse('feeds/{id}', pathParameters: {'id': 7});
      expect(s.adapter.lastPath, 'feeds/7');
    });

    test('postSse', () async {
      final s = _setup();
      await s.client.postSse('feeds/{id}', pathParameters: {'id': 7});
      expect(s.adapter.lastPath, 'feeds/7');
    });

    test('client-level customPathParameters are applied', () async {
      final s = _setup(customPathParameters: () => {'version': 'v2'});
      await s.client.getStream<String>(
        '{version}/events/{id}',
        pathParameters: {'id': 1},
        format: PlayxStreamFormat.text,
      );
      expect(s.adapter.lastPath, 'v2/events/1');
    });

    test('attachCustomPathParameters: false skips them', () async {
      final s = _setup(customPathParameters: () => {'version': 'v2'});
      await s.client.getSse(
        '{version}/events/{id}',
        pathParameters: {'id': 1},
        attachCustomPathParameters: false,
      );
      expect(s.adapter.lastPath, '{version}/events/1');
    });

    test('paths without placeholders are unchanged', () async {
      final s = _setup(customPathParameters: () => {'version': 'v2'});
      await s.client.getStream<String>(
        'events',
        format: PlayxStreamFormat.text,
      );
      expect(s.adapter.lastPath, 'events');
    });
  });
}
