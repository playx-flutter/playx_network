import 'package:flutter/foundation.dart';

import '../../../playx_network.dart';

/// A callback that decides whether a Dio [Response] should be considered
/// successful or treated as an error.
///
/// Returning `true` means the response is valid and its data will be parsed.
/// Returning `false` means the response will be processed as an error using
/// the configured error mapper and exception messages.
///
/// If `null` is returned (or the callback itself is `null`) the default
/// behaviour falls back to [PlayxNetworkClientSettings.successRequestCodes].
typedef PlayxValidateStatus = bool? Function(Response? response);

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

  /// Custom interceptors that should be added to the underlying [Dio] client.
  ///
  /// These are appended **after** the built-in logger interceptor (when
  /// logging is enabled), so they observe the final request/response cycle.
  /// Use [interceptorsBuilder] when the interceptors need to be created lazily
  /// at construction time (e.g. they depend on other registered services).
  final List<Interceptor> interceptors;

  /// A lazy builder for custom interceptors.
  ///
  /// Invoked once during [PlayxNetworkClient] construction. The returned
  /// interceptors are appended after [interceptors]. This is useful when the
  /// interceptors depend on services that are not yet available at the moment
  /// the settings object is created.
  final List<Interceptor> Function()? interceptorsBuilder;

  /// A custom callback to validate the response status.
  ///
  /// When provided, it takes precedence over [successRequestCodes] for the
  /// requests that use these settings. Return `true` to treat the response as
  /// successful, `false` to treat it as an error, or `null` to fall back to the
  /// default [successRequestCodes] based validation.
  final PlayxValidateStatus? validateStatus;

  const PlayxNetworkClientSettings({
    this.logSettings = const PlayxNetworkLoggerSettings(),
    this.shouldShowApiErrors = true,
    this.exceptionMessages = const DefaultEnglishExceptionMessage(),
    this.unauthorizedRequestCodes = const [401, 403],
    this.successRequestCodes = const [200, 201],
    this.useIsolateForMappingJson = true,
    this.useWorkMangerForMappingJsonInIsolate = true,
    this.interceptors = const [],
    this.interceptorsBuilder,
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
    List<Interceptor>? interceptors,
    List<Interceptor> Function()? interceptorsBuilder,
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
      interceptors: interceptors ?? this.interceptors,
      interceptorsBuilder: interceptorsBuilder ?? this.interceptorsBuilder,
      validateStatus: validateStatus ?? this.validateStatus,
    );
  }
}
