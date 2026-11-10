import 'dart:convert';

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
