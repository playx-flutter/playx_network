import 'package:playx_network/src/models/exceptions/message/exception_message.dart';

///Base class for handling api errors and provides suitable error messages.
sealed class NetworkException {
  String get message;

  final bool shouldShowApiError;
  final ExceptionMessage exceptionMessage;

  const NetworkException(
      {this.shouldShowApiError = true, required this.exceptionMessage});
}

/// Exception that occurs when receiving an unauthorized request from api mainly when receiving 401,403 error codes.
class UnauthorizedRequestException extends NetworkException {
  final String? error;

  const UnauthorizedRequestException(
      {this.error, required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.unauthorizedRequest
      : exceptionMessage.unauthorizedRequest;
}

/// Exception that occurs when receiving a not found request from api mainly when receiving 404 error code.
class NotFoundException extends NetworkException {
  final String? error;

  const NotFoundException(
      {this.error, required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.notFound
      : exceptionMessage.notFound;
}

/// Exception that occurs when there is a conflict from the API mainly when receiving 409 error code.
class ConflictException extends NetworkException {
  final String? error;

  const ConflictException(
      {this.error, required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.conflict
      : exceptionMessage.conflict;
}

/// Exception that occurs when the request has timed out.
class RequestTimeoutException extends NetworkException {
  final String? error;

  const RequestTimeoutException(
      {this.error, required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.requestTimeout
      : exceptionMessage.requestTimeout;
}

/// Exception that occurs when the client couldn't process the response successfully.
/// Can happen when the response returns status code 422.
/// Or the the model from json function has error on it.
class UnableToProcessException extends NetworkException {
  final String? error;

  const UnableToProcessException(
      {this.error, required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.unableToProcess
      : exceptionMessage.unableToProcess;
}

/// Exception that occurs when there's an internal server error.
/// Can happen when the response returns status code 500.
class InternalServerErrorException extends NetworkException {
  final String? error;

  const InternalServerErrorException(
      {this.error, required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.internalServerError
      : exceptionMessage.internalServerError;
}

/// Exception that occurs when the client receives service unavailable error.
/// Can happen when the response returns status code 503.
class ServiceUnavailableException extends NetworkException {
  final String? error;

  const ServiceUnavailableException(
      {this.error, required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.serviceUnavailable
      : exceptionMessage.serviceUnavailable;
}

/// Exception that occurs when the client receives empty response.
class EmptyResponseException extends NetworkException {
  final String? error;

  const EmptyResponseException(
      {this.error, required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.emptyResponse
      : exceptionMessage.emptyResponse;
}

/// Exception that occurs another api exception happens.
class DefaultApiException extends NetworkException {
  final String? error;

  const DefaultApiException(
      {this.error, required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.defaultError
      : exceptionMessage.defaultError;
}

//Dio errors
/// Exception that occurs when receiving send time out exception.
class SendTimeoutException extends NetworkException {
  const SendTimeoutException({required super.exceptionMessage});

  @override
  String get message => exceptionMessage.sendTimeout;
}

class RequestCanceledException extends NetworkException {
  const RequestCanceledException({
    required super.exceptionMessage,
  });

  @override
  String get message => exceptionMessage.requestCancelled;
}

/// Exception that occurs when there is no internet connection.
class NoInternetConnectionException extends NetworkException {
  const NoInternetConnectionException({
    required super.exceptionMessage,
  });

  @override
  String get message => exceptionMessage.noInternetConnection;
}

/// Exception that occurs when receiving format exception from Dio.
class FormatException extends NetworkException {
  const FormatException({
    required super.exceptionMessage,
  });

  @override
  String get message => exceptionMessage.formatException;
}

/// Default client exception.
class UnexpectedErrorException extends NetworkException {
  const UnexpectedErrorException({
    required super.exceptionMessage,
  });

  @override
  String get message => exceptionMessage.unexpectedError;
}
