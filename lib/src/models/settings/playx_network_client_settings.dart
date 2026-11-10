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
  ///
  /// Defaults to `[200, 201]`, so a `204 No Content` response is treated as an
  /// error. APIs that answer successful requests (for example `delete`) with
  /// `204` need `successRequestCodes: [200, 201, 204]`.
  final List<int> successRequestCodes;

  /// Used to determine whether to use isolate for mapping json or not.
  final bool useIsolateForMappingJson;

  /// Used to determine whether to use work manager for mapping json in isolate or use [compute] function.
  final bool useWorkMangerForMappingJsonInIsolate;

  /// Used to determine whether an empty successful list response should be
  /// returned as a successful empty list instead of an [EmptyResponseException].
  ///
  /// When `true`, list requests (`getList`, `postList`, ...) that succeed with
  /// an empty body (`null` or an empty string) or with an empty list (`[]`,
  /// including after `dataKey` / `itemDataKey` extraction) return
  /// `NetworkResult.success([])`.
  ///
  /// Requests that return a single object are not affected, because there is
  /// no empty value to return for an arbitrary model.
  ///
  /// Defaults to `false`, which keeps returning an [EmptyResponseException].
  final bool treatEmptyResponseAsSuccess;

  const PlayxNetworkClientSettings({
    this.logSettings = const PlayxNetworkLoggerSettings(),
    this.shouldShowApiErrors = true,
    this.exceptionMessages = const DefaultEnglishExceptionMessage(),
    this.unauthorizedRequestCodes = const [401, 403],
    this.successRequestCodes = const [200, 201],
    this.useIsolateForMappingJson = true,
    this.useWorkMangerForMappingJsonInIsolate = true,
    this.treatEmptyResponseAsSuccess = false,
  });

  PlayxNetworkClientSettings copyWith({
    PlayxNetworkLoggerSettings? logSettings,
    bool? shouldShowApiErrors,
    ExceptionMessage? exceptionMessages,
    List<int>? unauthorizedRequestCodes,
    List<int>? successRequestCodes,
    bool? useIsolateForMappingJson,
    bool? useWorkMangerForMappingJsonInIsolate,
    bool? treatEmptyResponseAsSuccess,
    bool? printResponseData,
    bool? printRequestData,
    bool? printRequestHeaders,
    bool? printResponseHeaders,
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
      treatEmptyResponseAsSuccess:
          treatEmptyResponseAsSuccess ?? this.treatEmptyResponseAsSuccess,
    );
  }
}
