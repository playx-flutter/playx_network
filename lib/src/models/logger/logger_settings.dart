import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Logger settings used to customize what should be logged by the application when performing a request.
class PlayxNetworkLoggerSettings {
  /// Print request [Options]
  final bool request;

  /// Print request header [Options.headers]
  final bool requestHeader;

  /// Print request data [Options.data]
  final bool requestBody;

  /// Print [Response.data]
  final bool responseBody;

  /// Print [Response.headers]
  final bool responseHeader;

  /// Print error message
  final bool error;

  /// InitialTab count to logPrint json response
  static const int kInitialTab = 1;

  /// 1 tab length
  static const String tabStep = '    ';

  /// Print compact json response
  final bool compact;

  /// Width size per logPrint
  final int maxWidth;

  /// Log printer; defaults logPrint log to console.
  /// In flutter, you'd better use debugPrint.
  /// you can also write log in a file.
  final void Function(Object object) logPrint;

  final bool attachLoggerOnDebug;

  final bool attachLoggerOnRelease;

  const PlayxNetworkLoggerSettings(
      {this.request = true,
      this.requestHeader = true,
      this.requestBody = true,
      this.responseHeader = false,
      this.responseBody = false,
      this.attachLoggerOnDebug = true,
      this.attachLoggerOnRelease = false,
      this.error = true,
      this.maxWidth = 90,
      this.compact = true,
      this.logPrint = print});

  PrettyDioLogger buildPrettyDioLogger() {
    return PrettyDioLogger(
      requestHeader: requestHeader,
      requestBody: requestBody,
      responseBody: responseBody,
      responseHeader: responseHeader,
      error: error,
      compact: compact,
      maxWidth: maxWidth,
      logPrint: logPrint,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PlayxNetworkLoggerSettings &&
        other.request == request &&
        other.requestHeader == requestHeader &&
        other.requestBody == requestBody &&
        other.responseHeader == responseHeader &&
        other.responseBody == responseBody &&
        other.error == error &&
        other.compact == compact &&
        other.maxWidth == maxWidth &&
        other.attachLoggerOnDebug == attachLoggerOnDebug &&
        other.attachLoggerOnRelease == attachLoggerOnRelease &&
        other.logPrint == logPrint;
  }

  @override
  int get hashCode {
    return request.hashCode ^
        requestHeader.hashCode ^
        requestBody.hashCode ^
        responseBody.hashCode ^
        responseHeader.hashCode ^
        error.hashCode ^
        compact.hashCode ^
        maxWidth.hashCode ^
        attachLoggerOnDebug.hashCode ^
        attachLoggerOnRelease.hashCode ^
        logPrint.hashCode;
  }
}
