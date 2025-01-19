import 'package:flutter/foundation.dart';

import '../../../playx_network.dart';

/// This class contains the settings for the PlayxNetworkClient.
/// You can customize the settings based on your needs.
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

  /// Used to determine whether to use isolate for mapping json or not.
  final bool useIsolateForMappingJson;

  /// Used to determine whether to use work manager for mapping json in isolate or use [compute] function.
  final bool useWorkMangerForMappingJsonInIsolate;

  const PlayxNetworkClientSettings({
    this.logSettings = const PlayxNetworkLoggerSettings(),
    this.shouldShowApiErrors = true,
    this.exceptionMessages = const DefaultEnglishExceptionMessage(),
    this.unauthorizedRequestCodes = const [401, 403],
    this.successRequestCodes = const [200, 201],
    this.useIsolateForMappingJson = true,
    this.useWorkMangerForMappingJsonInIsolate = true,
  });

  PlayxNetworkClientSettings copyWith({
    PlayxNetworkLoggerSettings? logSettings,
    bool? shouldShowApiErrors,
    ExceptionMessage? exceptionMessages,
    List<int>? unauthorizedRequestCodes,
    List<int>? successRequestCodes,
    bool? useIsolateForMappingJson,
    bool? useWorkMangerForMappingJsonInIsolate,
  }) {
    return PlayxNetworkClientSettings(
      logSettings: logSettings ?? this.logSettings,
      shouldShowApiErrors: shouldShowApiErrors ?? this.shouldShowApiErrors,
      exceptionMessages: exceptionMessages ?? this.exceptionMessages,
      unauthorizedRequestCodes:
          unauthorizedRequestCodes ?? this.unauthorizedRequestCodes,
      successRequestCodes: successRequestCodes ?? this.successRequestCodes,
      useIsolateForMappingJson:
          useIsolateForMappingJson ?? this.useIsolateForMappingJson,
      useWorkMangerForMappingJsonInIsolate:
          useWorkMangerForMappingJsonInIsolate ??
              this.useWorkMangerForMappingJsonInIsolate,
    );
  }
}
