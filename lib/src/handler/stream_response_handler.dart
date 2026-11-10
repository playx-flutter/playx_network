import 'dart:async';
import 'dart:convert';

import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/handler/exception_mapper.dart';
import 'package:playx_network/src/handler/handler_logger.dart';

/// Turns a streaming [ResponseBody] into a [NetworkStreamResult].
///
/// It checks the status code, maps failures with the [ExceptionMapper], and
/// wires the decoded stream to the listener's pause, resume and cancel and to
/// the request's cancel token.
class StreamResponseHandler {
  StreamResponseHandler({
    required this.settings,
    required this.mapper,
    required this.log,
  });

  final PlayxNetworkClientSettings settings;
  final ExceptionMapper mapper;
  final HandlerLogger log;

  /// Handles a streaming [ResponseBody] and returns a
  /// [NetworkStreamResult] of the decoded events.
  ///
  /// The generic type `T` is inferred from [format]:
  /// - [PlayxStreamFormat.bytes] → `List<int>`
  /// - [PlayxStreamFormat.text]  → `String`
  /// - [PlayxStreamFormat.json]  → `Object` (the decoded JSON value)
  /// - [PlayxStreamFormat.sse]   → [PlayxSseEvent]
  ///
  /// If the HTTP status code is not in the success codes, the (size-capped)
  /// response body is read so the server's error message reaches the
  /// [errorMapper], and a [NetworkStreamResult.error] is returned with the
  /// appropriate [NetworkException].
  ///
  /// [abort] is called to tear down the underlying HTTP request when the
  /// listener cancels or the source fails. Cancelling the subscription alone
  /// does not release the connection, because Dio wraps the response body in
  /// its own controller; the client passes a callback that cancels a
  /// request-scoped [CancelToken].
  ///
  /// The returned stream is a single-subscription stream; consume it once.
  /// The underlying HTTP subscription starts when the stream is listened to,
  /// follows the listener's pause/resume, and is cancelled when the listener
  /// cancels, the [cancelToken] is cancelled or the source fails. The stream
  /// always completes after emitting a terminal error.
  Future<NetworkStreamResult<T>> handle<T>({
    required ResponseBody? responseBody,
    required int statusCode,
    String? statusMessage,
    required PlayxStreamFormat format,
    CancelToken? cancelToken,
    void Function()? abort,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final successCodes = (settings ?? this.settings).successRequestCodes;

    if (!successCodes.contains(statusCode) || responseBody == null) {
      final errorBody = await _readErrorBody(responseBody, abort);
      final exception = mapper.fromResponse(
        response: _StreamStatusResponse(statusCode, statusMessage, errorBody),
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      log.error(
        text: 'STREAM ERROR $statusCode $statusMessage',
        error: exception,
      );
      return NetworkStreamResult.error(exception);
    }

    return NetworkStreamResult.success(
      _bindStream<T>(
        responseBody: responseBody,
        format: format,
        statusCode: statusCode,
        cancelToken: cancelToken,
        abort: abort,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      ),
    );
  }

  /// Maximum number of bytes read from a non-success streaming response body
  /// when looking for the server's error message.
  static const int _maxErrorBodyBytes = 64 * 1024;

  /// Reads up to [_maxErrorBodyBytes] of [body], then closes it.
  /// Returns the decoded JSON, the plain text if it is not JSON, or `null`.
  Future<dynamic> _readErrorBody(
    ResponseBody? body,
    void Function()? abort,
  ) async {
    if (body == null) return null;
    final bytes = <int>[];
    try {
      await for (final chunk in body.stream) {
        bytes.addAll(chunk);
        if (bytes.length >= _maxErrorBodyBytes) {
          // Oversized body: stop reading and drop the connection.
          abort?.call();
          break;
        }
      }
    } catch (_) {
      // Fall through with whatever was read.
    }
    if (bytes.isEmpty) return null;
    final text = utf8.decode(bytes, allowMalformed: true);
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  Stream<T> _bindStream<T>({
    required ResponseBody responseBody,
    required PlayxStreamFormat format,
    required int statusCode,
    CancelToken? cancelToken,
    void Function()? abort,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) {
    final cfg = settings ?? this.settings;
    final exceptionMessages = cfg.exceptionMessages;
    late final StreamController<T> controller;
    StreamSubscription<dynamic>? subscription;
    var finished = false;

    // Cancelling the subscription alone does not release the connection:
    // Dio wraps the body in its own controller, so the request must be aborted
    // explicitly (unless the body already ended on its own).
    void release({bool abortRequest = true}) {
      final sub = subscription;
      subscription = null;
      sub?.cancel().catchError((_) {});
      if (abortRequest) abort?.call();
    }

    // Closes the output exactly once and releases the upstream connection.
    void finish({bool abortRequest = true}) {
      if (finished) return;
      finished = true;
      release(abortRequest: abortRequest);
      if (!controller.isClosed) controller.close();
    }

    void emitError(Object error) {
      if (!finished && !controller.isClosed) controller.addError(error);
    }

    cancelToken?.whenCancel.then((_) {
      if (finished) return;
      emitError(
        RequestCanceledException(
          errorMessage: exceptionMessages.requestCancelled,
        ),
      );
      finish();
    });

    controller = StreamController<T>(
      onListen: () {
        if (finished) return;
        subscription = format
            .decodeStream(responseBody.stream)
            .listen(
              (event) {
                if (finished) return;
                try {
                  controller.add(event as T);
                } catch (e, s) {
                  log.error(
                    text: exceptionMessages.unableToProcess,
                    error: e,
                    stackTrace: s,
                  );
                  emitError(
                    UnableToProcessException(
                      errorMessage: exceptionMessages.unableToProcess,
                      statusCode: statusCode,
                      shouldShowApiError:
                          (settings ?? this.settings).shouldShowApiErrors,
                    ),
                  );
                }
              },
              onError: (Object e, StackTrace s) {
                if (finished) return;
                log.error(text: 'Stream error', error: e, stackTrace: s);
                if (e is FormatException) {
                  // A malformed element does not break the connection; report it
                  // and keep reading.
                  emitError(
                    UnableToProcessException(
                      errorMessage: exceptionMessages.unableToProcess,
                      statusCode: statusCode,
                      shouldShowApiError:
                          (settings ?? this.settings).shouldShowApiErrors,
                    ),
                  );
                  return;
                }
                void emitTerminalError(bool? isOnline) {
                  emitError(
                    mapper.fromError(
                      error: e,
                      errorMapper: errorMapper,
                      errorExtraMapper: errorExtraMapper,
                      shouldHandleUnauthorizedRequest:
                          shouldHandleUnauthorizedRequest,
                      settings: settings,
                      isOnline: isOnline,
                    ),
                  );
                  // Source errors are terminal: always complete the stream.
                  finish();
                }

                if (mapper.willCheckOnline(e)) {
                  // The error is terminal, so stop listening first: otherwise the
                  // source's `done` could close the stream while the connectivity
                  // check is still running and the error would be lost.
                  final sub = subscription;
                  subscription = null;
                  sub?.cancel().catchError((_) {});
                  mapper.checkOnline(e).then(emitTerminalError);
                } else {
                  emitTerminalError(null);
                }
              },
              onDone: () => finish(abortRequest: false),
              cancelOnError: false,
            );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        if (finished) return null;
        finished = true;
        release();
        return null;
      },
    );
    return controller.stream;
  }
}

/// A lightweight [Response]-like shim used by the stream handlers to reuse
/// [_handleResponse] for status-code based error mapping.
///
/// It only exposes the fields that [_handleResponse] and [ApiHandler] need:
/// [statusCode], [statusMessage] and [data] (the already-read error body, if
/// any).
class _StreamStatusResponse implements Response<dynamic> {
  _StreamStatusResponse(this._statusCode, this._statusMessage, this._data);

  final int _statusCode;
  final String? _statusMessage;
  final dynamic _data;

  @override
  int? get statusCode => _statusCode;

  @override
  set statusCode(int? value) {}

  @override
  String? get statusMessage => _statusMessage;

  @override
  set statusMessage(String? value) {}

  @override
  dynamic get data => _data;

  @override
  set data(dynamic value) {}

  @override
  RequestOptions requestOptions = RequestOptions(path: '');

  @override
  bool isRedirect = false;

  @override
  List<RedirectRecord> redirects = const [];

  @override
  Headers headers = Headers();

  @override
  Map<String, dynamic> extra = <String, dynamic>{};

  @override
  Uri get realUri => Uri.parse('');
}
