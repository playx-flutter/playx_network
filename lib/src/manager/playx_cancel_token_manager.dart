import 'package:dio/dio.dart';

/// A simple manager that caches and controls [CancelToken]s via string tags.
/// This allows grouped request cancellation (e.g., cancelling all API requests
/// initiated from a specific screen when it is disposed).
class PlayxCancelTokenManager {
  final Map<String, CancelToken> _tokens = {};

  /// Retrieves an existing [CancelToken] for the given [tag], or creates a new one
  /// if it doesn't exist or was already cancelled.
  /// If [cancelOld] is true, it will cancel the previous request associated with the same tag before creating a new one. (defaults to true)
  CancelToken getToken(String tag, {bool cancelOld = true}) {
    var token = _tokens[tag];
    if (cancelOld && token != null && !token.isCancelled) {
      token.cancel('New request started with same tag');
      token = null;
    }
    if (token == null || token.isCancelled) {
      token = CancelToken();
      _tokens[tag] = token;
    }
    return token;
  }

  /// Cancels all requests currently associated with the given [tag].
  /// The [tag] is then removed from the pool.
  void cancelRequests(String tag, {dynamic reason}) {
    final token = _tokens[tag];
    if (token != null && !token.isCancelled) {
      token.cancel(reason);
    }
    _tokens.remove(tag);
  }

  /// Cancels all pending requests managed by this manager.
  /// Clears the token pool entirely.
  void cancelAllRequests({dynamic reason}) {
    for (final token in _tokens.values) {
      if (!token.isCancelled) {
        token.cancel(reason);
      }
    }
    _tokens.clear();
  }
}
