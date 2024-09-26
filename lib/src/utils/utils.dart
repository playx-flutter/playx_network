bool? isResponseBlank(dynamic value) {
  if (value is String) {
    return value.toString().trim().isEmpty;
  }
  if (value is Iterable || value is Map) {
    return value.isEmpty as bool?;
  }
  if (value == null) {
    return true;
  }
  return false;
}
