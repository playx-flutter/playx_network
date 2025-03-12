
import 'package:playx_network/playx_network.dart';

/// Base class for handling API errors and providing suitable error messages.
sealed class NetworkException  implements Exception{
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

/// Exception for API-related errors.
class ApiException extends NetworkException {
  /// API-provided error message.
  final String? apiErrorMessage;

  /// HTTP status code.
  final int statusCode;

  const ApiException({
    this.apiErrorMessage,
    this.statusCode = 400,
    required super.errorMessage,
    super.shouldShowApiError,
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
  }) {
    switch (statusCode) {
      case 400:
        return DefaultApiException(
            apiErrorMessage: apiErrorMessage,
            statusCode: statusCode,
            errorMessage: exceptionMessages.defaultError,
            shouldShowApiError: shouldShowApiErrors);
      case 404:
        return NotFoundException(
            apiErrorMessage: apiErrorMessage,
            statusCode: statusCode,
            errorMessage: exceptionMessages.notFound,
            shouldShowApiError: shouldShowApiErrors);
      case 409:
        return ConflictException(
            apiErrorMessage: apiErrorMessage,
            statusCode: statusCode,
            errorMessage: exceptionMessages.conflict,
            shouldShowApiError: shouldShowApiErrors);
      case 408:
        return RequestTimeoutException(
            apiErrorMessage: apiErrorMessage,
            statusCode: statusCode,
            errorMessage: exceptionMessages.requestTimeout,
            shouldShowApiError: shouldShowApiErrors);
      case 422:
        return UnableToProcessException(
            apiErrorMessage: apiErrorMessage,
            statusCode: statusCode,
            errorMessage: exceptionMessages.unableToProcess,
            shouldShowApiError: shouldShowApiErrors);
      case 500:
        return InternalServerErrorException(
            apiErrorMessage: apiErrorMessage,
            statusCode: statusCode,
            errorMessage: exceptionMessages.internalServerError,
            shouldShowApiError: shouldShowApiErrors);
      case 503:
        return ServiceUnavailableException(
            apiErrorMessage: apiErrorMessage,
            statusCode: statusCode,
            errorMessage: exceptionMessages.serviceUnavailable,
            shouldShowApiError: shouldShowApiErrors);
      default:
        return DefaultApiException(
            apiErrorMessage: apiErrorMessage,
            statusCode: statusCode,
            errorMessage: exceptionMessages.defaultError,
            shouldShowApiError: shouldShowApiErrors);
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
  });
}

/// Exception for "Not Found" errors (404).
class NotFoundException extends ApiException {
  const NotFoundException({
    super.apiErrorMessage,
    super.statusCode = 404,
    required super.errorMessage,
    super.shouldShowApiError,
  });
}

/// Exception for conflicts (409).
class ConflictException extends ApiException {
  const ConflictException({
    super.apiErrorMessage,
    super.statusCode = 409,
    required super.errorMessage,
    super.shouldShowApiError,
  });
}

/// Exception for request timeout (408).
class RequestTimeoutException extends ApiException {
  const RequestTimeoutException({
    super.apiErrorMessage,
    super.statusCode = 408,
    required super.errorMessage,
    super.shouldShowApiError,
  });
}

/// Exception for unprocessable entity (422).
class UnableToProcessException extends ApiException {
  const UnableToProcessException({
    super.apiErrorMessage,
    super.statusCode = 422,
    required super.errorMessage,
    super.shouldShowApiError,
  });
}

/// Exception for internal server errors (500).
class InternalServerErrorException extends ApiException {
  const InternalServerErrorException({
    super.apiErrorMessage,
    super.statusCode = 500,
    required super.errorMessage,
    super.shouldShowApiError,
  });
}

/// Exception for service unavailable (503).
class ServiceUnavailableException extends ApiException {
  const ServiceUnavailableException({
    super.apiErrorMessage,
    super.statusCode = 503,
    required super.errorMessage,
    super.shouldShowApiError,
  });
}

/// Exception for empty responses (204).
class EmptyResponseException extends ApiException {
  const EmptyResponseException({
    super.apiErrorMessage,
    super.statusCode = 204,
    required super.errorMessage,
    super.shouldShowApiError,
  });
}

/// Default API exception (for unhandled errors).
class DefaultApiException extends ApiException {
  const DefaultApiException({
    super.apiErrorMessage,
    super.statusCode = 400,
    required super.errorMessage,
    super.shouldShowApiError,
  });
}

/// Exception for request send timeout.
class SendTimeoutException extends NetworkException {
  const SendTimeoutException({required super.errorMessage});
}

/// Exception for request cancellation.
class RequestCanceledException extends NetworkException {
  const RequestCanceledException({required super.errorMessage});
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
