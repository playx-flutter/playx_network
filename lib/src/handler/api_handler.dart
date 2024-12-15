import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/utils/utils.dart';

/// parses json to object in isolate.
Future<T> _parseJsonInIsolate<T>(List<dynamic> args) async {
  try {
    final data = args[0];
    final JsonMapper<T> fromJson = args[1];
    return fromJson(data);
  } catch (e, s) {
    ApiHandler.printError(text: e.toString(), stackTrace: s.toString());
    rethrow;
  }
}

/// parses json list to list of objects in isolate.
Future<List<T>> _parseJsonListInIsolate<T>(List<dynamic> args) async {
  try {
    final data = args[0] as List;
    final JsonMapper<T> fromJson = args[1];
    return await Future.wait(data.map((item) async => await fromJson(item)));
  } catch (e, s) {
    ApiHandler.printError(text: e.toString(), stackTrace: s.toString());
    rethrow;
  }
}

// ignore: avoid_classes_with_only_static_members
/// This class is responsible for handling the network response and extract error from it.
/// and return the result whether it was successful or not.
class ApiHandler {
  final ErrorMapper errorMapper;
  final PlayxNetworkClientSettings settings;
  final UnauthorizedRequestHandler? onUnauthorizedRequestReceived;

  ApiHandler({
    required this.errorMapper,
    required this.settings,
    this.onUnauthorizedRequestReceived,
  });

  ExceptionMessage get exceptionMessages => settings.exceptionMessages;

  bool get shouldShowApiErrors => settings.shouldShowApiErrors;

  bool get attachLogSettings =>
      kDebugMode && settings.logSettings.attachLoggerOnDebug ||
      kReleaseMode && settings.logSettings.attachLoggerOnRelease;

  List<int> get unauthorizedRequestCodes => settings.unauthorizedRequestCodes;

  List<int> get successCodes => settings.successRequestCodes;

