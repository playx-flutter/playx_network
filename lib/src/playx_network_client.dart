import 'dart:async';

import 'package:dio/dio.dart';
import 'package:playx_core/playx_core.dart';

import 'dio/dio_client.dart';
import 'handler/api_handler.dart';
import 'models/exceptions/message/exception_message.dart';
import 'models/network_result.dart';
import 'models/settings/playx_network_client_settings.dart';

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

  ///Settings for the client.
  final PlayxNetworkClientSettings settings;

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
    this.settings = const PlayxNetworkClientSettings(),
  }) {
    _dioClient = DioClient(
      dio: dio,
      customHeaders: customHeaders,
      customQuery: customQuery,
      settings: settings,
    );
    _apiHandler = ApiHandler(
      errorMapper: errorMapper ?? ApiHandler.getErrorMessageFromResponse,
      settings: settings,
      onUnauthorizedRequestReceived: onUnauthorizedRequestReceived,
    );
    if (GetIt.instance
        .isRegistered<ExceptionMessage>(instanceName: 'exception_messages')) {
      GetIt.instance.unregister<ExceptionMessage>();
    }
    GetIt.instance.registerSingleton<ExceptionMessage>(
        settings.exceptionMessages,
        instanceName: 'exception_messages');
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
    bool attachCustomQuery = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    try {
      final res = await _dioClient.get(
        path,
        headers: headers,
        query: query,
        options: options,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      );
      return _apiHandler.handleNetworkResult(
        response: res,
        fromJson: fromJson,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error, stackTrace) {
      return _apiHandler.handleDioException(
        error: error,
        stackTrace: stackTrace,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
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
    bool attachCustomQuery = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    try {
      final res = await _dioClient.get(
        path,
        headers: headers,
        query: query,
        options: options,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      );
      return _apiHandler.handleNetworkResultForList(
        response: res,
        fromJson: fromJson,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
        error: error,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
    }
  }

  /// Download file from the given [url]
  /// and returns [NetworkResult] of [Response].
  Future<NetworkResult<Response>> download(
    String path, {
    required dynamic savePath,
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    JsonMapper? fromJson,
    bool shouldHandleUnauthorizedRequest = true,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    PlayxNetworkClientSettings? settings,
  }) async {
    try {
      final res = await _dioClient.download(
        path,
        savePath: savePath,
        headers: headers,
        query: query,
        options: options,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        data: data,
        deleteOnError: deleteOnError,
        lengthHeader: lengthHeader,
        logSettings: settings?.logSettings,
      );
      return _apiHandler.handleNetworkResultForDownload(
        response: res,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
        error: error,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
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
    bool attachCustomQuery = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
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
        attachCustomQuery: attachCustomQuery,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      );
      return _apiHandler.handleNetworkResult(
        response: res,
        fromJson: fromJson,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
        error: error,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
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
    bool attachCustomQuery = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
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
        attachCustomQuery: attachCustomQuery,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      );
      return _apiHandler.handleNetworkResultForList(
        response: res,
        fromJson: fromJson,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
        error: error,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
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
    bool attachCustomQuery = true,
    CancelToken? cancelToken,
    required JsonMapper<T> fromJson,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
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
        attachCustomQuery: attachCustomQuery,
        cancelToken: cancelToken,
        logSettings: settings?.logSettings,
      );
      return _apiHandler.handleNetworkResult(
        response: res,
        fromJson: fromJson,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
        error: error,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
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
    bool attachCustomQuery = true,
    CancelToken? cancelToken,
    required JsonMapper<T> fromJson,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
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
        attachCustomQuery: attachCustomQuery,
        cancelToken: cancelToken,
        logSettings: settings?.logSettings,
      );
      return _apiHandler.handleNetworkResultForList(
        response: res,
        fromJson: fromJson,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
        error: error,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
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
    bool attachCustomQuery = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
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
        attachCustomQuery: attachCustomQuery,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      );
      return _apiHandler.handleNetworkResult(
        response: res,
        fromJson: fromJson,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
        error: error,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
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
    bool attachCustomQuery = true,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
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
        attachCustomQuery: attachCustomQuery,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      );
      return _apiHandler.handleNetworkResultForList(
        response: res,
        fromJson: fromJson,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error) {
      return _apiHandler.handleDioException(
        error: error,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
    }
  }
}
