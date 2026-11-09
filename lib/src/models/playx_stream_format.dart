import 'dart:convert';

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
        return const Utf8Decoder(allowMalformed: true)
            .bind(stream)
            .where((text) => text.isNotEmpty);
      case PlayxStreamFormat.json:
        return const Utf8Decoder(allowMalformed: true)
            .bind(stream)
            .transform(const LineSplitter())
            .where((line) => line.trim().isNotEmpty)
            .map(jsonDecode);
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
/// - [id] is the last event id seen on the stream so far (it persists across
///   events until the server changes it), if any.
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

/// Stateful SSE parser that converts a raw byte stream into [PlayxSseEvent]s,
/// following the HTML "Server-sent events" processing model.
class _PlayxSseParser {
  _PlayxSseParser(this._stream);

  final Stream<List<int>> _stream;

  // Per-event fields, reset after each dispatch.
  String? _event;
  final List<String> _dataLines = <String>[];
  int? _retry;

  // Persists across events, per the spec's "last event ID buffer".
  String? _lastEventId;

  Stream<PlayxSseEvent> parse() async* {
    var carry = '';
    var first = true;

    await for (final text
        in const Utf8Decoder(allowMalformed: true).bind(_stream)) {
      var buffer = carry + text;
      if (first && buffer.isNotEmpty) {
        // Strip a leading byte order mark.
        if (buffer.codeUnitAt(0) == 0xFEFF) buffer = buffer.substring(1);
        first = false;
      }

      var start = 0;
      var i = 0;
      while (i < buffer.length) {
        final unit = buffer.codeUnitAt(i);
        if (unit != 0x0A && unit != 0x0D) {
          i++;
          continue;
        }
        // A trailing '\r' might be the first half of '\r\n'; wait for more.
        if (unit == 0x0D && i == buffer.length - 1) break;

        final line = buffer.substring(start, i);
        i += (unit == 0x0D && buffer.codeUnitAt(i + 1) == 0x0A) ? 2 : 1;
        start = i;

        final event = _processLine(line);
        if (event != null) yield event;
      }
      carry = buffer.substring(start);
    }

    // A trailing partial line (no line terminator) is incomplete and is
    // discarded. A fully received event that was never closed by a blank line
    // is still flushed, because some servers omit the final delimiter.
    final pending = _dispatch();
    if (pending != null) yield pending;
  }

  /// Processes one complete [line]. Returns an event when [line] is the blank
  /// line that terminates an event.
  PlayxSseEvent? _processLine(String line) {
    if (line.isEmpty) return _dispatch();
    if (line.startsWith(':')) return null; // comment

    final colonIndex = line.indexOf(':');
    final field = colonIndex == -1 ? line : line.substring(0, colonIndex);
    var value = colonIndex == -1 ? '' : line.substring(colonIndex + 1);
    if (value.startsWith(' ')) value = value.substring(1);

    switch (field) {
      case 'event':
        _event = value;
      case 'data':
        _dataLines.add(value);
      case 'id':
        // Per spec, ids containing NULL are ignored.
        if (!value.contains('\u0000')) {
          _lastEventId = value.isEmpty ? null : value;
        }
      case 'retry':
        final parsed = int.tryParse(value);
        if (parsed != null && parsed >= 0) _retry = parsed;
      default:
        // Unknown fields are ignored per the SSE spec.
        break;
    }
    return null;
  }

  /// Builds the pending event, if any, and resets the per-event state.
  ///
  /// An event without any `data:` line (for example an id-only or retry-only
  /// block) is not dispatched; the id stays in [_lastEventId] and the retry
  /// hint is kept for the next dispatched event.
  PlayxSseEvent? _dispatch() {
    final event = _event;
    _event = null;
    if (_dataLines.isEmpty) return null;

    final result = PlayxSseEvent(
      event: (event == null || event.isEmpty) ? 'message' : event,
      data: _dataLines.join('\n'),
      id: _lastEventId,
      retry: _retry,
    );
    _dataLines.clear();
    _retry = null;
    return result;
  }
}
