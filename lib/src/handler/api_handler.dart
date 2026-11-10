import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:playx_core/playx_core.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/handler/exception_mapper.dart';
import 'package:playx_network/src/handler/handler_logger.dart';
import 'package:playx_network/src/utils/json_utils.dart';

// ignore: avoid_classes_with_only_static_members
/// This class is responsible for handling the network response and extract error from it.
/// and return the result whether it was successful or not.
class ApiHandler {
  ApiHandler({
    required ErrorMapper errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    required this.settings,
    UnauthorizedRequestHandler? onUnauthorizedRequestReceived,
    FutureOr<bool> Function()? hasInternetConnection,
    required PlayxBaseLogger logger,
  })  : _log = HandlerLogger(logger: logger, settings: settings),
        _mapper = ExceptionMapper(
          errorMapper: errorMapper,
          errorExtraMapper: errorExtraMapper,
          settings: settings,
          onUnauthorizedRequestReceived: onUnauthorizedRequestReceived,
          hasInternetConnection: hasInternetConnection,
          log: HandlerLogger(logger: logger, settings: settings),
        );

  final PlayxNetworkClientSettings settings;
  final HandlerLogger _log;
  final ExceptionMapper _mapper;

  ExceptionMessage buildExceptionMessages(
          PlayxNetworkClientSettings? settings) =>
      (settings ?? this.settings).exceptionMessages;

  bool buildShouldShowApiErrors(PlayxNetworkClientSettings? settings) =>
      (settings ?? this.settings).shouldShowApiErrors;

  bool attachLogSettings(PlayxNetworkClientSettings? settings) =>
      (settings ?? this.settings).logSettings.enabled;

  List<int> buildUnauthorizedRequestCodes(
          PlayxNetworkClientSettings? settings) =>
      (settings ?? this.settings).unauthorizedRequestCodes;

  List<int> buildSuccessCodes(PlayxNetworkClientSettings? settings) =>
      (settings ?? this.settings).successRequestCodes;

  bool useIsolateForMappingJson(PlayxNetworkClientSettings? settings) =>
      (settings ?? this.settings).useIsolateForMappingJson;

  bool useWorkManagerForMappingJsonInIsolate(
          PlayxNetworkClientSettings? settings) =>
      (settings ?? this.settings).useWorkMangerForMappingJsonInIsolate;

  bool treatEmptyResponseAsSuccess(PlayxNetworkClientSettings? settings) =>
      (settings ?? this.settings).treatEmptyResponseAsSuccess;

  /// Returns the exception for [response] when its status code is not one of
  /// the success codes (a `400` is always an error), or `null` for a success.
  /// The error is logged.
  NetworkException? _errorForStatus({
    required Response response,
    required bool shouldHandleUnauthorizedRequest,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    PlayxNetworkClientSettings? settings,
  }) {
    final isSuccess = response.statusCode != HttpStatus.badRequest &&
        buildSuccessCodes(settings).contains(response.statusCode);
    if (isSuccess) return null;

    final exception = _mapper.fromResponse(
      response: response,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
    );
    _log.error(
      text: 'ERROR ${response.statusCode} ${response.statusMessage}',
      error: exception,
    );
    return exception;
  }

  /// Whether a response body carries no data at all.
  bool _isEmptyBody(dynamic data) =>
      data == null || (data is String && data.isEmpty);

  /// Logs and returns an [EmptyResponseException] result. [data] is only used
  /// for the log.
  NetworkResult<R> _emptyResponseError<R>(
    dynamic data,
    PlayxNetworkClientSettings? settings,
  ) {
    final exceptionMessages = buildExceptionMessages(settings);
    _log.error(
      text: exceptionMessages.emptyResponse,
      error: data,
    );
    return NetworkResult.error(EmptyResponseException(
      errorMessage: exceptionMessages.emptyResponse,
      statusCode: -1,
      shouldShowApiError: buildShouldShowApiErrors(settings),
    ));
  }

