import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:playx_core/playx_core.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

/// Logger settings used to customize what should be logged by the application when performing a request.
class PlayxNetworkLoggerSettings extends Equatable {
  // Print Dio logger if true
  final bool enabled;

  /// Print [response.data] if true
  final bool printResponseData;

  /// Print [response.headers] if true
  final bool printResponseHeaders;

  /// Print [response.statusMessage] if true
  final bool printResponseMessage;

  /// Print [response.redirects] if true
  final bool printResponseRedirects;

  /// Print response time if true
  final bool printResponseTime;

  /// Print [error.response.data] if true
  final bool printErrorData;

  /// Print [error.response.headers] if true
  final bool printErrorHeaders;

  /// Print [error.message] if true
  final bool printErrorMessage;

  /// Print [request.data] if true
  final bool printRequestData;

  /// Print [request.headers] if true
  final bool printRequestHeaders;

  /// Print [request.extra] if true
  final bool printRequestExtra;

  /// For request filtering.
  /// You can add your custom logic to log only specific HTTP requests [RequestOptions].
  final bool Function(RequestOptions requestOptions)? requestFilter;

  /// For response filtering.
  /// You can add your custom logic to log only specific HTTP responses [Response].
  final bool Function(Response response)? responseFilter;

  /// For error filtering.
  /// You can add your custom logic to log only specific Dio error [DioException].
  final bool Function(DioException response)? errorFilter;

  /// Header values for the specified keys in the Set will be replaced with *****.
  /// Case insensitive
  final Set<String> hiddenHeaders;

  const PlayxNetworkLoggerSettings({
    this.enabled = kDebugMode,
    this.printResponseData = true,
    this.printResponseHeaders = false,
    this.printResponseMessage = true,
    this.printResponseRedirects = false,
    this.printResponseTime = false,
    this.printErrorData = true,
    this.printErrorHeaders = true,
    this.printErrorMessage = true,
    this.printRequestData = true,
    this.printRequestHeaders = true,
    this.printRequestExtra = false,
    this.hiddenHeaders = const <String>{},
    this.requestFilter,
    this.responseFilter,
    this.errorFilter,
  });

  TalkerDioLogger buildTalkerDioLogger() {
    return TalkerDioLogger(
        settings: TalkerDioLoggerSettings(
      enabled: enabled,
      printResponseData: printResponseData,
      printResponseHeaders: printResponseHeaders,
      printResponseMessage: printResponseMessage,
      printResponseRedirects: printResponseRedirects,
      printResponseTime: printResponseTime,
      printErrorData: printErrorData,
      printErrorHeaders: printErrorHeaders,
      printErrorMessage: printErrorMessage,
      printRequestData: printRequestData,
      printRequestHeaders: printRequestHeaders,
      printRequestExtra: printRequestExtra,
      requestFilter: requestFilter,
      responseFilter: responseFilter,
      errorFilter: errorFilter,
      hiddenHeaders: hiddenHeaders,
    ));
  }

  PlayxNetworkLoggerSettings copyWith(
      {bool? enabled,
      bool? printResponseData,
      bool? printResponseHeaders,
      bool? printResponseMessage,
      bool? printResponseRedirects,
      bool? printResponseTime,
      bool? printErrorData,
      bool? printErrorHeaders,
      bool? printErrorMessage,
      bool? printRequestData,
      bool? printRequestHeaders,
      bool? printRequestExtra,
      bool Function(RequestOptions requestOptions)? requestFilter,
      bool Function(Response response)? responseFilter,
      bool Function(DioException response)? errorFilter,
      Set<String>? hiddenHeaders}) {
    return PlayxNetworkLoggerSettings(
        enabled: enabled ?? this.enabled,
        printResponseData: printResponseData ?? this.printResponseData,
        printResponseHeaders: printResponseHeaders ?? this.printResponseHeaders,
        printResponseMessage: printResponseMessage ?? this.printResponseMessage,
        printResponseRedirects:
            printResponseRedirects ?? this.printResponseRedirects,
        printResponseTime: printResponseTime ?? this.printResponseTime,
        printErrorData: printErrorData ?? this.printErrorData,
        printErrorHeaders: printErrorHeaders ?? this.printErrorHeaders,
        printErrorMessage: printErrorMessage ?? this.printErrorMessage,
        printRequestData: printRequestData ?? this.printRequestData,
        printRequestHeaders: printRequestHeaders ?? this.printRequestHeaders,
        printRequestExtra: printRequestExtra ?? this.printRequestExtra,
        requestFilter: requestFilter ?? this.requestFilter,
        responseFilter: responseFilter ?? this.responseFilter,
        errorFilter: errorFilter ?? this.errorFilter,
        hiddenHeaders: hiddenHeaders ?? this.hiddenHeaders);
  }

  @override
  List<Object?> get props => [
        enabled,
        printResponseData,
        printResponseHeaders,
        printResponseMessage,
        printResponseRedirects,
        printResponseTime,
        printErrorData,
        printErrorHeaders,
        printErrorMessage,
        printRequestData,
        printRequestHeaders,
        printRequestExtra,
        requestFilter,
        responseFilter,
        errorFilter,
        hiddenHeaders
      ];

  @override
  bool get stringify => true;
}
