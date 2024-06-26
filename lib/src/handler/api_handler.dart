import 'dart:io';

import 'package:dio/dio.dart';
import 'package:playx_network/src/models/exceptions/message/english_exception_message.dart';
import 'package:playx_network/src/models/exceptions/message/exception_message.dart';
import 'package:playx_network/src/utils/utils.dart';

import '../models/error/api_error.dart';
import '../models/exceptions/network_exception.dart';
import '../models/network_result.dart';
import '../playx_network_client.dart';

// ignore: avoid_classes_with_only_static_members
/// This class is responsible for handling the network response and extract error from it.
/// and return the result whether it was successful or not.
class ApiHandler {
  final ErrorMapper errorMapper;

  /// Whether or not it should show the error from the api response.
  final bool shouldShowApiErrors;
  final ExceptionMessage exceptionMessages;
  final UnauthorizedRequestHandler? onUnauthorizedRequestReceived;
  final List<int> unauthorizedRequestCodes;
  final List<int> successCodes;
  final bool attachLoggerOnDebug;

  ApiHandler({
    required this.errorMapper,
    this.shouldShowApiErrors = true,
    this.exceptionMessages = const DefaultEnglishExceptionMessage(),
    this.onUnauthorizedRequestReceived,
    this.unauthorizedRequestCodes = const [401, 403],
    this.successCodes = const [200, 201],
    this.attachLoggerOnDebug = true,
  });

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
            final result = fromJson(data);
            return NetworkResult.success(result);
            // ignore: avoid_catches_without_on_clauses
          } on Exception catch (e, s) {
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
            final List<T> result =
                (data as List).map((item) => fromJson(item)).toList();
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
            // ignore: avoid_catches_without_on_clauses
          } on Exception catch (e, s) {
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
    if (attachLoggerOnDebug) {
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

  void _printStackTrace(String msg) {
    final lines = msg.split('\n');
    for (var i = 0; i < lines.length; ++i) {
      final text = lines[i];
      final error = '\x1B[31m$text\x1B[0m';
      //ignore: avoid_print
      print((i >= 0 ? '║ ' : '') + error);
    }
  }
}