  /// Awaits [future] (the mapping of a response) and turns it into a success,
  /// or into a [RequestCanceledException] when [cancelToken] is cancelled
  /// while it runs. Other errors are rethrown for the caller to handle.
  Future<NetworkResult<R>> _awaitCancelable<R>(
    Future<R> future,
    CancelToken? cancelToken,
    ExceptionMessage exceptionMessages,
  ) async {
    var isFinished = false;
    final cancelable = Cancelable.fromFuture(future);
    cancelToken?.whenCancel.then((_) {
      if (!isFinished) cancelable.cancel();
    });

    try {
      final result = await cancelable;
      if (cancelToken?.isCancelled ?? false) {
        return NetworkResult.error(RequestCanceledException(
            errorMessage: exceptionMessages.requestCancelled));
      }
      return NetworkResult.success(result);
    } on CanceledError {
      return NetworkResult.error(RequestCanceledException(
          errorMessage: exceptionMessages.requestCancelled));
    } finally {
      isFinished = true;
    }
  }

  /// Logs an unexpected [error] and returns an [UnexpectedErrorException]
  /// result.
  NetworkResult<R> _unexpectedError<R>(
    Object error,
    StackTrace stackTrace,
    ExceptionMessage exceptionMessages,
  ) {
    _log.error(
      error: error,
      stackTrace: stackTrace,
    );
    return NetworkResult.error(UnexpectedErrorException(
      errorMessage: exceptionMessages.unexpectedError,
    ));
  }

