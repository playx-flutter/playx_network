import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';

/// Decodes [bytes] delivered as the given [chunks] boundaries.
Future<List<dynamic>> _decode(
  PlayxStreamFormat format,
  List<int> bytes,
  List<int> cuts,
) {
  final points = [0, ...cuts, bytes.length];
  final chunks = <List<int>>[
    for (var i = 0; i < points.length - 1; i++)
      bytes.sublist(points[i], points[i + 1]),
  ];
  return format.decodeStream(Stream.fromIterable(chunks)).toList();
}

String _joined(List<dynamic> items) => items.join('');

void main() {
  // Mixes CRLF, LF and CR endings, comments, multibyte text, multi-line data,
  // ids, retries, custom events and a final event without a blank line.
  final sse = utf8.encode(
    ': comment\r\n'
    'id: 1\r\n'
    'event: greet\r\n'
    'data: مرحبا 😀\r\n'
    '\r\n'
    'data: line one\n'
    'data: line two\n'
    '\n'
    'retry: 4000\r'
    'data: carriage return endings\r'
    '\r'
    'id: 2\n'
    'data: {"emoji":"🎉","text":"日本語"}\n'
    '\n'
    'data: last, no blank line\n',
  );

  group('SSE parser splits', () {
    late List<PlayxSseEvent> expected;

    setUpAll(() async {
      expected = (await _decode(
        PlayxStreamFormat.sse,
        sse,
        const [],
      )).cast<PlayxSseEvent>();
    });

    test('the unsplit parse is what we expect', () {
      expect(expected.map((e) => e.data), [
        'مرحبا 😀',
        'line one\nline two',
        'carriage return endings',
        '{"emoji":"🎉","text":"日本語"}',
        'last, no blank line',
      ]);
      expect(expected.first.event, 'greet');
      expect(expected.first.id, '1');
      expect(expected[2].retry, 4000);
      expect(expected[3].id, '2');
      expect(expected.last.id, '2');
    });

    test('every single split point gives the same events', () async {
      for (var cut = 1; cut < sse.length; cut++) {
        final events = await _decode(PlayxStreamFormat.sse, sse, [cut]);
        expect(events, expected, reason: 'split at byte $cut');
      }
    });

    test('byte-by-byte delivery gives the same events', () async {
      final cuts = [for (var i = 1; i < sse.length; i++) i];
      expect(await _decode(PlayxStreamFormat.sse, sse, cuts), expected);
    });

    test('random splits give the same events', () async {
      final random = Random(42);
      for (var round = 0; round < 200; round++) {
        final cuts = {
          for (var i = 0; i < 1 + random.nextInt(8); i++)
            1 + random.nextInt(sse.length - 1),
        }.toList()..sort();
        final events = await _decode(PlayxStreamFormat.sse, sse, cuts);
        expect(events, expected, reason: 'cuts $cuts');
      }
    });
  });

  group('text decoding splits', () {
    final text = utf8.encode('Hello مرحبا 😀 日本語 🎉 end');

    test('every split point reassembles the characters', () async {
      for (var cut = 1; cut < text.length; cut++) {
        final chunks = await _decode(PlayxStreamFormat.text, text, [cut]);
        expect(_joined(chunks), utf8.decode(text), reason: 'split at $cut');
      }
    });

    test('byte-by-byte delivery reassembles the characters', () async {
      final cuts = [for (var i = 1; i < text.length; i++) i];
      final chunks = await _decode(PlayxStreamFormat.text, text, cuts);
      expect(_joined(chunks), utf8.decode(text));
    });
  });

  group('NDJSON splits', () {
    final ndjson = utf8.encode(
      '{"id":1,"name":"مرحبا"}\n'
      '{"id":2,"name":"😀"}\r\n'
      '\n'
      '[1,2,3]\n'
      '{"id":4,"name":"last without newline"}',
    );

    test('every split point gives the same documents', () async {
      final expected = await _decode(PlayxStreamFormat.json, ndjson, const []);
      expect(expected, hasLength(4));
      for (var cut = 1; cut < ndjson.length; cut++) {
        final docs = await _decode(PlayxStreamFormat.json, ndjson, [cut]);
        expect(docs, expected, reason: 'split at byte $cut');
      }
    });

    test('byte-by-byte delivery gives the same documents', () async {
      final expected = await _decode(PlayxStreamFormat.json, ndjson, const []);
      final cuts = [for (var i = 1; i < ndjson.length; i++) i];
      expect(await _decode(PlayxStreamFormat.json, ndjson, cuts), expected);
    });
  });

  group('bytes format', () {
    test('passes chunks through unchanged', () async {
      final data = utf8.encode('abcdef');
      final chunks = await _decode(PlayxStreamFormat.bytes, data, [2, 4]);
      expect(chunks, [
        [97, 98],
        [99, 100],
        [101, 102],
      ]);
    });
  });
}
