import 'dart:async';
import 'dart:io';

import 'package:playx_core/playx_core.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/handler/exception_mapper.dart';
import 'package:playx_network/src/handler/handler_logger.dart';
import 'package:playx_network/src/handler/stream_response_handler.dart';
import 'package:playx_network/src/utils/json_utils.dart';

/// Turns Dio responses and errors into results.
///
/// It maps successful responses to models (single, list and download results),
/// and delegates the rest: failures become exceptions through [ExceptionMapper],
/// streaming responses are handled by [StreamResponseHandler] and logging goes
/// through [HandlerLogger]. Per-request `settings` passed to its methods
/// override the client-level [settings].
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
  late final StreamResponseHandler _streams = StreamResponseHandler(
    settings: settings,
    mapper: _mapper,
    log: _log,
  );

  /// The effective settings: the per-request [override] if given, otherwise
  /// the client-level ones.
  PlayxNetworkClientSettings _cfg(PlayxNetworkClientSettings? override) =>
      override ?? settings;

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
        _cfg(settings).successRequestCodes.contains(response.statusCode);
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
    final exceptionMessages = _cfg(settings).exceptionMessages;
    _log.error(
      text: exceptionMessages.emptyResponse,
      error: data,
    );
    return NetworkResult.error(EmptyResponseException(
      errorMessage: exceptionMessages.emptyResponse,
      statusCode: -1,
      shouldShowApiError: _cfg(settings).shouldShowApiErrors,
    ));
  }

  /// Awaits [future] (the mapping of a response) and turns it into a success,
  /// or into a [RequestCanceledException] when [cancelToken] is cancelled
  /// before the mapping finishes. Other errors are rethrown for the caller to
  /// handle.
  ///
  /// Whichever of the two happens first decides the result; the other one is
  /// ignored, so cancelling exactly while the mapping completes is safe. A
  /// mapping that is cancelled keeps running in the background, its result is
  /// simply dropped.
  Future<NetworkResult<R>> _awaitCancelable<R>(
    Future<R> future,
    CancelToken? cancelToken,
    ExceptionMessage exceptionMessages,
  ) {
    NetworkResult<R> cancelled() => NetworkResult.error(RequestCanceledException(
        errorMessage: exceptionMessages.requestCancelled));

    if (cancelToken == null) {
      return future.then((value) => NetworkResult.success(value));
    }

    final completer = Completer<NetworkResult<R>>();
    cancelToken.whenCancel.then((_) {
      if (!completer.isCompleted) completer.complete(cancelled());
    });
    future.then((value) {
      if (completer.isCompleted) return;
      completer.complete(
        cancelToken.isCancelled ? cancelled() : NetworkResult.success(value),
      );
    }, onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    });
    return completer.future;
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
    final exceptionMessages = _cfg(settings).exceptionMessages;
    final shouldShowApiErrors = _cfg(settings).shouldShowApiErrors;
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
        final future = Future.value(_cfg(settings).useIsolateForMappingJson
            ? MapUtils.mapAsyncInIsolate(
                data: actualData,
                mapper: fromJson,
                useWorkManager: _cfg(settings).useWorkMangerForMappingJsonInIsolate,
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
    final exceptionMessages = _cfg(settings).exceptionMessages;
    final shouldShowApiErrors = _cfg(settings).shouldShowApiErrors;
    final emptyIsSuccess = _cfg(settings).treatEmptyResponseAsSuccess;

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

        final Future<List<T>> future = _cfg(settings).useIsolateForMappingJson
            ? itemsToMap.asyncMapInIsolate(
                mapper: fromJson,
                useWorkManager: _cfg(settings).useWorkMangerForMappingJsonInIsolate,
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
    final exceptionMessages = _cfg(settings).exceptionMessages;

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
    } catch (e, s) {
      return _unexpectedError(e, s, exceptionMessages);
    }
  }

  /// Handles a streaming response, see [StreamResponseHandler.handle].
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
  }) =>
      _streams.handle<T>(
        responseBody: responseBody,
        statusCode: statusCode,
        statusMessage: statusMessage,
        format: format,
        cancelToken: cancelToken,
        abort: abort,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );

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
