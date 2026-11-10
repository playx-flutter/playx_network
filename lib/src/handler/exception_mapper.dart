import 'dart:async';
import 'dart:io';

import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/handler/handler_logger.dart';
import 'package:playx_network/src/utils/connection_utils.dart';

/// Turns failed responses and thrown errors into [NetworkException]s.
///
/// It owns everything needed to decide which exception a failure becomes: the
/// error mappers, the settings (messages, unauthorized codes), the unauthorized
/// request callback and the optional connectivity check. Per-request values
/// passed to its methods override the client-level ones.
class ExceptionMapper {
  ExceptionMapper({
    required this.errorMapper,
    this.errorExtraMapper,
    required this.settings,
    this.onUnauthorizedRequestReceived,
    this.hasInternetConnection,
    required this.log,
  });

  final ErrorMapper errorMapper;
  final ErrorExtraMapper? errorExtraMapper;
  final PlayxNetworkClientSettings settings;
  final UnauthorizedRequestHandler? onUnauthorizedRequestReceived;

  /// Optional app-provided check used to tell "no internet" from "server
  /// unreachable" once a connection failure happened.
  final FutureOr<bool> Function()? hasInternetConnection;

  final HandlerLogger log;

  /// The default [ErrorMapper]: reads the `message` of a [DefaultApiError].
  static String? defaultErrorMessage(dynamic json) {
    final DefaultApiError? error =
        json != null ? DefaultApiError.fromJson(json) : null;
    return error?.message;
  }

  /// Whether [checkOnline] would actually ask the app for connectivity for
  /// [error], that is a callback exists and [error] is a connection failure.
  bool willCheckOnline(Object? error) =>
      hasInternetConnection != null && isConnectionFailure(error);

  /// Asks [hasInternetConnection] whether the device is online, but only when
  /// [error] is a connection failure. Returns `null` when there is no
  /// callback, the error is something else, or the callback throws.
  Future<bool?> checkOnline(Object? error) async {
    final check = hasInternetConnection;
    if (check == null || !isConnectionFailure(error)) return null;
    try {
      return await check();
      // ignore: avoid_catches_without_on_clauses
    } catch (e, s) {
      log.error(
        text: 'hasInternetConnection threw',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Maps a response with an error status code to an exception, extracting the
  /// API message and the optional extra data from its body.
  NetworkException fromResponse(
      {Response? response,
      bool shouldHandleUnauthorizedRequest = true,
      ErrorMapper? errorMapper,
      ErrorExtraMapper? errorExtraMapper,
      PlayxNetworkClientSettings? settings}) {
    final cfg = settings ?? this.settings;
    final exceptionMessages = cfg.exceptionMessages;
    final shouldShowApiErrors = cfg.shouldShowApiErrors;
    final unauthorizedRequestCodes = cfg.unauthorizedRequestCodes;

    final dynamic errorJson = response?.data;

    String? errMsg;
    try {
      errMsg = (errorMapper ?? this.errorMapper)(errorJson);
    } catch (e, s) {
      log.error(
        text: 'Error while parsing error message $e',
        error: e,
        stackTrace: s,
      );
    }

    Object? extra;
    final extraMapper = errorExtraMapper ?? this.errorExtraMapper;
    if (extraMapper != null) {
      try {
        extra = extraMapper(errorJson);
      } catch (e, s) {
        log.error(
          text: 'Error while parsing error extra data $e',
          error: e,
          stackTrace: s,
        );
      }
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
          shouldShowApiError: shouldShowApiErrors,
          extra: extra);
    }

    return ApiException.fromStatusCode(
        statusCode: statusCode,
        apiErrorMessage: errMsg,
        exceptionMessages: exceptionMessages,
        shouldShowApiErrors: shouldShowApiErrors,
        extra: extra);
  }

  /// Maps a thrown [error] (usually a [DioException]) to an exception.
  ///
  /// [isOnline] is the answer of [checkOnline], see [buildConnectionException].
  NetworkException fromError(
      {dynamic error,
      ErrorMapper? errorMapper,
      ErrorExtraMapper? errorExtraMapper,
      bool shouldHandleUnauthorizedRequest = true,
      PlayxNetworkClientSettings? settings,
      bool? isOnline}) {
    final cfg = settings ?? this.settings;
    final exceptionMessages = cfg.exceptionMessages;
    final shouldShowApiErrors = cfg.shouldShowApiErrors;

    if (isTlsFailure(error)) {
      return SecureConnectionException(
        errorMessage: exceptionMessages.secureConnectionError,
      );
    }

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
                ? buildConnectionException(
                    error: error,
                    messages: exceptionMessages,
                    isOnline: isOnline,
                  )
                : UnexpectedErrorException(
                    errorMessage: exceptionMessages.unexpectedError,
                  ),
            DioExceptionType.receiveTimeout => ReceiveTimeoutException(
                errorMessage: exceptionMessages.receiveTimeout,
              ),
            DioExceptionType.badResponse => fromResponse(
                response: error.response,
                errorMapper: errorMapper,
                errorExtraMapper: errorExtraMapper,
                shouldHandleUnauthorizedRequest:
                    shouldHandleUnauthorizedRequest,
                settings: settings),
            DioExceptionType.sendTimeout => SendTimeoutException(
                errorMessage: exceptionMessages.sendTimeout,
              ),
            DioExceptionType.badCertificate => SecureConnectionException(
                errorMessage: exceptionMessages.secureConnectionError,
              ),
            DioExceptionType.connectionError => buildConnectionException(
                error: error,
                messages: exceptionMessages,
                isOnline: isOnline,
              ),
            // Parsing the response took too long: the data arrived but could
            // not be processed in time.
            DioExceptionType.transformTimeout => UnableToProcessException(
                errorMessage: exceptionMessages.unableToProcess,
                statusCode: -1,
                shouldShowApiError: false,
              ),
          };
        } else if (error is SocketException) {
          networkExceptions = buildConnectionException(
            error: error,
            messages: exceptionMessages,
            isOnline: isOnline,
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
}
