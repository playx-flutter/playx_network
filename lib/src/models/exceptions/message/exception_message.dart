/// Class that can be extended to implement your own custom errors message.
abstract class ExceptionMessage {
  const ExceptionMessage();

  String get requestCancelled;

  String get unauthorizedRequest;

  String get badRequest;

  String get notFound;

  String get notAcceptable;

  String get requestTimeout;

  String get sendTimeout;

  String get conflict;

  String get internalServerError;

  String get serviceUnavailable;

  String get noInternetConnection;

  String get formatException;

  String get unableToProcess;

  String get defaultError;

  String get unexpectedError;

  String get emptyResponse;
}
