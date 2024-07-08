import 'package:playx_network/src/models/exceptions/message/exception_message.dart';

///Default client error messages.
///To customize your messages you can override [ExceptionMessage] the same way as this class and customize the messages.
class DefaultEnglishExceptionMessage extends ExceptionMessage {
  const DefaultEnglishExceptionMessage();

  @override
  String get badRequest =>
      "Sorry, The API request is invalid or improperly formed.";

  @override
  String get conflict =>
      "Sorry, The request wasn't completed due to a conflict.";

  @override
  String get defaultError => "Sorry, Something went wrong.";

  @override
  String get emptyResponse =>
      "Sorry, Couldn't receive response from the server.";

  @override
  String get formatException =>
      "Sorry, The request wasn't formatted correctly.";

  @override
  String get internalServerError => "Sorry, There is an internal server error";

  @override
  String get noInternetConnection => "Sorry, There is no internet connection.";

  @override
  String get notAcceptable => "Sorry, The request is not acceptable";

  @override
  String get notFound => "Sorry, The resource requested couldn't be found.";

  @override
  String get requestCancelled => "Sorry, The request has been canceled";

  @override
  String get requestTimeout => "Sorry, The request has timed out.";

  @override
  String get sendTimeout =>
      "Sorry, The request has send timeout in connection with API server";

  @override
  String get serviceUnavailable => "Sorry, The service is unavailable";

  @override
  String get unableToProcess => "Sorry, Couldn't process the data.";

  @override
  String get unauthorizedRequest => "Sorry, The request is unauthorized.";

  @override
  String get unexpectedError => "Sorry, Something went wrong.";
}
