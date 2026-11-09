final RegExp _placeholder = RegExp(r'\{(\w+)\}');

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
/// - Substitution is done in a single pass, so replaced values are never
///   re-scanned and the result does not depend on map order.
/// - Each `{key}` token is replaced with the URL-encoded `toString()` of the
///   matching entry in [pathParameters]. Slashes are encoded too (`a/b` becomes
///   `a%2Fb`), so a value always stays within one path segment.
/// - Tokens without a matching key are left untouched so that Dio raises its
///   standard path error, preserving existing behaviour for paths that
///   legitimately contain literal braces.
///
/// Throws an [ArgumentError] if a placeholder present in [path] is mapped to
/// `null`, instead of silently sending a request to a literal `{key}` path.
String substitutePathParameters(
  String path,
  Map<String, dynamic> pathParameters,
) {
  if (pathParameters.isEmpty) return path;
  return path.replaceAllMapped(_placeholder, (match) {
    final key = match.group(1)!;
    if (!pathParameters.containsKey(key)) return match.group(0)!;
    final value = pathParameters[key];
    if (value == null) {
      throw ArgumentError.value(
        value,
        key,
        'Path parameter "$key" for path "$path" must not be null',
      );
    }
    return Uri.encodeComponent(value.toString());
  });
}
