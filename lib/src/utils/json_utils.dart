/// Safely reads the value at [key] from decoded JSON ([json]).
///
/// Returns `null` if [json] is `null`, is not a map or list where the path
/// goes, or if the key or index is missing. A literal key that contains dots
/// wins over the path interpretation. Dot-notation reaches nested values, and
/// numeric segments index into lists, for example `'data.user.name'` or
/// `'data.users.0.name'`.
dynamic getJsonValueOrNull(dynamic json, String key) {
  if (json == null) return null;

  if (json is Map && json.containsKey(key)) return json[key];

  if (!key.contains('.')) return null;

  dynamic current = json;
  for (final segment in key.split('.')) {
    if (current is Map) {
      if (!current.containsKey(segment)) return null;
      current = current[segment];
    } else if (current is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= current.length) return null;
      current = current[index];
    } else {
      return null;
    }
  }
  return current;
}
