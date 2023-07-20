import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:playx_network/src/models/exceptions/message/english_exception_message.dart';
import 'package:playx_network/src/models/exceptions/message/exception_message.dart';
import 'package:playx_network/src/models/logger/logger_settings.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'dio/dio_client.dart';
import 'handler/api_handler.dart';
import 'models/network_result.dart';

///Function that converts json response to the required model.
typedef JsonMapper<T> = T Function(dynamic json);

///Function that converts json error response from api to error message.
typedef ErrorMapper = String? Function(dynamic json);

/// PlayxNetworkClient is a Wrapper around [Dio] that can perform api request
/// With better error handling and easily get the result of any api request.
class PlayxNetworkClient {
  late final DioClient _dioClient;
  late final ApiHandler _apiHandler;

  ///Creates an instance of [PlayxNetworkClient]
  ///takes [Dio] object so u can easily customize your dio options.
  /// [customHeaders] which is custom headers that can included in each request like authorization token.
  /// You can attach logger to [Dio] to pretty print request using [attachLoggerOnDebug] and customize what is printed by customizing [LoggerSettings].
  /// You can customize whether The client should show api errors or use the default messages by using [shouldShowApiErrors].
  /// and you can decide how to get the error message from the api response by using [ErrorMapper].
  /// also you can customize the error messages for each network exception by creating a class that extends the [ExceptionMessage] by default [DefaultEnglishExceptionMessage].
  /// also you can handle when un authorized request is received by using [onUnauthorizedRequestReceived].
  PlayxNetworkClient({
    required Dio dio,
    final Future<Map<String, dynamic>> Function()? customHeaders,
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
    _dioClient = DioClient(dio: dio, customHeaders: customHeaders);
    _apiHandler = ApiHandler(
      errorMapper: errorMapper ?? ApiHandler.getErrorMessageFromResponse,
      shouldShowApiErrors: shouldShowApiErrors,
      exceptionMessages: exceptionMessages,
      onUnauthorizedRequestReceived: onUnauthorizedRequestReceived,
    );
  }

   static Dio createDefaultDioClient({
    required String baseUrl,
  }) {
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        validateStatus: (_) => true,
        followRedirects: true,
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 20),
        contentType: Headers.jsonContentType,
      ),
    );

    return dio;
  }




  /// sends a [GET] request to the given [url]
  /// and returns object of Type [T] model.
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  Future<NetworkResult<T>> get<T>(
    String path, {
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await _dioClient.get(
        path,
        headers: headers,
        query: query,
        options: options,
        attachCustomHeaders: attachCustomHeaders,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return _apiHandler.handleNetworkResult(res, fromJson);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(error);
    }
  }

  /// sends a [GET] request to the given [url]
  /// and returns [List] of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.

  Future<NetworkResult<List<T>>> getList<T>(
    String path, {
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await _dioClient.get(path,
          headers: headers,
          query: query,
          options: options,
          attachCustomHeaders: attachCustomHeaders,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress);
      return _apiHandler.handleNetworkResultForList(res, fromJson);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(error);
    }
  }

  /// sends a [POST] request to the given [url]
  /// and returns object of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  Future<NetworkResult<T>> post<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await _dioClient.post(
        path,
        body: body,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return _apiHandler.handleNetworkResult(
        res,
        fromJson,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(error);
    }
  }

  /// sends a [POST] request to the given [url]
  /// and returns [List] of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  Future<NetworkResult<List<T>>> postList<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await _dioClient.post(
        path,
        body: body,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return _apiHandler.handleNetworkResultForList(
        res,
        fromJson,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(error);
    }
  }

  /// sends a [DELETE] request to the given [url]
  /// and returns object of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  Future<NetworkResult<T>> delete<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    CancelToken? cancelToken,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await _dioClient.delete(
        path,
        body: body,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        cancelToken: cancelToken,
      );
      return _apiHandler.handleNetworkResult(
        res,
        fromJson,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(error);
    }
  }

  /// sends a [DELETE] request to the given [url]
  /// and returns [List] of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  Future<NetworkResult<List<T>>> deleteList<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    CancelToken? cancelToken,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await _dioClient.delete(
        path,
        body: body,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        cancelToken: cancelToken,
      );
      return _apiHandler.handleNetworkResultForList(
        res,
        fromJson,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(error);
    }
  }

  /// sends a [PUT] request to the given [url]
  /// and returns object of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  Future<NetworkResult<T>> put<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await _dioClient.put(
        path,
        body: body,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return _apiHandler.handleNetworkResult(res, fromJson);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(error);
    }
  }

  /// sends a [PUT] request to the given [url]
  /// and returns [List] of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  Future<NetworkResult<List<T>>> putList<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
  }) async {
    try {
      final res = await _dioClient.put(
        path,
        body: body,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return _apiHandler.handleNetworkResultForList(res, fromJson);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(error);
    }
  }
}
