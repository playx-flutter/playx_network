import 'dart:convert';

import 'package:playx_network/src/models/playx_sse_event.dart';

/// Stateful SSE parser that converts a raw byte stream into [PlayxSseEvent]s,
/// following the HTML "Server-sent events" processing model.
class SseParser {
  SseParser(this._stream);

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
