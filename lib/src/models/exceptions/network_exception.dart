
import 'package:playx_network/src/models/exceptions/message/exception_message.dart';


/// Base class for handling most api errors and provides suitable error messages.
sealed class NetworkException {
  String get message;
  final bool shouldShowApiError;
  final ExceptionMessage exceptionMessage;

  const NetworkException({this.shouldShowApiError = true,required this.exceptionMessage});
}

class UnauthorizedRequestException extends NetworkException {
  final String? error;

  const UnauthorizedRequestException({this.error,required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.unauthorizedRequest
      : exceptionMessage.unauthorizedRequest;
}

class NotFoundException extends NetworkException {
  final String? error;

  const NotFoundException({this.error,required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.notFound
      : exceptionMessage.notFound;
}

class ConflictException extends NetworkException {
  final String? error;

  const ConflictException({this.error,required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.conflict
      : exceptionMessage.conflict;
}

class RequestTimeoutException extends NetworkException {
  final String? error;

  const RequestTimeoutException({this.error,required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.requestTimeout
      : exceptionMessage.requestTimeout;
}

class UnableToProcessException extends NetworkException {
  final String? error;

  const UnableToProcessException({this.error,required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => exceptionMessage.unableToProcess;
}

class InternalServerErrorException extends NetworkException {
  final String? error;

  const InternalServerErrorException({this.error,required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.internalServerError
      : exceptionMessage.internalServerError;
}

class ServiceUnavailableException extends NetworkException {
  final String? error;

  const ServiceUnavailableException({this.error,required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.serviceUnavailable
      : exceptionMessage.serviceUnavailable;
}

class EmptyResponseException extends NetworkException {
  final String? error;

  const EmptyResponseException({this.error,required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.emptyResponse
      : exceptionMessage.emptyResponse;
}

class DefaultApiException extends NetworkException {
  final String? error;

  const DefaultApiException({this.error,required super.exceptionMessage, super.shouldShowApiError});

  @override
  String get message => shouldShowApiError
      ? error ?? exceptionMessage.defaultError
      : exceptionMessage.defaultError;
}

//Dio errors
class SendTimeoutException extends NetworkException {
  const SendTimeoutException({required super.exceptionMessage});

  @override
  String get message => exceptionMessage.sendTimeout;
}

class RequestCanceledException extends NetworkException {
  const RequestCanceledException({required super.exceptionMessage, });

  @override
  String get message => exceptionMessage.requestCancelled;
}

class NoInternetConnectionException extends NetworkException {
  const NoInternetConnectionException({required super.exceptionMessage, });

  @override
  String get message => exceptionMessage.noInternetConnection;
}

class FormatException extends NetworkException {
  const FormatException({required super.exceptionMessage,});

  @override
  String get message => exceptionMessage.formatException;
}

class UnexpectedErrorException extends NetworkException {
  const UnexpectedErrorException({required super.exceptionMessage,});

  @override
  String get message => exceptionMessage.unexpectedError;
}
