import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:playx_network/src/models/exceptions/message/english_exception_message.dart';
import 'package:playx_network/src/models/exceptions/message/exception_message.dart';
import 'package:playx_network/src/models/logger/logger_settings.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'dio/dio_client.dart';
import 'handler/api_handler.dart';
import 'models/network_result.dart';

typedef JsonMapper<T> = T Function(Map<String, dynamic> json);
typedef ErrorMapper = String? Function(Map<String, dynamic> json);

/// wrapper around dio to handlers api calls
class PlayxNetworkClient {
  late final DioClient dioClient;
  late final ApiHandler apiHandler;

  PlayxNetworkClient({
    required Dio dio,
    String? token,
    bool attachLoggerOnDebug = true,
    LoggerSettings logSettings = const LoggerSettings(),
    ErrorMapper? errorMapper,
    bool shouldShowApiErrors = true,
    ExceptionMessage exceptionMessages = const DefaultEnglishExceptionMessage(),
    VoidCallback? onUnauthorizedRequestReceived,
  }) {
    if (kDebugMode && attachLoggerOnDebug) {
      dio.interceptors.add(
        PrettyDioLogger(
            requestHeader: logSettings.requestHeader,
            requestBody: logSettings.requestBody,
            responseBody: logSettings.responseBody,
            request: logSettings.request,
            responseHeader: logSettings.responseHeader,
            error: logSettings.error,
            maxWidth: logSettings.maxWidth,
            compact: logSettings.compact,
            logPrint: logSettings.logPrint),
      );
    }
    dioClient = DioClient(dio: dio, token: token);
    apiHandler = ApiHandler(
      errorMapper: errorMapper ?? ApiHandler.getErrorMessageFromResponse,
      shouldShowApiErrors: shouldShowApiErrors,
      exceptionMessages: exceptionMessages,
      onUnauthorizedRequestReceived: onUnauthorizedRequestReceived,
    );
  }

  /// sends a [GET] request to the given [url]
  /// and returns object of Type [T] not list
  Future<NetworkResult<T>> get<T>(
    String path, {
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    bool attachToken = true,
    CancelToken? cancelToken,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await dioClient.get(
        path,
        headers: headers,
        query: query,
        attachToken: attachToken,
        cancelToken: cancelToken,
      );
      return apiHandler.handleNetworkResult(res, fromJson);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return apiHandler.handleDioException(error);
    }
  }

  /// sends a [GET] request to the given [url]
  /// and returns List<object> of Type [T] not object
  Future<NetworkResult<List<T>>> getList<T>(
    String path, {
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    bool attachToken = true,
    CancelToken? cancelToken,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await dioClient.get(
        path,
        headers: headers,
        query: query,
        attachToken: attachToken,
        cancelToken: cancelToken,
      );
      return apiHandler.handleNetworkResultForList(res, fromJson);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return apiHandler.handleDioException(error);
    }
  }

  /// sends a [POST] request to the given [url]
  /// and returns object of Type [T] not list
  Future<NetworkResult<T>> post<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    String? contentType,
    bool attachToken = true,
    CancelToken? cancelToken,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await dioClient.post(
        path,
        body: body,
        headers: headers,
        query: query,
        contentType: contentType,
        attachToken: attachToken,
        cancelToken: cancelToken,
      );
      return apiHandler.handleNetworkResult(
        res,
        fromJson,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return apiHandler.handleDioException(error);
    }
  }

  /// sends a [POST] request to the given [url]
  /// and returns List<object> of Type [T] not object
  Future<NetworkResult<List<T>>> postList<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    String? contentType,
    bool attachToken = true,
    CancelToken? cancelToken,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await dioClient.post(
        path,
        body: body,
        headers: headers,
        query: query,
        contentType: contentType,
        attachToken: attachToken,
        cancelToken: cancelToken,
      );
      return apiHandler.handleNetworkResultForList(
        res,
        fromJson,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return apiHandler.handleDioException(error);
    }
  }

  /// sends a [DELETE] request to the given [url]
  /// and returns object of Type [T] not list
  Future<NetworkResult<T>> delete<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    String? contentType,
    bool attachToken = true,
    CancelToken? cancelToken,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await dioClient.delete(
        path,
        body: body,
        headers: headers,
        query: query,
        contentType: contentType,
        attachToken: attachToken,
        cancelToken: cancelToken,
      );
      return apiHandler.handleNetworkResult(
        res,
        fromJson,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return apiHandler.handleDioException(error);
    }
  }

  /// sends a [DELETE] request to the given [url]
  /// and returns List<object> of Type [T] not object
  Future<NetworkResult<List<T>>> deleteList<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    String? contentType,
    bool attachToken = true,
    CancelToken? cancelToken,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await dioClient.delete(
        path,
        body: body,
        headers: headers,
        query: query,
        contentType: contentType,
        attachToken: attachToken,
        cancelToken: cancelToken,
      );
      return apiHandler.handleNetworkResultForList(
        res,
        fromJson,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return apiHandler.handleDioException(error);
    }
  }

  /// sends a [PUT] request to the given [url]
  /// and returns object of Type [T] not list
  Future<NetworkResult<T>> put<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    String? contentType,
    bool attachToken = true,
    CancelToken? cancelToken,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await dioClient.put(
        path,
        body: body,
        headers: headers,
        query: query,
        contentType: contentType,
        attachToken: attachToken,
        cancelToken: cancelToken,
      );
      return apiHandler.handleNetworkResult(res, fromJson);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return apiHandler.handleDioException(error);
    }
  }

  /// sends a [PUT] request to the given [url]
  /// and returns List<object> of Type [T] not object
  Future<NetworkResult<List<T>>> putList<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    String? contentType,
    bool attachToken = true,
    CancelToken? cancelToken,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await dioClient.put(
        path,
        body: body,
        headers: headers,
        query: query,
        contentType: contentType,
        attachToken: attachToken,
        cancelToken: cancelToken,
      );
      return apiHandler.handleNetworkResultForList(res, fromJson);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return apiHandler.handleDioException(error);
    }
  }
}
