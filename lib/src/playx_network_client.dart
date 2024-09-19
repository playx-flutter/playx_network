import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:playx_network/src/models/settings/playx_network_client_settings.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'dio/dio_client.dart';
import 'handler/api_handler.dart';
import 'models/network_result.dart';

///Function that converts json response to the required model.
typedef JsonMapper<T> = FutureOr<T> Function(dynamic json);

///Function that converts json error response from api to error message.
typedef ErrorMapper = String? Function(dynamic json);

/// Function that handles unauthorized request.
typedef UnauthorizedRequestHandler = void Function(Response? response);

/// PlayxNetworkClient is a Wrapper around [Dio] that can perform api request
/// With better error handling and easily get the result of any api request.
class PlayxNetworkClient {
  late final DioClient _dioClient;
  late final ApiHandler _apiHandler;

  ///Creates an instance of [PlayxNetworkClient]
  ///takes [Dio] object so u can easily customize your dio options.
  /// [customHeaders] which is custom headers that can included in each request like authorization token.
  /// [customQuery] which is custom query that can included in each request.
  /// [onUnauthorizedRequestReceived] which is a function that is called when unauthorized request is received.
  /// [errorMapper] which is a function that converts json error response from api to error message.
  /// [settings] which is a settings object that can be used to customize the client.
  PlayxNetworkClient({
    required Dio dio,
    FutureOr<Map<String, dynamic>> Function()? customHeaders,
    FutureOr<Map<String, dynamic>> Function()? customQuery,
    UnauthorizedRequestHandler? onUnauthorizedRequestReceived,
    ErrorMapper? errorMapper,
    PlayxNetworkClientSettings settings = const PlayxNetworkClientSettings(),
  }) {
    final attachLogSettings =
        kDebugMode && settings.logSettings.attachLoggerOnDebug ||
            kReleaseMode && settings.logSettings.attachLoggerOnRelease;

    if (attachLogSettings) {
      dio.interceptors.add(
        PrettyDioLogger(
            requestHeader: settings.logSettings.requestHeader,
            requestBody: settings.logSettings.requestBody,
            responseBody: settings.logSettings.responseBody,
            request: settings.logSettings.request,
            responseHeader: settings.logSettings.responseHeader,
            error: settings.logSettings.error,
            maxWidth: settings.logSettings.maxWidth,
            compact: settings.logSettings.compact,
            logPrint: settings.logSettings.logPrint),
      );
    }
    _dioClient = DioClient(
      dio: dio,
      customHeaders: customHeaders,
      customQuery: customQuery,
    );
    _apiHandler = ApiHandler(
      errorMapper: errorMapper ?? ApiHandler.getErrorMessageFromResponse,
      settings: settings,
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
    bool shouldHandleUnauthorizedRequest = true,
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
      return _apiHandler.handleNetworkResult(
          response: res,
          fromJson: fromJson,
          shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
      // ignore: avoid_catches_without_on_clauses
    } catch (error, stackTrace) {
      return _apiHandler.handleDioException(
          error: error,
          stackTrace: stackTrace,
          shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
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
    bool shouldHandleUnauthorizedRequest = true,
  }) async {
    try {
      final res = await _dioClient.get(path,
          headers: headers,
          query: query,
          options: options,
          attachCustomHeaders: attachCustomHeaders,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress);
      return _apiHandler.handleNetworkResultForList(
          response: res,
          fromJson: fromJson,
          shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
          error: error,
          shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
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
    bool shouldHandleUnauthorizedRequest = true,
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
        response: res,
        fromJson: fromJson,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
          error: error,
          shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
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
    bool shouldHandleUnauthorizedRequest = true,
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
        response: res,
        fromJson: fromJson,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
          error: error,
          shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
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
    bool shouldHandleUnauthorizedRequest = true,
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
        response: res,
        fromJson: fromJson,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
          error: error,
          shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
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
    bool shouldHandleUnauthorizedRequest = true,
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
        response: res,
        fromJson: fromJson,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
          error: error,
          shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
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
    bool shouldHandleUnauthorizedRequest = true,
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
      return _apiHandler.handleNetworkResult(
          response: res,
          fromJson: fromJson,
          shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
          error: error,
          shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
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
    bool shouldHandleUnauthorizedRequest = true,
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
      return _apiHandler.handleNetworkResultForList(
          response: res,
          fromJson: fromJson,
          shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
          error: error,
          shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest);
    }
  }
}