  /// Handles a response that maps to a single object of type [T].
  ///
  /// When [fromJson] is `null` any successful response is a success with a
  /// `null` value (used by `delete` without a mapper); [T] must then be
  /// nullable, `void` or `dynamic`.
  ///
  /// When [allowEmptyResponse] is `true`, a successful response with an empty
  /// body (`null` or `""`) is a success: [fromJson] is called with `null` and
  /// no `dataKey` extraction is attempted, instead of returning an
  /// [EmptyResponseException].
  Future<NetworkResult<T>> handleNetworkResult<T>({
    required Response response,
    required JsonMapper<T>? fromJson,
    bool allowEmptyResponse = false,
    String? dataKey,
    CancelToken? cancelToken,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final exceptionMessages = buildExceptionMessages(settings);
    final shouldShowApiErrors = buildShouldShowApiErrors(settings);
    try {
      final statusError = _errorForStatus(
        response: response,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      if (statusError != null) return NetworkResult.error(statusError);

      final data = response.data;

      if (fromJson == null) {
        if (null is T) return NetworkResult.success(null as T);
        return ApiHandler.unableToProcessException(
          e: ArgumentError('fromJson is required when T is non-nullable'),
          exceptionMessage: exceptionMessages.unableToProcess,
          shouldShowApiErrors: shouldShowApiErrors,
        );
      }

      if (_isEmptyBody(data)) {
        if (!allowEmptyResponse) return _emptyResponseError(data, settings);
        // Nothing to extract a `dataKey` from: the mapper gets `null`.
        try {
          return NetworkResult.success(await fromJson(null));
          // ignore: avoid_catches_without_on_clauses
        } catch (e, s) {
          return ApiHandler.unableToProcessException(
            e: e,
            s: s,
            exceptionMessage: exceptionMessages.unableToProcess,
            shouldShowApiErrors: shouldShowApiErrors,
          );
        }
      }

      final actualData =
          dataKey != null ? getJsonValueOrNull(data, dataKey) : data;

      try {
        final future = Future.value(useIsolateForMappingJson(settings)
            ? MapUtils.mapAsyncInIsolate(
                data: actualData,
                mapper: fromJson,
                useWorkManager: useWorkManagerForMappingJsonInIsolate(settings),
                printError: false,
              )
            : fromJson(actualData));
        return await _awaitCancelable(future, cancelToken, exceptionMessages);
        // ignore: avoid_catches_without_on_clauses
      } catch (e, s) {
        return ApiHandler.unableToProcessException(
          e: e,
          s: s,
          exceptionMessage: exceptionMessages.unableToProcess,
          shouldShowApiErrors: shouldShowApiErrors,
        );
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      return _unexpectedError(e, s, exceptionMessages);
    }
  }

  /// Handles a response that maps to a list of [T].
  ///
  /// An empty body or an empty list is an [EmptyResponseException] unless the
  /// settings enable `treatEmptyResponseAsSuccess`, which returns an empty
  /// list instead.
  Future<NetworkResult<List<T>>> handleNetworkResultForList<T>({
    required Response response,
    required JsonMapper<T> fromJson,
    String? dataKey,
    String? itemDataKey,
    CancelToken? cancelToken,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final exceptionMessages = buildExceptionMessages(settings);
    final shouldShowApiErrors = buildShouldShowApiErrors(settings);
    final emptyIsSuccess = treatEmptyResponseAsSuccess(settings);

    try {
      final statusError = _errorForStatus(
        response: response,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      if (statusError != null) return NetworkResult.error(statusError);

      final data = response.data;

      if (_isEmptyBody(data)) {
        return emptyIsSuccess
            ? NetworkResult.success(<T>[])
            : _emptyResponseError(data, settings);
      }

      final actualData =
          dataKey != null ? getJsonValueOrNull(data, dataKey) : data;

      if (actualData is! List) {
        _log.error(
          text: 'Response is not a List',
          error: response,
        );
        return ApiHandler.unableToProcessException(
          e: 'Response is not a List',
          exceptionMessage: exceptionMessages.unableToProcess,
          shouldShowApiErrors: shouldShowApiErrors,
        );
      }

      try {
        final List<dynamic> itemsToMap = itemDataKey == null
            ? actualData
            : actualData
                .map((item) =>
                    getJsonValueOrNull(item, itemDataKey) ?? item)
                .toList();

        final Future<List<T>> future = useIsolateForMappingJson(settings)
            ? itemsToMap.asyncMapInIsolate(
                mapper: fromJson,
                useWorkManager: useWorkManagerForMappingJsonInIsolate(settings),
                printError: false,
                printEachItemError: false)
            : Future.wait(itemsToMap.map((item) async => await fromJson(item)));

        final mapped =
            await _awaitCancelable(future, cancelToken, exceptionMessages);
        final result = mapped.data;
        // `data` is only null when the mapping was cancelled.
        if (result == null) return mapped;

        if (result.isEmpty && !emptyIsSuccess) {
          return _emptyResponseError(result, settings);
        }
        return NetworkResult.success(result);
        // ignore: avoid_catches_without_on_clauses
      } catch (e, s) {
        return ApiHandler.unableToProcessException(
          e: e,
          s: s,
          exceptionMessage: exceptionMessages.unableToProcess,
          shouldShowApiErrors: shouldShowApiErrors,
        );
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      return _unexpectedError(e, s, exceptionMessages);
    }
  }

  Future<NetworkResult<Response>> handleNetworkResultForDownload({
    required Response<dynamic> response,
    required bool shouldHandleUnauthorizedRequest,
    CancelToken? cancelToken,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    PlayxNetworkClientSettings? settings,
  }) async {
    final exceptionMessages = buildExceptionMessages(settings);

    try {
      final statusError = _errorForStatus(
        response: response,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      if (statusError != null) return NetworkResult.error(statusError);

      if (cancelToken?.isCancelled ?? false) {
        return NetworkResult.error(RequestCanceledException(
            errorMessage: exceptionMessages.requestCancelled));
      }
      return NetworkResult.success(response);
      // ignore: avoid_catches_without_on_clauses
    } on Exception catch (e, s) {
      _log.error(
        text: exceptionMessages.unexpectedError,
        error: e,
        stackTrace: s,
      );
      return NetworkResult.error(UnexpectedErrorException(
        errorMessage: exceptionMessages.unexpectedError,
      ));
    }
  }

  /// Handles a streaming [ResponseBody] and returns a
  /// [NetworkStreamResult] of the decoded events.
  ///
  /// The generic type [T] is inferred from [format]:
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
  Future<NetworkStreamResult<T>> handleStreamResult<T>({
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
    final successCodes = buildSuccessCodes(settings);

    if (!successCodes.contains(statusCode) || responseBody == null) {
      final errorBody = await _readErrorBody(responseBody, abort);
      final exception = _mapper.fromResponse(
        response: _StreamStatusResponse(statusCode, statusMessage, errorBody),
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      _log.error(
        text: 'STREAM ERROR $statusCode $statusMessage',
        error: exception,
      );
      return NetworkStreamResult.error(exception);
    }

    return NetworkStreamResult.success(_bindStream<T>(
      responseBody: responseBody,
      format: format,
      statusCode: statusCode,
      cancelToken: cancelToken,
      abort: abort,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
    ));
  }

  /// Maximum number of bytes read from a non-success streaming response body
  /// when looking for the server's error message.
  static const int _maxErrorBodyBytes = 64 * 1024;

  /// Reads up to [_maxErrorBodyBytes] of [body], then closes it.
  /// Returns the decoded JSON, the plain text if it is not JSON, or `null`.
  Future<dynamic> _readErrorBody(
      ResponseBody? body, void Function()? abort) async {
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
    final exceptionMessages = buildExceptionMessages(settings);
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
      emitError(RequestCanceledException(
          errorMessage: exceptionMessages.requestCancelled));
      finish();
    });

    controller = StreamController<T>(
      onListen: () {
        if (finished) return;
        subscription = format.decodeStream(responseBody.stream).listen(
          (event) {
            if (finished) return;
            try {
              controller.add(event as T);
            } catch (e, s) {
              _log.error(
                text: exceptionMessages.unableToProcess,
                error: e,
                stackTrace: s,
              );
              emitError(UnableToProcessException(
                errorMessage: exceptionMessages.unableToProcess,
                statusCode: statusCode,
                shouldShowApiError: buildShouldShowApiErrors(settings),
              ));
            }
          },
          onError: (Object e, StackTrace s) {
            if (finished) return;
            _log.error(
              text: 'Stream error',
              error: e,
              stackTrace: s,
            );
            if (e is FormatException) {
              // A malformed element does not break the connection; report it
              // and keep reading.
              emitError(UnableToProcessException(
                errorMessage: exceptionMessages.unableToProcess,
                statusCode: statusCode,
                shouldShowApiError: buildShouldShowApiErrors(settings),
              ));
              return;
            }
            void emitTerminalError(bool? isOnline) {
              emitError(_mapper.fromError(
                error: e,
                errorMapper: errorMapper,
                errorExtraMapper: errorExtraMapper,
                shouldHandleUnauthorizedRequest:
                    shouldHandleUnauthorizedRequest,
                settings: settings,
                isOnline: isOnline,
              ));
              // Source errors are terminal: always complete the stream.
              finish();
            }

            if (_mapper.willCheckOnline(e)) {
              // The error is terminal, so stop listening first: otherwise the
              // source's `done` could close the stream while the connectivity
              // check is still running and the error would be lost.
              final sub = subscription;
              subscription = null;
              sub?.cancel().catchError((_) {});
              _mapper.checkOnline(e).then(emitTerminalError);
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

  Future<NetworkResult<T>> handleDioException<T>({
    dynamic error,
    dynamic stackTrace,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    _log.error(
      text: 'DioException occurred:',
      error: error,
      stackTrace: stackTrace,
    );
    final isOnline = await _mapper.checkOnline(error);
    return NetworkResult.error(_mapper.fromError(
        error: error,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        isOnline: isOnline));
  }

  static NetworkResult<T> unableToProcessException<T>({
    dynamic e,
    dynamic s,
    required String exceptionMessage,
    bool shouldShowApiErrors = false,
  }) {
    PlayxLogger.getLogger('Playx Network')
        ?.e(exceptionMessage, error: e, stackTrace: s);
    return NetworkResult<T>.error(
      UnableToProcessException(
          errorMessage: exceptionMessage,
          statusCode: -1,
          shouldShowApiError: shouldShowApiErrors),
    );
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
