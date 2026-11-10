import 'package:playx_network/playx_network.dart';

/// Base class for handling API errors and providing suitable error messages.
sealed class NetworkException implements Exception {
  /// General error message.
  final String errorMessage;

  /// Whether to display the API error message.
  final bool shouldShowApiError;

  const NetworkException({
    required this.errorMessage,
    this.shouldShowApiError = true,
  });

  /// Returns the appropriate message.
  String get message => errorMessage;
}

/// Typed access to the custom error object of a [NetworkException].
///
/// Works on any [NetworkException], so no cast to [ApiException] is needed:
/// ```dart
/// final apiError = result.error?.extraAs<ApiError>();
/// ```
extension NetworkExceptionExtra on NetworkException {
  /// Returns the custom error object produced by the `errorExtraMapper` as
  /// [E], or `null` when there is none, it is not an [E], or this exception
  /// is not an [ApiException] (timeouts, no connection, ... have no response
  /// body).
  E? extraAs<E>() {
    final exception = this;
    if (exception is! ApiException) return null;
    final value = exception.extra;
    return value is E ? value : null;
  }
}

/// Exception for API-related errors.
class ApiException extends NetworkException {
  /// API-provided error message.
  final String? apiErrorMessage;

  /// HTTP status code.
  final int statusCode;

  /// Optional structured data extracted from the error response, such as a
  /// custom error model. It is produced by the `errorExtraMapper` of the client
  /// or of a single request and is `null` when no mapper was provided, when the
  /// mapper returned `null`, or when it threw (the failure is logged).
  final Object? extra;

  const ApiException({
    this.apiErrorMessage,
    this.statusCode = 400,
    required super.errorMessage,
    super.shouldShowApiError,
    this.extra,
  });

  @override
  String get message =>
      shouldShowApiError ? apiErrorMessage ?? errorMessage : errorMessage;

  /// Factory method to create an `ApiException` based on status code.
  static ApiException fromStatusCode({
    required int statusCode,
    required ExceptionMessage exceptionMessages,
    String? apiErrorMessage,
    bool shouldShowApiErrors = true,
    Object? extra,
  }) {
    switch (statusCode) {
      case 400:
        return DefaultApiException(
          apiErrorMessage: apiErrorMessage,
          statusCode: statusCode,
          errorMessage: exceptionMessages.defaultError,
          shouldShowApiError: shouldShowApiErrors,
          extra: extra,
        );
      case 404:
        return NotFoundException(
          apiErrorMessage: apiErrorMessage,
          statusCode: statusCode,
          errorMessage: exceptionMessages.notFound,
          shouldShowApiError: shouldShowApiErrors,
          extra: extra,
        );
      case 409:
        return ConflictException(
          apiErrorMessage: apiErrorMessage,
          statusCode: statusCode,
          errorMessage: exceptionMessages.conflict,
          shouldShowApiError: shouldShowApiErrors,
          extra: extra,
        );
      case 408:
        return RequestTimeoutException(
          apiErrorMessage: apiErrorMessage,
          statusCode: statusCode,
          errorMessage: exceptionMessages.requestTimeout,
          shouldShowApiError: shouldShowApiErrors,
          extra: extra,
        );
      case 422:
        return UnableToProcessException(
          apiErrorMessage: apiErrorMessage,
          statusCode: statusCode,
          errorMessage: exceptionMessages.unableToProcess,
          shouldShowApiError: shouldShowApiErrors,
          extra: extra,
        );
      case 500:
        return InternalServerErrorException(
          apiErrorMessage: apiErrorMessage,
          statusCode: statusCode,
          errorMessage: exceptionMessages.internalServerError,
          shouldShowApiError: shouldShowApiErrors,
          extra: extra,
        );
      case 503:
        return ServiceUnavailableException(
          apiErrorMessage: apiErrorMessage,
          statusCode: statusCode,
          errorMessage: exceptionMessages.serviceUnavailable,
          shouldShowApiError: shouldShowApiErrors,
          extra: extra,
        );
      default:
        return DefaultApiException(
          apiErrorMessage: apiErrorMessage,
          statusCode: statusCode,
          errorMessage: exceptionMessages.defaultError,
          shouldShowApiError: shouldShowApiErrors,
          extra: extra,
        );
    }
  }
}

