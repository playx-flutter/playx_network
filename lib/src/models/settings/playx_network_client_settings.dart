import '../../../playx_network.dart';

/// This class contains the settings for the PlayxNetworkClient.
/// You can customize the settings based on your needs.
/// [logSettings] is used to customize the logger settings.
/// [shouldShowApiErrors] is used to determine whether to show api errors or not.
/// [exceptionMessages] is used to customize the exception messages.
/// [unauthorizedRequestCodes] is used to determine the unauthorized request codes.
/// [successRequestCodes] is used to determine the success request codes.
class PlayxNetworkClientSettings {
  /// Used to customize the logger settings.
  final PlayxNetworkLoggerSettings logSettings;

  /// Used to determine whether to show api errors or not.
  final bool shouldShowApiErrors;

  /// Used to customize the exception messages.
  final ExceptionMessage exceptionMessages;

  /// Used to determine the unauthorized request codes.
  final List<int> unauthorizedRequestCodes;

  /// Used to determine the success request codes.
  final List<int> successRequestCodes;

  const PlayxNetworkClientSettings({
    this.logSettings = const PlayxNetworkLoggerSettings(),
    this.shouldShowApiErrors = true,
    this.exceptionMessages = const DefaultEnglishExceptionMessage(),
    this.unauthorizedRequestCodes = const [401, 403],
    this.successRequestCodes = const [200, 201],
  });
}
