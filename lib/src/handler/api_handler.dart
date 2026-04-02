import 'dart:io';

import 'package:playx_core/playx_core.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/utils/utils.dart';

// ignore: avoid_classes_with_only_static_members
/// This class is responsible for handling the network response and extract error from it.
/// and return the result whether it was successful or not.
class ApiHandler {
  final ErrorMapper errorMapper;
  final PlayxNetworkClientSettings settings;
  final UnauthorizedRequestHandler? onUnauthorizedRequestReceived;

  final PlayxBaseLogger logger;

  ApiHandler({
    required this.errorMapper,
    required this.settings,
    this.onUnauthorizedRequestReceived,
    required this.logger,
  });

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

  Future<NetworkResult<T>> handleNetworkResult<T>({
    required Response response,
    required JsonMapper<T> fromJson,
    String? dataKey,
    CancelToken? cancelToken,
    ErrorMapper? errorMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final exceptionMessages = buildExceptionMessages(settings);
    final shouldShowApiErrors = buildShouldShowApiErrors(settings);
    final successCodes = buildSuccessCodes(settings);
    try {
      if (response.statusCode == HttpStatus.badRequest ||
          !successCodes.contains(response.statusCode)) {
        final NetworkException exception = _handleResponse(
            response: response,
            errorMapper: errorMapper,
            shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
        _printError(
          header: 'Playx Network Error :',
          text: 'ERROR ${response.statusCode} ${response.statusMessage}',
          error: exception,
        );
        return NetworkResult.error(exception);
      } else {
        if (isResponseBlank(response) ?? true) {
          _printError(
            header: 'Playx Network Error :',
            text: 'Response is blank or null',
            error: response,
          );
          return NetworkResult.error(UnexpectedErrorException(
            errorMessage: exceptionMessages.unexpectedError,
          ));
        } else {
          final data = response.data;

          if (data == null || (data is String && data.isEmpty)) {
            _printError(
              header: 'Playx Network Error :',
              text: exceptionMessages.emptyResponse,
              error: data,
            );
            return NetworkResult.error(EmptyResponseException(
                errorMessage: exceptionMessages.emptyResponse,
                statusCode: -1,
                shouldShowApiError: shouldShowApiErrors));
          }

          final actualData =
              dataKey != null ? _getJsonValueOrNull(data, dataKey) : data;

          try {
            bool useIsolate = useIsolateForMappingJson(settings);
            bool useWorkManager =
                useWorkManagerForMappingJsonInIsolate(settings);

            final future = Future.value(useIsolate
                ? MapUtils.mapAsyncInIsolate(
                    data: actualData,
                    mapper: fromJson,
                    useWorkManager: useWorkManager,
                    printError: false,
                  )
                : fromJson(actualData));

            bool isFinished = false;
            final cancelable = Cancelable.fromFuture(future);
            cancelToken?.whenCancel.then((_) {
              if (!isFinished) {
                cancelable.cancel();
              }
            });

            try {
              final result = await cancelable;
              isFinished = true;
              if (cancelToken?.isCancelled ?? false) {
                return NetworkResult.error(RequestCanceledException(
                    errorMessage: exceptionMessages.requestCancelled));
              }
              return NetworkResult.success(result);
            } on CanceledError {
              isFinished = true;
              return NetworkResult.error(RequestCanceledException(
                  errorMessage: exceptionMessages.requestCancelled));
            } catch (e) {
              isFinished = true;
              rethrow;
            }
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
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      _printError(
        header: 'Playx Network Error :',
        error: e,
        stackTrace: s,
      );
      return NetworkResult.error(UnexpectedErrorException(
        errorMessage: exceptionMessages.unexpectedError,
      ));
    }
  }

  Future<NetworkResult<List<T>>> handleNetworkResultForList<T>({
    required Response response,
    required JsonMapper<T> fromJson,
    String? dataKey,
    CancelToken? cancelToken,
    ErrorMapper? errorMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final exceptionMessages = buildExceptionMessages(settings);
    final shouldShowApiErrors = buildShouldShowApiErrors(settings);
    final successCodes = buildSuccessCodes(settings);

    try {
      if (response.statusCode == HttpStatus.badRequest ||
          !successCodes.contains(response.statusCode)) {
        final NetworkException exception = _handleResponse(
            response: response,
            errorMapper: errorMapper,
            shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
        _printError(
            header: 'Playx Network Error :',
            text: 'ERROR ${response.statusCode} ${response.statusMessage}',
            error: exception);
        return NetworkResult.error(exception);
      } else {
        if (isResponseBlank(response) ?? true) {
          _printError(
            header: 'Playx Network Error :',
            text: 'Response is blank or null',
            error: response,
          );
          return NetworkResult.error(UnexpectedErrorException(
            errorMessage: exceptionMessages.unexpectedError,
          ));
        } else {
          final data = response.data;

          if (data == null || (data is String && data.isEmpty)) {
            _printError(
              header: 'Playx Network Error :',
              text: exceptionMessages.emptyResponse,
              error: data,
            );
            return NetworkResult.error(EmptyResponseException(
                errorMessage: exceptionMessages.emptyResponse,
                statusCode: -1,
                shouldShowApiError: shouldShowApiErrors));
          }

          final actualData =
              dataKey != null ? _getJsonValueOrNull(data, dataKey) : data;

          try {
            if (actualData is List) {
              bool useIsolate = useIsolateForMappingJson(settings);
              bool useWorkManager =
                  useWorkManagerForMappingJsonInIsolate(settings);

              final future = useIsolate
                  ? actualData.asyncMapInIsolate(
                      mapper: fromJson,
                      useWorkManager: useWorkManager,
                      printError: false,
                      printEachItemError: false)
                  : Future.wait(
                      actualData.map((item) async => await fromJson(item)));

              bool isFinished = false;
              final cancelable = Cancelable.fromFuture(future);
              cancelToken?.whenCancel.then((_) {
                if (!isFinished) {
                  cancelable.cancel();
                }
              });

              late final List<T> result;
              try {
                result = await cancelable;
                isFinished = true;
                if (cancelToken?.isCancelled ?? false) {
                  return NetworkResult.error(RequestCanceledException(
                      errorMessage: exceptionMessages.requestCancelled));
                }
              } on CanceledError {
                isFinished = true;
                return NetworkResult.error(RequestCanceledException(
                    errorMessage: exceptionMessages.requestCancelled));
              } catch (e) {
                isFinished = true;
                rethrow;
              }

              if (result.isEmpty) {
                _printError(
                  header: 'Playx Network Error :',
                  text: exceptionMessages.emptyResponse,
                  error: result,
                );
                return NetworkResult.error(EmptyResponseException(
                    errorMessage: exceptionMessages.emptyResponse,
                    shouldShowApiError: shouldShowApiErrors,
                    statusCode: -1));
              }
              return NetworkResult.success(result);
            } else {
              _printError(
                header: 'Playx Network Error :',
                text: 'Response is not a List',
                error: response,
              );
              return ApiHandler.unableToProcessException(
                e: ApiHandler.unableToProcessException,
                exceptionMessage: exceptionMessages.unableToProcess,
                shouldShowApiErrors: shouldShowApiErrors,
              );
            }
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
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      _printError(
        header: 'Playx Network Error :',
        error: e,
        stackTrace: s,
      );
      return NetworkResult.error(UnexpectedErrorException(
        errorMessage: exceptionMessages.unexpectedError,
      ));
    }
  }

  Future<NetworkResult<Response>> handleNetworkResultForDownload({
    required Response<dynamic> response,
    required bool shouldHandleUnauthorizedRequest,
    CancelToken? cancelToken,
    ErrorMapper? errorMapper,
    PlayxNetworkClientSettings? settings,
  }) async {
    final exceptionMessages = buildExceptionMessages(settings);
    final successCodes = buildSuccessCodes(settings);

    try {
      if (response.statusCode == HttpStatus.badRequest ||
          !successCodes.contains(response.statusCode)) {
        final NetworkException exception = _handleResponse(
            response: response,
            errorMapper: errorMapper,
            shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
        _printError(
          header: 'Playx Network Error:',
          text: 'ERROR ${response.statusCode} ${response.statusMessage}',
          error: exception,
        );
        return NetworkResult.error(exception);
      } else {
        if (isResponseBlank(response) ?? true) {
          _printError(
            header: 'Playx Network Error :',
            text: 'Response is blank or null',
            error: response,
          );
          return NetworkResult.error(UnexpectedErrorException(
            errorMessage: exceptionMessages.unexpectedError,
          ));
        } else {
          if (cancelToken?.isCancelled ?? false) {
            return NetworkResult.error(RequestCanceledException(
                errorMessage: exceptionMessages.requestCancelled));
          }
          return NetworkResult.success(response);
        }
      }
      // ignore: avoid_catches_without_on_clauses
    } on Exception catch (e, s) {
      _printError(
        text: exceptionMessages.unexpectedError,
        error: e,
        stackTrace: s,
      );
      return NetworkResult.error(UnexpectedErrorException(
        errorMessage: exceptionMessages.unexpectedError,
      ));
    }
  }

  NetworkResult<T> handleDioException<T>({
    dynamic error,
    dynamic stackTrace,
    ErrorMapper? errorMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) {
    _printError(
      header: 'Playx Network (Dio) Error :',
      text: 'DioException occurred:',
      error: error,
      stackTrace: stackTrace,
    );
    return NetworkResult.error(_getDioException(
        error: error,
        errorMapper: errorMapper,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest));
  }

  NetworkException _handleResponse(
      {Response? response,
      bool shouldHandleUnauthorizedRequest = true,
      ErrorMapper? errorMapper,
      PlayxNetworkClientSettings? settings}) {
    final exceptionMessages = buildExceptionMessages(settings);
    final shouldShowApiErrors = buildShouldShowApiErrors(settings);
    final unauthorizedRequestCodes = buildUnauthorizedRequestCodes(settings);

    final dynamic errorJson = response?.data;

    String? errMsg;
    try {
      errMsg = (errorMapper ?? this.errorMapper)(errorJson);
    } catch (e, s) {
      _printError(
        header: 'Playx Network Error :',
        text: 'Error while parsing error message $e',
        error: e,
        stackTrace: s,
      );
    }

    final int statusCode = response?.statusCode ?? -1;

    if (unauthorizedRequestCodes.contains(statusCode)) {
      if (shouldHandleUnauthorizedRequest) {
        onUnauthorizedRequestReceived?.call(response);
      }
      return UnauthorizedRequestException(
          apiErrorMessage: errMsg,
          statusCode: statusCode,
          errorMessage: exceptionMessages.unauthorizedRequest,
          shouldShowApiError: shouldShowApiErrors);
    }

    return ApiException.fromStatusCode(
        statusCode: statusCode,
        apiErrorMessage: errMsg,
        exceptionMessages: exceptionMessages,
        shouldShowApiErrors: shouldShowApiErrors);
  }

  NetworkException _getDioException(
      {dynamic error,
      ErrorMapper? errorMapper,
      bool shouldHandleUnauthorizedRequest = true,
      PlayxNetworkClientSettings? settings}) {
    final exceptionMessages = buildExceptionMessages(settings);
    final shouldShowApiErrors = buildShouldShowApiErrors(settings);

    if (error is Exception) {
      try {
        NetworkException networkExceptions = UnexpectedErrorException(
            errorMessage: exceptionMessages.unexpectedError);

        if (error is DioException) {
          networkExceptions = switch (error.type) {
            DioExceptionType.cancel => RequestCanceledException(
                errorMessage: exceptionMessages.requestCancelled,
              ),
            DioExceptionType.connectionTimeout => RequestTimeoutException(
                errorMessage: exceptionMessages.requestTimeout,
                statusCode: -1,
                shouldShowApiError: shouldShowApiErrors),
            DioExceptionType.unknown => error.error is SocketException
                ? NoInternetConnectionException(
                    errorMessage: exceptionMessages.noInternetConnection,
                  )
                : UnexpectedErrorException(
                    errorMessage: exceptionMessages.unexpectedError,
                  ),
            DioExceptionType.receiveTimeout => SendTimeoutException(
                errorMessage: exceptionMessages.sendTimeout,
              ),
            DioExceptionType.badResponse => _handleResponse(
                response: error.response,
                errorMapper: errorMapper,
                shouldHandleUnauthorizedRequest:
                    shouldHandleUnauthorizedRequest),
            DioExceptionType.sendTimeout => SendTimeoutException(
                errorMessage: exceptionMessages.sendTimeout,
              ),
            DioExceptionType.badCertificate => UnexpectedErrorException(
                errorMessage: exceptionMessages.unexpectedError,
              ),
            DioExceptionType.connectionError => NoInternetConnectionException(
                errorMessage: exceptionMessages.noInternetConnection,
              ),
          };
        } else if (error is SocketException) {
          networkExceptions = NoInternetConnectionException(
            errorMessage: exceptionMessages.noInternetConnection,
          );
        } else {
          networkExceptions = UnexpectedErrorException(
            errorMessage: exceptionMessages.unexpectedError,
          );
        }
        return networkExceptions;
      } on FormatException catch (_) {
        return InvalidFormatException(
          errorMessage: exceptionMessages.formatException,
        );
      } catch (_) {
        return UnexpectedErrorException(
          errorMessage: exceptionMessages.unexpectedError,
        );
      }
    } else {
      if (error.toString().contains("is not a subtype of")) {
        return UnableToProcessException(
            errorMessage: exceptionMessages.unableToProcess,
            statusCode: -1,
            shouldShowApiError: false);
      } else {
        return UnexpectedErrorException(
          errorMessage: exceptionMessages.unexpectedError,
        );
      }
    }
  }

  static String? getErrorMessageFromResponse(dynamic json) {
    final DefaultApiError? error =
        json != null ? DefaultApiError.fromJson(json) : null;
    return error?.message;
  }

  void _printError(
      {String? header,
      String? text,
      Object? error,
      dynamic stackTrace,
      PlayxNetworkClientSettings? settings}) {
    final bool attachLogs = attachLogSettings(settings);
    if (attachLogs) {
      logger.e(text, error: error, stackTrace: stackTrace);
    }
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

  /// Internal helper to safely get a value from a JSON map by key.
  /// Returns null if the JSON is null, not a map, or if the key is missing.
  /// Supports dot-notation for nested keys (e.g., 'data.user.name' or 'data.users.0.name').
  static dynamic _getJsonValueOrNull(dynamic json, String key) {
    if (json == null) {
      return null;
    }

    if (json is Map && json.containsKey(key)) {
      return json[key];
    }

    if (key.contains('.')) {
      final keys = key.split('.');
      dynamic current = json;

      for (final k in keys) {
        if (current is Map) {
          if (!current.containsKey(k)) {
            return null;
          }
          current = current[k];
        } else if (current is List) {
          final index = int.tryParse(k);
          if (index == null || index < 0 || index >= current.length) {
            return null;
          }
          current = current[index];
        } else {
          return null;
        }
      }
      return current;
    }

    return null;
  }
}
