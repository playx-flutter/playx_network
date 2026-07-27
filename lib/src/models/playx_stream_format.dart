import 'dart:convert';

/// Defines how the raw bytes emitted by a server stream should be decoded
/// before being emitted by `PlayxNetworkClient.getStream` /
/// `PlayxNetworkClient.postStream`.
///
/// The decoding happens per chunk: each [List<int>] received from the network
/// is converted into the corresponding type and emitted through the
/// [Stream] returned by the network client.
enum PlayxStreamFormat {
  /// Emits raw byte chunks (`List<int>`) as received from the server without
  /// any decoding. Use this when you need the raw payload (e.g. binary file
  /// downloads, protocol buffers, etc.).
  bytes,

  /// Decodes each byte chunk as UTF-8 text and emits a [String] per chunk.
  /// This is the most common format for text/event streams, NDJSON and
  /// plain-text streaming endpoints.
  text,

  /// Decodes each byte chunk as UTF-8 text and then tries to parse it as a
  /// single JSON object, emitting [Map<String, dynamic>] / [List<dynamic>]
  /// per chunk.
  ///
  /// Use this when each server chunk is a complete JSON document (for example
  /// a single SSE `data:` payload that already has the `data:` prefix
  /// stripped, or an endpoint that returns one JSON object per line).
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

  /// Decodes a single raw byte [chunk] into the format's element type.
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
  /// For [sse] this is a stateful parser that buffers lines across chunks and
  /// emits an [PlayxSseEvent] whenever a blank-line delimiter is encountered.
  Stream<dynamic> decodeStream(Stream<List<int>> stream) {
    switch (this) {
      case PlayxStreamFormat.bytes:
      case PlayxStreamFormat.text:
      case PlayxStreamFormat.json:
        return stream.map(decodeChunk).where((e) => e != null);
      case PlayxStreamFormat.sse:
        return _PlayxSseParser(stream).parse();
    }
  }
}

/// A single Server-Sent Event as emitted by [PlayxStreamFormat.sse].
///
/// The fields mirror the SSE wire format:
/// - [event] is the value of the last `event:` line (defaults to `'message'`).
/// - [data] contains the concatenated `data:` lines joined with `\n`.
/// - [id] is the value of the last `id:` line, if any.
/// - [retry] is the reconnection hint, if any.
class PlayxSseEvent {
  /// The event type. Defaults to `'message'` when the server does not specify
  /// an `event:` field.
  final String event;

  /// The event payload. When the server sends multiple `data:` lines they are
  /// joined with a single `\n` separator, matching the SSE specification.
  final String data;

  /// The last event id, if the server sent an `id:` field.
  final String? id;

  /// The reconnection interval (milliseconds) hinted by the server via a
  /// `retry:` field, if any.
  final int? retry;

  const PlayxSseEvent({
    required this.event,
    required this.data,
    this.id,
    this.retry,
  });

  /// Whether the event carries no data. Useful for filtering heartbeat events.
  bool get isEmpty => data.isEmpty;

  /// Parses [data] as JSON, throwing if it is not valid JSON.
  dynamic dataToJson() => jsonDecode(data);

  /// Parses [data] as JSON, returning `null` on failure.
  dynamic dataToJsonOrNull() {
    try {
      return data.isEmpty ? null : jsonDecode(data);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() =>
      'PlayxSseEvent(event: $event, id: $id, retry: $retry, data: $data)';

  @override
  bool operator ==(Object other) =>
      other is PlayxSseEvent &&
      other.event == event &&
      other.data == data &&
      other.id == id &&
      other.retry == retry;

  @override
  int get hashCode => Object.hash(event, data, id, retry);
}

/// Stateful SSE parser that converts a raw byte stream into [PlayxSseEvent]s.
class _PlayxSseParser {
  _PlayxSseParser(this._stream);

  final Stream<List<int>> _stream;

  Stream<PlayxSseEvent> parse() async* {
    final buffer = StringBuffer();
    String? currentEvent;
    final dataLines = <String>[];
    String? currentId;
    int? currentRetry;

    await for (final chunk in _stream) {
      final text = utf8.decode(chunk, allowMalformed: true);
      buffer.write(text);

      // Process complete lines (terminated by \n).
      // Keep the trailing partial line in the buffer.
      while (true) {
        final content = buffer.toString();
        final newlineIndex = content.indexOf('\n');
        if (newlineIndex == -1) break;

        final rawLine = content.substring(0, newlineIndex);
        // Clear consumed content, keep the rest (partial line) in buffer.
        buffer
          ..clear()
          ..write(content.substring(newlineIndex + 1));

        // Strip a single trailing \r (CRLF handling).
        final line = rawLine.endsWith('\r')
            ? rawLine.substring(0, rawLine.length - 1)
            : rawLine;

        // Empty line → dispatch event (SSE spec).
        if (line.isEmpty) {
          if (dataLines.isNotEmpty || currentId != null) {
            yield PlayxSseEvent(
              event: currentEvent ?? 'message',
              data: dataLines.join('\n'),
              id: currentId,
              retry: currentRetry,
            );
          }
          currentEvent = null;
          dataLines.clear();
          currentId = null;
          currentRetry = null;
          continue;
        }

        // Comment line starts with ':'.
        if (line.startsWith(':')) {
          continue;
        }

        final colonIndex = line.indexOf(':');
        final field = colonIndex == -1 ? line : line.substring(0, colonIndex);
        // Per spec: strip a single leading space from the value.
        var value = '';
        if (colonIndex != -1) {
          value = line.substring(colonIndex + 1);
          if (value.startsWith(' ')) {
            value = value.substring(1);
          }
        }

        switch (field) {
          case 'event':
            currentEvent = value;
            break;
          case 'data':
            dataLines.add(value);
            break;
          case 'id':
            currentId = value.isEmpty ? null : value;
            break;
          case 'retry':
            final parsed = int.tryParse(value);
            if (parsed != null) {
              currentRetry = parsed;
            }
            break;
          default:
            // Unknown fields are ignored per the SSE spec.
            break;
        }
      }
    }

    // Process any remaining content in the buffer (no trailing newline).
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      buffer.clear();
      final line = remaining.endsWith('\r')
          ? remaining.substring(0, remaining.length - 1)
          : remaining;

      if (line.isEmpty) {
        // Already handled by trim above.
      } else if (line.startsWith(':')) {
        // Comment — ignore.
      } else {
        final colonIndex = line.indexOf(':');
        final field = colonIndex == -1 ? line : line.substring(0, colonIndex);
        var value = '';
        if (colonIndex != -1) {
          value = line.substring(colonIndex + 1);
          if (value.startsWith(' ')) {
            value = value.substring(1);
          }
        }

        switch (field) {
          case 'event':
            currentEvent = value;
            break;
          case 'data':
            dataLines.add(value);
            break;
          case 'id':
            currentId = value.isEmpty ? null : value;
            break;
          case 'retry':
            final parsed = int.tryParse(value);
            if (parsed != null) {
              currentRetry = parsed;
            }
            break;
          default:
            break;
        }
      }
    }

    // Flush any pending event when the stream closes without a trailing
    // blank line (some servers omit the final delimiter).
    if (dataLines.isNotEmpty || currentId != null) {
      yield PlayxSseEvent(
        event: currentEvent ?? 'message',
        data: dataLines.join('\n'),
        id: currentId,
        retry: currentRetry,
      );
    }
  }
}