  Future<NetworkResult<T>> handleNetworkResult<T>({
    required Response response,
    required JsonMapper<T> fromJson,
    bool shouldHandleUnauthorizedRequest = true,
  }) async {
    try {
      if (response.statusCode == HttpStatus.badRequest ||
          !successCodes.contains(response.statusCode)) {
        final NetworkException exception = _handleResponse(
            response: response,
            shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
        _printError(
          header: 'Playx Network Error :',
          text: exception.errorMessage,
        );
        return NetworkResult.error(exception);
      } else {
        if (isResponseBlank(response) ?? true) {
          _printError(
            header: 'Playx Network Error :',
            text: exceptionMessages.unexpectedError,
            stackTrace: response.toString(),
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
            );
            return NetworkResult.error(EmptyResponseException(
                errorMessage: exceptionMessages.emptyResponse,
                statusCode: -1,
                shouldShowApiError: shouldShowApiErrors));
          }

          try {
            final result = await compute(_parseJsonInIsolate, [data, fromJson]);
            return NetworkResult.success(result);
            // ignore: avoid_catches_without_on_clauses
          } catch (e, s) {
            _printError(
              header: 'Playx Network Error :',
              text: e.toString(),
              stackTrace: s.toString(),
            );
            return NetworkResult.error(
              UnableToProcessException(
                  errorMessage: exceptionMessages.unableToProcess,
                  statusCode: -1,
                  shouldShowApiError: shouldShowApiErrors),
            );
          }
        }
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      _printError(
        header: 'Playx Network Error :',
        text: e.toString(),
        stackTrace: s.toString(),
      );
      return NetworkResult.error(UnexpectedErrorException(
        errorMessage: exceptionMessages.unexpectedError,
      ));
    }
  }

  Future<NetworkResult<List<T>>> handleNetworkResultForList<T>({
    required Response response,
    required JsonMapper<T> fromJson,
    bool shouldHandleUnauthorizedRequest = true,
  }) async {
    try {
      if (response.statusCode == HttpStatus.badRequest ||
          !successCodes.contains(response.statusCode)) {
        final NetworkException exception = _handleResponse(
            response: response,
            shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
        _printError(
          header: 'Playx Network Error :',
          text: exception.errorMessage,
        );
        return NetworkResult.error(exception);
      } else {
        if (isResponseBlank(response) ?? true) {
          _printError(
            header: 'Playx Network Error :',
            text: exceptionMessages.unexpectedError,
            stackTrace: response.toString(),
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
            );
            return NetworkResult.error(EmptyResponseException(
                errorMessage: exceptionMessages.emptyResponse,
                statusCode: -1,
                shouldShowApiError: shouldShowApiErrors));
          }

          try {
            if (data is List) {
              final result =
                  await compute(_parseJsonListInIsolate<T>, [data, fromJson]);

              if (result.isEmpty) {
                _printError(
                  header: 'Playx Network Error :',
                  text: exceptionMessages.emptyResponse,
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
                text: exceptionMessages.unableToProcess,
              );
              return NetworkResult.error(UnableToProcessException(
                  errorMessage: exceptionMessages.unableToProcess,
                  shouldShowApiError: shouldShowApiErrors,
                  statusCode: -1));
            }
            // ignore: avoid_catches_without_on_clauses
          } catch (e, s) {
            _printError(
              header: 'Playx Network Error :',
              text: e.toString(),
              stackTrace: s.toString(),
            );
            return NetworkResult.error(
              UnableToProcessException(
                  errorMessage: exceptionMessages.unableToProcess,
                  statusCode: -1,
                  shouldShowApiError: shouldShowApiErrors),
            );
          }
        }
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      _printError(
        header: 'Playx Network Error :',
        text: e.toString(),
        stackTrace: s.toString(),
      );
      return NetworkResult.error(UnexpectedErrorException(
        errorMessage: exceptionMessages.unexpectedError,
      ));
    }
  }

  Future<NetworkResult<Response>> handleNetworkResultForDownload(
      {required Response<dynamic> response,
      required bool shouldHandleUnauthorizedRequest}) async {
    try {
      if (response.statusCode == HttpStatus.badRequest ||
          !successCodes.contains(response.statusCode)) {
        final NetworkException exception = _handleResponse(
            response: response,
            shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
        _printError(
          header: 'Playx Network Error :',
          text: exception.errorMessage,
        );
        return NetworkResult.error(exception);
      } else {
        if (isResponseBlank(response) ?? true) {
          _printError(
            header: 'Playx Network Error :',
            text: exceptionMessages.unexpectedError,
            stackTrace: response.toString(),
          );
          return NetworkResult.error(UnexpectedErrorException(
            errorMessage: exceptionMessages.unexpectedError,
          ));
        } else {
          return NetworkResult.success(response);
        }
      }
      // ignore: avoid_catches_without_on_clauses
    } on Exception catch (e, s) {
      _printError(
        header: 'Playx Network Error :',
        text: e.toString(),
        stackTrace: s.toString(),
      );
      return NetworkResult.error(UnexpectedErrorException(
        errorMessage: exceptionMessages.unexpectedError,
      ));
    }
  }

  NetworkResult<T> handleDioException<T>(
      {dynamic error,
      dynamic stackTrace,
      bool shouldHandleUnauthorizedRequest = true}) {
    _printError(
      header: 'Playx Network (Dio) Error :',
      text: error.toString(),
      stackTrace: stackTrace.toString(),
    );
    return NetworkResult.error(_getDioException(
        error: error,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest));
  }

  NetworkException _handleResponse(
      {Response? response, bool shouldHandleUnauthorizedRequest = true}) {
    final dynamic errorJson = response?.data;

    String? errMsg;
    try {
      errMsg = errorMapper(errorJson);
    } catch (e, s) {
      _printError(
        header: 'Playx Network Error :',
        text: 'Error while parsing error message $e',
        stackTrace: s.toString(),
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

    switch (statusCode) {
      case 400:
        return DefaultApiException(
            apiErrorMessage: errMsg,
            statusCode: statusCode,
            errorMessage: exceptionMessages.defaultError,
            shouldShowApiError: shouldShowApiErrors);
      case 404:
        return NotFoundException(
            apiErrorMessage: errMsg,
            statusCode: statusCode,
            errorMessage: exceptionMessages.notFound,
            shouldShowApiError: shouldShowApiErrors);
      case 409:
        return ConflictException(
            apiErrorMessage: errMsg,
            statusCode: statusCode,
            errorMessage: exceptionMessages.conflict,
            shouldShowApiError: shouldShowApiErrors);
      case 408:
        return RequestTimeoutException(
            apiErrorMessage: errMsg,
            statusCode: statusCode,
            errorMessage: exceptionMessages.requestTimeout,
            shouldShowApiError: shouldShowApiErrors);
      case 422:
        return UnableToProcessException(
            apiErrorMessage: errMsg,
            statusCode: statusCode,
            errorMessage: exceptionMessages.unableToProcess,
            shouldShowApiError: shouldShowApiErrors);
      case 500:
        return InternalServerErrorException(
            apiErrorMessage: errMsg,
            statusCode: statusCode,
            errorMessage: exceptionMessages.internalServerError,
            shouldShowApiError: shouldShowApiErrors);
      case 503:
        return ServiceUnavailableException(
            apiErrorMessage: errMsg,
            statusCode: statusCode,
            errorMessage: exceptionMessages.serviceUnavailable,
            shouldShowApiError: shouldShowApiErrors);
      default:
        return DefaultApiException(
            apiErrorMessage: errMsg,
            statusCode: statusCode,
            errorMessage: exceptionMessages.defaultError,
            shouldShowApiError: shouldShowApiErrors);
    }
  }

  NetworkException _getDioException(
      {dynamic error, bool shouldHandleUnauthorizedRequest = true}) {
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
        return FormatException(
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

  void _printError({String? header, String? text, String? stackTrace}) {
    if (attachLogSettings) {
      const maxWidth = 90;
      //ignore: avoid_print
      print('');
      //ignore: avoid_print
      print('╔╣ $header');
      final error = '\x1B[31m$text\x1B[0m';
      //ignore: avoid_print
      print('║  $error');
      _printStackTrace(stackTrace ?? '');
      //ignore: avoid_print
      print('╚${'═' * (maxWidth - 1)}╝');
    }
  }

  static void _printStackTrace(String msg) {
    final lines = msg.split('\n');
    for (var i = 0; i < lines.length; ++i) {
      final text = lines[i];
      final error = '\x1B[31m$text\x1B[0m';
      //ignore: avoid_print
      print((i >= 0 ? '║ ' : '') + error);
    }
  }

  static void printError({String? header, String? text, String? stackTrace}) {
    if (kReleaseMode) return;
    const maxWidth = 90;
    //ignore: avoid_print
    print('');
    //ignore: avoid_print
    print('╔╣ $header');
    final error = '\x1B[31m$text\x1B[0m';
    //ignore: avoid_print
    print('║  $error');
    _printStackTrace(stackTrace ?? '');
    //ignore: avoid_print
    print('╚${'═' * (maxWidth - 1)}╝');
  }
}