/// Exception for unauthorized requests (401, 403).
class UnauthorizedRequestException extends ApiException {
  const UnauthorizedRequestException({
    super.apiErrorMessage,
    super.statusCode = 401,
    required super.errorMessage,
    super.shouldShowApiError,
    super.extra,
  });
}

/// Exception for "Not Found" errors (404).
class NotFoundException extends ApiException {
  const NotFoundException({
    super.apiErrorMessage,
    super.statusCode = 404,
    required super.errorMessage,
    super.shouldShowApiError,
    super.extra,
  });
}

/// Exception for conflicts (409).
class ConflictException extends ApiException {
  const ConflictException({
    super.apiErrorMessage,
    super.statusCode = 409,
    required super.errorMessage,
    super.shouldShowApiError,
    super.extra,
  });
}

/// Exception for request timeout (408).
class RequestTimeoutException extends ApiException {
  const RequestTimeoutException({
    super.apiErrorMessage,
    super.statusCode = 408,
    required super.errorMessage,
    super.shouldShowApiError,
    super.extra,
  });
}

/// Exception for unprocessable entity (422).
class UnableToProcessException extends ApiException {
  const UnableToProcessException({
    super.apiErrorMessage,
    super.statusCode = 422,
    required super.errorMessage,
    super.shouldShowApiError,
    super.extra,
  });
}

/// Exception for internal server errors (500).
class InternalServerErrorException extends ApiException {
  const InternalServerErrorException({
    super.apiErrorMessage,
    super.statusCode = 500,
    required super.errorMessage,
    super.shouldShowApiError,
    super.extra,
  });
}

/// Exception for service unavailable (503).
class ServiceUnavailableException extends ApiException {
  const ServiceUnavailableException({
    super.apiErrorMessage,
    super.statusCode = 503,
    required super.errorMessage,
    super.shouldShowApiError,
    super.extra,
  });
}

/// Exception for empty responses (204).
class EmptyResponseException extends ApiException {
  const EmptyResponseException({
    super.apiErrorMessage,
    super.statusCode = 204,
    required super.errorMessage,
    super.shouldShowApiError,
    super.extra,
  });
}

/// Default API exception (for unhandled errors).
class DefaultApiException extends ApiException {
  const DefaultApiException({
    super.apiErrorMessage,
    super.statusCode = 400,
    required super.errorMessage,
    super.shouldShowApiError,
    super.extra,
  });
}

/// Exception for request send timeout.
class SendTimeoutException extends NetworkException {
  const SendTimeoutException({required super.errorMessage});
}

/// Exception for a server that took too long to send the response.
class ReceiveTimeoutException extends NetworkException {
  const ReceiveTimeoutException({required super.errorMessage});
}

/// Exception for a failure to establish a secure (TLS/SSL) connection: the
/// server certificate is invalid, expired or untrusted, or the TLS handshake
/// failed. The server was reached, so this is not an offline problem.
class SecureConnectionException extends NetworkException {
  const SecureConnectionException({required super.errorMessage});
}

/// Exception for request cancellation.
class RequestCanceledException extends NetworkException {
  const RequestCanceledException({required super.errorMessage});
}

/// Exception for a server that could not be reached although the device has a
/// network: the connection was refused, reset, closed or timed out, or there is
/// no route to the host.
class ServerUnreachableException extends NetworkException {
  const ServerUnreachableException({required super.errorMessage});
}

/// Exception for a request that failed in the browser without a response,
/// which is most commonly caused by a CORS misconfiguration on the server.
///
/// Browsers hide the real reason for such failures, so this can also mean the
/// server is down. It is only created on the web.
class CorsException extends NetworkException {
  const CorsException({required super.errorMessage});
}

/// Exception for no internet connection.
class NoInternetConnectionException extends NetworkException {
  const NoInternetConnectionException({required super.errorMessage});
}

/// Exception for invalid response format.
class InvalidFormatException extends NetworkException {
  const InvalidFormatException({required super.errorMessage});
}

/// Exception for unexpected errors.
class UnexpectedErrorException extends NetworkException {
  const UnexpectedErrorException({required super.errorMessage});
}
