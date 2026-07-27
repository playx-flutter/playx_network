/// Utility for substituting `{placeholder}` segments in a request path with
/// concrete values supplied via [pathParameters].
///
/// Example:
/// ```dart
/// substitutePathParameters('users/{userId}/posts/{postId}', {
///   'userId': 42,
///   'postId': 7,
/// }); // => 'users/42/posts/7'
/// ```
///
/// - Each `{key}` token is replaced with the URL-encoded `toString()` of the
///   matching entry in [pathParameters].
/// - Tokens without a matching key are left untouched so that Dio raises its
///   standard path error, preserving existing behaviour for paths that
///   legitimately contain literal braces.
/// - Values are encoded with [Uri.encodeComponent] (spaces become `%20`),
///   which is the correct encoding for path segments.
String substitutePathParameters(
  String path,
  Map<String, dynamic> pathParameters,
) {
  if (pathParameters.isEmpty) return path;
  var resolved = path;
  for (final entry in pathParameters.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value == null) continue;
    final token = '{$key}';
    if (!resolved.contains(token)) continue;
    resolved = resolved.replaceAll(
      token,
      Uri.encodeComponent(value.toString()),
    );
  }
  return resolved;
}