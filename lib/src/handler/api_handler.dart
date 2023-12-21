import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:playx_network/src/models/exceptions/message/english_exception_message.dart';
import 'package:playx_network/src/models/exceptions/message/exception_message.dart';
import 'package:playx_network/src/utils/utils.dart';
import '../playx_network_client.dart';
import '../models/error/api_error.dart';
import '../models/exceptions/network_exception.dart';
import '../models/network_result.dart';

// ignore: avoid_classes_with_only_static_members
/// This class is responsible for handling the network response and extract error from it.
/// and return the result whether it was successful or not.
class ApiHandler {
  final ErrorMapper errorMapper;

  /// Whether or not it should show the error from the api response.
  final bool shouldShowApiErrors;
  final ExceptionMessage exceptionMessages;
  final VoidCallback? onUnauthorizedRequestReceived;

  ApiHandler({
    required this.errorMapper,
    this.shouldShowApiErrors = true,
    this.exceptionMessages = const DefaultEnglishExceptionMessage(),
    this.onUnauthorizedRequestReceived,
  });

  Future<NetworkResult<T>> handleNetworkResult<T>({
    required Response response,
    required JsonMapper<T> fromJson,
    bool shouldHandleUnauthorizedRequest = true,
  }) async {
    try {
      final correctCodes = [
        200,
        201,
      ];

      if (response.statusCode == HttpStatus.badRequest ||
          !correctCodes.contains(response.statusCode)) {
        final NetworkException exception = _handleResponse(response: response, shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);

        return NetworkResult.error(exception);
      } else {
        if (isResponseBlank(response) ?? true) {
          return NetworkResult.error(UnexpectedErrorException(
            errorMessage: exceptionMessages.unexpectedError,
          ));
        } else {
          final data = response.data;

          if (data == null) {
            return NetworkResult.error(EmptyResponseException(
                errorMessage: exceptionMessages.emptyResponse,
                statusCode: -1,
                shouldShowApiError: shouldShowApiErrors));
          }

          try {
            final result = fromJson(data);
            return NetworkResult.success(result);
            // ignore: avoid_catches_without_on_clauses
          } catch (e) {
            log('Playx Network Error : ', error: e);
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
    } catch (e) {
      log('Playx Network Error : ', error: e);
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
      final correctCodes = [
        200,
        201,
      ];

      if (response.statusCode == HttpStatus.badRequest ||
          !correctCodes.contains(response.statusCode)) {
        final NetworkException exception = _handleResponse(response: response, shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
        return NetworkResult.error(exception);
      } else {
        if (isResponseBlank(response) ?? true) {
          return NetworkResult.error(UnexpectedErrorException(
            errorMessage: exceptionMessages.unexpectedError,
          ));
        } else {
          final data = response.data;

          if (data == null) {
            return NetworkResult.error(EmptyResponseException(
                errorMessage: exceptionMessages.emptyResponse,
                statusCode: -1,
                shouldShowApiError: shouldShowApiErrors));
          }

          try {
            final List<T> result =
                (data as List).map((item) => fromJson(item)).toList();
            if (result.isEmpty) {
              return NetworkResult.error(EmptyResponseException(
                  errorMessage: exceptionMessages.emptyResponse,
                  shouldShowApiError: shouldShowApiErrors, statusCode: -1));
            }
            return NetworkResult.success(result);
            // ignore: avoid_catches_without_on_clauses
          } catch (e) {
            log('Playx Network Error : ', error: e);
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
    } catch (e) {
      log('Playx Network Error : ', error: e);
      return NetworkResult.error(UnexpectedErrorException(
        errorMessage: exceptionMessages.unexpectedError,
      ));
    }
  }

  NetworkResult<T> handleDioException<T>({dynamic error, bool shouldHandleUnauthorizedRequest = true}) {
    return NetworkResult.error(_getDioException(error: error,shouldHandleUnauthorizedRequest :shouldHandleUnauthorizedRequest));
  }

  NetworkException _handleResponse({Response? response, bool shouldHandleUnauthorizedRequest = true }) {
    final dynamic errorJson = response?.data;

    String? errMsg;
    try {
      errMsg = errorMapper(errorJson);
    } catch (_) {}

    final int statusCode = response?.statusCode ?? -1;
    switch (statusCode) {
      case 400:
        return DefaultApiException(
            apiErrorMessage: errMsg,
            statusCode: statusCode,
            errorMessage: exceptionMessages.defaultError,
            shouldShowApiError: shouldShowApiErrors);
      case 401:
      case 403:
      if (shouldHandleUnauthorizedRequest ) {
        onUnauthorizedRequestReceived?.call();
      }

      return UnauthorizedRequestException(
            apiErrorMessage: errMsg,
          statusCode: statusCode,
          errorMessage: exceptionMessages.unauthorizedRequest,
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

  NetworkException _getDioException({dynamic error, bool shouldHandleUnauthorizedRequest = true}) {
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
            DioExceptionType.badResponse => _handleResponse(response: error.response,shouldHandleUnauthorizedRequest :shouldHandleUnauthorizedRequest),
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
}
