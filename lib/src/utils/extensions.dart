/// Extensions on nullable [String] that provide common null-or-empty /
/// null-or-blank checks and fallback behavior.
///
/// These helpers let call-sites express common guards without repeating
/// `value == null || value.trim().isEmpty` boilerplate.
///
/// They complement — and intentionally avoid duplicating — the nullable-string
/// helpers already provided by `playx_core` (`isNullOrEmpty`,
/// `isNotNullOrEmpty`, `ifNullOrEmpty`).
extension PlayxNetworkNullableStringExtensions on String? {
  /// Returns `true` if this string is `null` or consists only of whitespace.
  ///
  /// Unlike [isNullOrEmpty] (provided by `playx_core`), this also treats a
  /// string of spaces, tabs, or newlines as "blank".
  ///
  /// Example:
  /// ```dart
  /// null.isNullOrBlank;          // true
  /// ''.isNullOrBlank;            // true
  /// '   '.isNullOrBlank;         // true
  /// '\t\n'.isNullOrBlank;        // true
  /// 'hello'.isNullOrBlank;       // false
  /// ```
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;

  /// Returns `true` if this string is not `null` and contains at least one
  /// non-whitespace character.
  ///
  /// This is the negation of [isNullOrBlank].
  ///
  /// Example:
  /// ```dart
  /// null.isNotNullOrBlank;       // false
  /// ''.isNotNullOrBlank;         // false
  /// '   '.isNotNullOrBlank;      // false
  /// 'hello'.isNotNullOrBlank;    // true
  /// ```
  bool get isNotNullOrBlank => this != null && this!.trim().isNotEmpty;

  /// Returns `null` if the string is `null` or empty; otherwise returns the
  /// string itself.
  ///
  /// Useful for normalizing optional fields before persistence or
  /// serialization where an empty string should be treated as "absent".
  ///
  /// Example:
  /// ```dart
  /// null.nullIfEmpty;            // null
  /// ''.nullIfEmpty;              // null
  /// 'hello'.nullIfEmpty;         // 'hello'
  /// '  '.nullIfEmpty;            // '  '  (whitespace is preserved)
  /// ```
  String? get nullIfEmpty => (this == null || this!.isEmpty) ? null : this;

  /// Returns `null` if the string is `null`, empty, or contains only
  /// whitespace; otherwise returns the string itself.
  ///
  /// Unlike [nullIfEmpty], this also treats a whitespace-only string as
  /// "blank" and converts it to `null`.
  ///
  /// Example:
  /// ```dart
  /// null.nullIfBlank;            // null
  /// ''.nullIfBlank;              // null
  /// '   '.nullIfBlank;           // null
  /// '\t\n'.nullIfBlank;          // null
  /// 'hello'.nullIfBlank;         // 'hello'
  /// ```
  String? get nullIfBlank =>
      (this == null || this!.trim().isEmpty) ? null : this;

  /// Returns this string if it is not `null` or empty; otherwise returns
  /// [fallback].
  ///
  /// Example:
  /// ```dart
  /// null.orIfNullOrEmpty('N/A');       // 'N/A'
  /// ''.orIfNullOrEmpty('N/A');         // 'N/A'
  /// 'hello'.orIfNullOrEmpty('N/A');    // 'hello'
  /// '  '.orIfNullOrEmpty('N/A');       // '  '  (whitespace is preserved)
  /// ```
  String orIfNullOrEmpty(String fallback) =>
      (this == null || this!.isEmpty) ? fallback : this!;

  /// Returns this string if it is not `null`, empty, or blank (only
  /// whitespace); otherwise returns [fallback].
  ///
  /// Unlike [orIfNullOrEmpty], this also treats a whitespace-only string as
  /// "blank" and falls back to [fallback].
  ///
  /// Example:
  /// ```dart
  /// null.orIfNullOrBlank('N/A');       // 'N/A'
  /// ''.orIfNullOrBlank('N/A');        // 'N/A'
  /// '   '.orIfNullOrBlank('N/A');      // 'N/A'
  /// 'hello'.orIfNullOrBlank('N/A');   // 'hello'
  /// ```
  String orIfNullOrBlank(String fallback) =>
      (this == null || this!.trim().isEmpty) ? fallback : this!;
}
