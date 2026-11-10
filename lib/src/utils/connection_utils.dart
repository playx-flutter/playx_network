import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:playx_network/src/models/exceptions/message/exception_message.dart';
import 'package:playx_network/src/models/exceptions/network_exception.dart';
import 'package:playx_network/src/utils/browser_connectivity.dart';

/// What a failed connection attempt most likely means.
enum ConnectionFailure {
  /// The device has no usable network ("network unreachable", "network down").
  noInternet,

  /// The device has a network but the server could not be reached: connection
  /// refused, reset, closed or timed out, or no route to the host.
  serverUnreachable,

  /// The host name could not be resolved. This is usually caused by being
  /// offline, but also by a wrong host or a DNS problem.
  hostLookup,

  /// The cause is not known.
  unknown,
}

// errno values by platform. Android and Linux share numbers; macOS and iOS
// share another set; Windows uses WinSock codes.
const _networkDownCodes = {100, 101, 50, 51, 10050, 10051};
const _hostUnreachableCodes = {113, 65, 10065};
const _connectionRefusedCodes = {111, 61, 10061};
const _connectionResetCodes = {104, 54, 10054, 32, 103, 53, 10053};
const _timedOutCodes = {110, 60, 10060};
const _hostLookupCodes = {7, -2, -5, -3, 8, 11001, 11004};

/// Classifies the [cause] of a connection error using the OS error code and
/// message. Only [SocketException]s carry that information; anything else is
/// [ConnectionFailure.unknown].
@visibleForTesting
ConnectionFailure classifyConnectionFailure(Object? cause) {
  if (cause is! SocketException) return ConnectionFailure.unknown;

  final code = cause.osError?.errorCode;
  final text = '${cause.message} ${cause.osError?.message ?? ''}'.toLowerCase();

  if (text.contains('failed host lookup') ||
      text.contains('no address associated') ||
      text.contains('nodename nor servname') ||
      text.contains('name or service not known') ||
      text.contains('temporary failure in name resolution')) {
    return ConnectionFailure.hostLookup;
  }
  if (_networkDownCodes.contains(code) ||
      text.contains('network is unreachable') ||
      text.contains('network is down')) {
    return ConnectionFailure.noInternet;
  }
  if (_connectionRefusedCodes.contains(code) ||
      _connectionResetCodes.contains(code) ||
      _timedOutCodes.contains(code) ||
      _hostUnreachableCodes.contains(code) ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('connection closed') ||
      text.contains('connection timed out') ||
      text.contains('no route to host') ||
      text.contains('broken pipe')) {
    return ConnectionFailure.serverUnreachable;
  }
  if (_hostLookupCodes.contains(code)) return ConnectionFailure.hostLookup;
  return ConnectionFailure.unknown;
}

/// Whether [error] is a failed TLS/SSL handshake or a rejected certificate.
///
/// Dio reports a rejected certificate as `badCertificate`, but a failed
/// handshake only arrives as an `unknown` (or `connectionError`) exception
/// wrapping a [TlsException].
bool isTlsFailure(Object? error) {
  if (error is TlsException) return true;
  if (error is DioException) {
    return error.type == DioExceptionType.badCertificate ||
        error.error is TlsException;
  }
  return false;
}

/// Whether [error] is a failure to establish or keep a connection (as opposed
/// to a timeout, a bad status code, a cancellation, a TLS failure, ...).
bool isConnectionFailure(Object? error) {
  if (isTlsFailure(error)) return false;
  if (error is SocketException) return true;
  if (error is DioException) {
    return error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.unknown &&
            error.error is SocketException);
  }
  return false;
}

/// Builds the exception for a connection failure.
///
/// [isOnline] is the answer of the app's `hasInternetConnection` callback:
/// `false` is always [NoInternetConnectionException]; `true` means the problem
/// is not a missing internet connection, so the server is considered
/// unreachable; `null` falls back to inspecting the error.
///
/// On the web a failed request carries no detail at all (CORS, an offline
/// browser and a down server all look the same), so [CorsException] is used
/// unless the browser or the callback says it is offline.
///
/// Failures that cannot be identified keep returning
/// [NoInternetConnectionException], as in earlier versions.
NetworkException buildConnectionException({
  required Object error,
  required ExceptionMessage messages,
  bool? isOnline,
  bool isWeb = kIsWeb,
  bool? Function() browserOnline = browserIsOnline,
}) {
  final noInternet =
      NoInternetConnectionException(errorMessage: messages.noInternetConnection);

  if (isWeb) {
    final online = isOnline ?? browserOnline();
    return online == false
        ? noInternet
        : CorsException(errorMessage: messages.corsError);
  }

  if (isOnline == false) return noInternet;

  final unreachable =
      ServerUnreachableException(errorMessage: messages.serverUnreachable);
  if (isOnline == true) return unreachable;

  final cause = error is DioException ? error.error : error;
  return classifyConnectionFailure(cause) == ConnectionFailure.serverUnreachable
      ? unreachable
      : noInternet;
}
