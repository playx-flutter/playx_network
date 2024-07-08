///Base class for handling api errors and provides suitable error messages.
sealed class NetworkException {
  final String errorMessage;

  final bool shouldShowApiError;

  const NetworkException({
    required this.errorMessage,
    this.shouldShowApiError = true,
  });

  String get message => errorMessage;
}

class ApiException extends NetworkException {
  /// Error message from the api.
  final String? apiErrorMessage;

  /// Status code of the response.
  /// Returns -1 if the error is not returned from the api.
  final int statusCode;

  const ApiException(
      {this.apiErrorMessage,
      required this.statusCode,
      required super.errorMessage,
      super.shouldShowApiError});

  @override
  String get message =>
      shouldShowApiError ? apiErrorMessage ?? errorMessage : errorMessage;
}

/// Exception that occurs when receiving an unauthorized request from api mainly when receiving 401,403 error codes.
class UnauthorizedRequestException extends ApiException {
  const UnauthorizedRequestException(
      {super.apiErrorMessage,
      required super.statusCode,
      required super.errorMessage,
      super.shouldShowApiError});
}

/// Exception that occurs when receiving a not found request from api mainly when receiving 404 error code.
class NotFoundException extends ApiException {
  const NotFoundException(
      {super.apiErrorMessage,
      required super.statusCode,
      required super.errorMessage,
      super.shouldShowApiError});

  @override
  String get message =>
      shouldShowApiError ? apiErrorMessage ?? errorMessage : errorMessage;
}

/// Exception that occurs when there is a conflict from the API mainly when receiving 409 error code.
class ConflictException extends ApiException {
  const ConflictException(
      {super.apiErrorMessage,
      required super.statusCode,
      required super.errorMessage,
      super.shouldShowApiError});

  @override
  String get message =>
      shouldShowApiError ? apiErrorMessage ?? errorMessage : errorMessage;
}

/// Exception that occurs when the request has timed out.
class RequestTimeoutException extends ApiException {
  const RequestTimeoutException(
      {super.apiErrorMessage,
      required super.statusCode,
      required super.errorMessage,
      super.shouldShowApiError});

  @override
  String get message =>
      shouldShowApiError ? apiErrorMessage ?? errorMessage : errorMessage;
}

/// Exception that occurs when the client couldn't process the response successfully.
/// Can happen when the response returns status code 422.
/// Or the the model from json function has error on it.
class UnableToProcessException extends ApiException {
  const UnableToProcessException(
      {super.apiErrorMessage,
      required super.statusCode,
      required super.errorMessage,
      super.shouldShowApiError});

  @override
  String get message =>
      shouldShowApiError ? apiErrorMessage ?? errorMessage : errorMessage;
}

/// Exception that occurs when there's an internal server error.
/// Can happen when the response returns status code 500.
class InternalServerErrorException extends ApiException {
  const InternalServerErrorException(
      {super.apiErrorMessage,
      required super.statusCode,
      required super.errorMessage,
      super.shouldShowApiError});

  @override
  String get message =>
      shouldShowApiError ? apiErrorMessage ?? errorMessage : errorMessage;
}

/// Exception that occurs when the client receives service unavailable error.
/// Can happen when the response returns status code 503.
class ServiceUnavailableException extends ApiException {
  const ServiceUnavailableException(
      {super.apiErrorMessage,
      required super.statusCode,
      required super.errorMessage,
      super.shouldShowApiError});

  @override
  String get message =>
      shouldShowApiError ? apiErrorMessage ?? errorMessage : errorMessage;
}

/// Exception that occurs when the client receives empty response.
class EmptyResponseException extends ApiException {
  const EmptyResponseException(
      {super.apiErrorMessage,
      required super.statusCode,
      required super.errorMessage,
      super.shouldShowApiError});

  @override
  String get message =>
      shouldShowApiError ? apiErrorMessage ?? errorMessage : errorMessage;
}

/// Exception that occurs another api exception happens.
class DefaultApiException extends ApiException {
  const DefaultApiException(
      {super.apiErrorMessage,
      required super.statusCode,
      required super.errorMessage,
      super.shouldShowApiError});
}

//Dio errors
/// Exception that occurs when receiving send time out exception.
class SendTimeoutException extends NetworkException {
  const SendTimeoutException({
    required super.errorMessage,
  });
}

class RequestCanceledException extends NetworkException {
  const RequestCanceledException({required super.errorMessage});
}

/// Exception that occurs when there is no internet connection.
class NoInternetConnectionException extends NetworkException {
  const NoInternetConnectionException({required super.errorMessage});
}

/// Exception that occurs when receiving format exception from Dio.
class FormatException extends NetworkException {
  const FormatException({required super.errorMessage});
}

/// Default client exception.
class UnexpectedErrorException extends NetworkException {
  const UnexpectedErrorException({
    required super.errorMessage,
  });
}
