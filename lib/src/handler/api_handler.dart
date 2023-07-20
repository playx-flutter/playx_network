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

  Future<NetworkResult<T>> handleNetworkResult<T>(
    Response response,
    JsonMapper<T> fromJson,
  ) async {
    try {
      final correctCodes = [
        200,
        201,
      ];

      if (response.statusCode == HttpStatus.badRequest ||
          !correctCodes.contains(response.statusCode)) {
        final NetworkException exception = _handleResponse(response);

        if (exception is UnauthorizedRequestException) {
          onUnauthorizedRequestReceived?.call();
        }
        return NetworkResult.error(exception);
      } else {
        if (isResponseBlank(response) ?? true) {
          return NetworkResult.error(UnexpectedErrorException(
            exceptionMessage: exceptionMessages,
          ));
        } else {
          final data = response.data;

          if (data == null) {
            return NetworkResult.error(EmptyResponseException(
                exceptionMessage: exceptionMessages,
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
                  exceptionMessage: exceptionMessages,
                  shouldShowApiError: shouldShowApiErrors),
            );
          }
        }
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      log('Playx Network Error : ', error: e);
      return NetworkResult.error(UnexpectedErrorException(
        exceptionMessage: exceptionMessages,
      ));
    }
  }

  Future<NetworkResult<List<T>>> handleNetworkResultForList<T>(
    Response response,
    JsonMapper<T> fromJson,
  ) async {
    try {
      final correctCodes = [
        200,
        201,
      ];

      if (response.statusCode == HttpStatus.badRequest ||
          !correctCodes.contains(response.statusCode)) {
        final NetworkException exception = _handleResponse(response);
        if (exception is UnauthorizedRequestException) {
          onUnauthorizedRequestReceived?.call();
        }
        return NetworkResult.error(exception);
      } else {
        if (isResponseBlank(response) ?? true) {
          return NetworkResult.error(UnexpectedErrorException(
            exceptionMessage: exceptionMessages,
          ));
        } else {
          final data = response.data;

          if (data == null) {
            return NetworkResult.error(EmptyResponseException(
                exceptionMessage: exceptionMessages,
                shouldShowApiError: shouldShowApiErrors));
          }

          try {
            final List<T> result = (data as List)
                .map((item) => fromJson(item))
                .toList();
            if (result.isEmpty) {
              return NetworkResult.error(EmptyResponseException(
                  exceptionMessage: exceptionMessages,
                  shouldShowApiError: shouldShowApiErrors));
            }
            return NetworkResult.success(result);
            // ignore: avoid_catches_without_on_clauses
          } catch (e) {
            log('Playx Network Error : ', error: e);
            return NetworkResult.error(
              UnableToProcessException(
                  exceptionMessage: exceptionMessages,
                  shouldShowApiError: shouldShowApiErrors),
            );
          }
        }
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      log('Playx Network Error : ', error: e);
      return NetworkResult.error(UnexpectedErrorException(
        exceptionMessage: exceptionMessages,
      ));
    }
  }

  NetworkResult<T> handleDioException<T>(dynamic error) {
    return NetworkResult.error(_getDioException(error));
  }

  NetworkException _handleResponse(Response? response) {
    final dynamic errorJson = response?.data;

       String? errMsg;
      try{
        errMsg =  errorMapper(errorJson);
      }catch(_){}

      final int statusCode = response?.statusCode ?? -1;
      switch (statusCode) {
        case 400:
          return DefaultApiException(
              error: errMsg,
              exceptionMessage: exceptionMessages,
              shouldShowApiError: shouldShowApiErrors);
        case 401:
        case 403:
          return UnauthorizedRequestException(
              error: errMsg,
              exceptionMessage: exceptionMessages,
              shouldShowApiError: shouldShowApiErrors);
        case 404:
          return NotFoundException(
              error: errMsg,
              exceptionMessage: exceptionMessages,
              shouldShowApiError: shouldShowApiErrors);
        case 409:
          return ConflictException(
              error: errMsg,
              exceptionMessage: exceptionMessages,
              shouldShowApiError: shouldShowApiErrors);
        case 408:
          return RequestTimeoutException(
              error: errMsg,
              exceptionMessage: exceptionMessages,
              shouldShowApiError: shouldShowApiErrors);
        case 422:
          return UnableToProcessException(
              error: errMsg,
              exceptionMessage: exceptionMessages,
              shouldShowApiError: shouldShowApiErrors);
        case 500:
          return InternalServerErrorException(
              error: errMsg,
              exceptionMessage: exceptionMessages,
              shouldShowApiError: shouldShowApiErrors);
        case 503:
          return ServiceUnavailableException(
              error: errMsg,
              exceptionMessage: exceptionMessages,
              shouldShowApiError: shouldShowApiErrors);
        default:
          return DefaultApiException(
              error: errMsg,
              exceptionMessage: exceptionMessages,
              shouldShowApiError: shouldShowApiErrors);
      }
  }

  NetworkException _getDioException(dynamic error) {
    if (error is Exception) {
      try {
        NetworkException networkExceptions =
            UnexpectedErrorException(exceptionMessage: exceptionMessages);

        if (error is DioException) {
          networkExceptions = switch (error.type) {
            DioExceptionType.cancel => RequestCanceledException(
                exceptionMessage: exceptionMessages,
              ),
            DioExceptionType.connectionTimeout => RequestTimeoutException(
                exceptionMessage: exceptionMessages,
                shouldShowApiError: shouldShowApiErrors),
            DioExceptionType.unknown => error.error is SocketException
                ? NoInternetConnectionException(
                    exceptionMessage: exceptionMessages,
                  )
                : UnexpectedErrorException(
                    exceptionMessage: exceptionMessages,
                  ),
            DioExceptionType.receiveTimeout => SendTimeoutException(
                exceptionMessage: exceptionMessages,
              ),
            DioExceptionType.badResponse => _handleResponse(error.response),
            DioExceptionType.sendTimeout => SendTimeoutException(
                exceptionMessage: exceptionMessages,
              ),
            DioExceptionType.badCertificate => UnexpectedErrorException(
                exceptionMessage: exceptionMessages,
              ),
            DioExceptionType.connectionError => NoInternetConnectionException(
                exceptionMessage: exceptionMessages,
              ),
          };
        } else if (error is SocketException) {
          networkExceptions = NoInternetConnectionException(
            exceptionMessage: exceptionMessages,
          );
        } else {
          networkExceptions = UnexpectedErrorException(
            exceptionMessage: exceptionMessages,
          );
        }
        return networkExceptions;
      } on FormatException catch (_) {
        return FormatException(
          exceptionMessage: exceptionMessages,
        );
      } catch (_) {
        return UnexpectedErrorException(
          exceptionMessage: exceptionMessages,
        );
      }
    } else {
      if (error.toString().contains("is not a subtype of")) {
        return UnableToProcessException(
            exceptionMessage: exceptionMessages,
            shouldShowApiError: shouldShowApiErrors);
      } else {
        return UnexpectedErrorException(
          exceptionMessage: exceptionMessages,
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
