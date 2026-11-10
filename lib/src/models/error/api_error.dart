import 'package:playx_network/src/models/error/message.dart';

/// Default api error model that can be received from network response.
/// It understands the most common error shapes and can be replaced with your
/// own `errorMapper`:
///
/// - `{"message": "..."}` and `{"statusCode": 400, "name": "...", "message": "..."}`
/// - `{"message": ["a is invalid", "b is invalid"]}` (validation errors, the
///   messages are joined with a new line)
/// - `{"error": "..."}` and `{"error": {"name": "...", "message": "..."}}`
/// - Strapi's `{"message": [{"messages": [{"id": "...", "message": "..."}]}]}`
///
/// Every field is read on its own, so a field with an unexpected type is
/// ignored instead of discarding the rest. Blank messages are treated as
/// missing.
class DefaultApiError {
  int? statusCode;
  String? name;
  String? message;

  DefaultApiError({
    this.statusCode,
    this.name,
    this.message,
  });

  DefaultApiError.fromJson(dynamic json) {
    if (json is! Map) return;

    statusCode = _asInt(json['statusCode']);
    name = _asString(json['name']);
    message = _messageFrom(json['message']);

    // No usable `message`: fall back to `error`.
    if (message == null) {
      final error = json['error'];
      if (error is Map) {
        message = _messageFrom(error['message']);
        name = _asString(error['name']) ?? name;
      } else {
        message = _asString(error);
      }
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _asString(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  /// Reads a message that is either a string, a list of strings, or Strapi's
  /// list of `{messages: [{message}]}`.
  static String? _messageFrom(dynamic value) {
    if (value is String) return _asString(value);
    if (value is! List || value.isEmpty) return null;

    if (value.first is Map) {
      final strapi = ApiMessage.fromJson(value.first).messages;
      return _asString(strapi?.firstOrNull?.message);
    }

    final messages = value.map(_asString).whereType<String>();
    return messages.isEmpty ? null : messages.join('\n');
  }
}
