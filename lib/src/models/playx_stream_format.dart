import 'dart:convert';

import 'package:playx_network/src/models/playx_sse_event.dart';
import 'package:playx_network/src/utils/sse_parser.dart';

/// Defines how the raw bytes emitted by a server stream should be decoded
/// before being emitted by `PlayxNetworkClient.getStream` /
/// `PlayxNetworkClient.postStream`.
///
/// Decoding is done on the whole byte stream (see [decodeStream]), so
/// multibyte UTF-8 characters and lines that are split across network chunks
/// are reassembled correctly.
enum PlayxStreamFormat {
  /// Emits raw byte chunks (`List<int>`) as received from the server without
  /// any decoding. Use this when you need the raw payload (e.g. binary file
  /// downloads, protocol buffers, etc.).
  bytes,

  /// Decodes the stream as UTF-8 text and emits a [String] per network chunk.
  /// Multibyte characters split across chunks are reassembled, so a chunk may
  /// be empty-free but is not guaranteed to end on a line boundary.
  text,

  /// Decodes the stream as newline-delimited JSON (NDJSON): the stream is
  /// split into lines and each non-empty line is parsed as one JSON document,
  /// emitting [Map<String, dynamic>] / [List<dynamic>] per line.
  ///
  /// Each JSON document must therefore be terminated by a newline (a final
  /// document without a trailing newline is still emitted when the stream
  /// closes). A line that is not valid JSON produces a [FormatException] error
  /// event and the stream continues with the next line.
  json,

  /// Decodes the stream as Server-Sent Events (SSE) and emits an
  /// [PlayxSseEvent] for each event received. This parser understands the
  /// standard SSE wire format (`event:`, `data:`, `id:`, `retry:` and `:`
  /// comments) as described in the HTML specification.
  sse;

  /// Type produced by this format, used for documentation and generic
  /// inference at call sites.
  Type get elementType => switch (this) {
    PlayxStreamFormat.bytes => List<int>,
    PlayxStreamFormat.text => String,
    PlayxStreamFormat.json => Object,
    PlayxStreamFormat.sse => PlayxSseEvent,
  };

  /// Decodes a single, self-contained raw byte [chunk] into the format's
  /// element type.
  ///
  /// This works on one chunk in isolation, so it does not handle characters or
  /// documents split across chunks. Prefer [decodeStream] for real network
  /// streams.
  ///
  /// For [bytes] the same chunk is returned.
  /// For [text] the chunk is UTF-8 decoded.
  /// For [json] the chunk is UTF-8 decoded and then JSON parsed.
  /// For [sse] `null` is returned because SSE parsing is stateful and
  /// requires the full stream context; use [decodeStream] instead.
  dynamic decodeChunk(List<int> chunk) {
    switch (this) {
      case PlayxStreamFormat.bytes:
        return chunk;
      case PlayxStreamFormat.text:
        return utf8.decode(chunk, allowMalformed: true);
      case PlayxStreamFormat.json:
        final text = utf8.decode(chunk, allowMalformed: true).trim();
        if (text.isEmpty) return null;
        return jsonDecode(text);
      case PlayxStreamFormat.sse:
        // SSE parsing requires the full stream; handled by [decodeStream].
        return null;
    }
  }

  /// Transforms the raw byte [stream] into a stream of decoded elements
  /// according to this format.
  ///
  /// - [bytes] passes the chunks through untouched.
  /// - [text] uses a streaming UTF-8 decoder.
  /// - [json] splits the decoded text into lines and parses each one.
  /// - [sse] is a stateful parser that buffers lines across chunks and emits
  ///   a [PlayxSseEvent] whenever a blank-line delimiter is encountered.
  Stream<dynamic> decodeStream(Stream<List<int>> stream) {
    switch (this) {
      case PlayxStreamFormat.bytes:
        return stream;
      case PlayxStreamFormat.text:
        return const Utf8Decoder(
          allowMalformed: true,
        ).bind(stream).where((text) => text.isNotEmpty);
      case PlayxStreamFormat.json:
        return const Utf8Decoder(allowMalformed: true)
            .bind(stream)
            .transform(const LineSplitter())
            .where((line) => line.trim().isNotEmpty)
            .map(jsonDecode);
      case PlayxStreamFormat.sse:
        return SseParser(stream).parse();
    }
  }
}
