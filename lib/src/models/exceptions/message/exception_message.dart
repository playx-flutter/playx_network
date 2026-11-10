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

  /// Message for a response that took too long to receive. Defaults to
  /// [sendTimeout], the message used for it in earlier versions, so existing
  /// subclasses keep working.
  String get receiveTimeout => sendTimeout;

  /// Message for a failed secure (TLS/SSL) connection, such as an invalid
  /// certificate. Defaults to [defaultError] so existing subclasses keep
  /// working.
  String get secureConnectionError => defaultError;

  /// Message for a server that could not be reached while the device has a
  /// network. Defaults to [defaultError] so existing subclasses keep working.
  String get serverUnreachable => defaultError;

  /// Message for a request blocked in the browser (usually CORS). Defaults to
  /// [defaultError] so existing subclasses keep working.
  String get corsError => defaultError;
}
