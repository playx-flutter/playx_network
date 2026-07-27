import 'package:flutter/foundation.dart';

import '../../../playx_network.dart';

/// A callback used to decide whether an HTTP [Response] should be treated as a
/// success or an error.
///
/// Returning `true` means the response is successful.
/// Returning `false` means the response is an error and will be handled by the
/// [ApiHandler] (producing a [NetworkException]).
/// Returning `null` means "fall back to the default `successRequestCodes`"
/// list in the active [PlayxNetworkClientSettings].
///
/// This is intentionally **separate** from Dio's native `ValidateStatus`
/// (`bool Function(Response?)`). Dio's `validateStatus` only controls whether
/// Dio throws a `DioException` or returns the response; it does NOT decide
/// success/error semantics. [PlayxNetworkClient] always configures Dio with
/// `validateStatus: (_) => true` so that *every* response is returned, and then
/// the [ApiHandler] uses [PlayxValidateStatus] (or `successRequestCodes` when
/// the callback returns `null`) to decide success vs. error.
typedef PlayxValidateStatus = bool? Function(Response response);

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

  /// Optional callback to decide whether a [Response] should be treated as
  /// success or error.
  ///
  /// If provided and returns a non-null value, that value is used directly.
  /// If it returns `null` (or is not provided), the handler falls back to
  /// [successRequestCodes].
  ///
  /// This allows callers to implement custom validation logic that goes beyond
  /// a simple list of status codes — for example inspecting the response body,
  /// headers, or a business-logic field inside the payload.
  final PlayxValidateStatus? validateStatus;

  const PlayxNetworkClientSettings({
    this.logSettings = const PlayxNetworkLoggerSettings(),
    this.shouldShowApiErrors = true,
    this.exceptionMessages = const DefaultEnglishExceptionMessage(),
    this.unauthorizedRequestCodes = const [401, 403],
    this.successRequestCodes = const [200, 201],
    this.useIsolateForMappingJson = true,
    this.useWorkMangerForMappingJsonInIsolate = true,
    this.validateStatus,
  });

  PlayxNetworkClientSettings copyWith({
    PlayxNetworkLoggerSettings? logSettings,
    bool? shouldShowApiErrors,
    ExceptionMessage? exceptionMessages,
    List<int>? unauthorizedRequestCodes,
    List<int>? successRequestCodes,
    bool? useIsolateForMappingJson,
    bool? useWorkMangerForMappingJsonInIsolate,
    bool? printResponseData,
    bool? printRequestData,
    bool? printRequestHeaders,
    bool? printResponseHeaders,
    PlayxValidateStatus? validateStatus,
  }) {
    return PlayxNetworkClientSettings(
      logSettings: (logSettings ?? this.logSettings).copyWith(
        printRequestData: printRequestData,
        printRequestHeaders: printRequestHeaders,
        printResponseHeaders: printResponseHeaders,
        printResponseData: printResponseData,
      ),
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
      validateStatus: validateStatus ?? this.validateStatus,
    );
  }
}
