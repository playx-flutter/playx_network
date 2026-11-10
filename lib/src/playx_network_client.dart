import 'dart:async';

import 'package:dio/dio.dart';
import 'package:playx_core/playx_core.dart';

import 'dio/dio_client.dart';
import 'handler/api_handler.dart';
import 'handler/exception_mapper.dart';
import 'manager/playx_cancel_token_manager.dart';
import 'models/exceptions/message/exception_message.dart';
import 'models/network_result.dart';
import 'models/network_stream_result.dart';
import 'models/playx_stream_format.dart';
import 'models/settings/playx_network_client_settings.dart';

///Function that converts json response to the required model.
typedef JsonMapper<T> = FutureOr<T> Function(dynamic json);

///Function that converts json error response from api to error message.
typedef ErrorMapper = String? Function(dynamic json);

/// Converts the json error response of a failed request into structured data
/// (for example a custom error model) that is exposed as `ApiException.extra`.
/// It complements [ErrorMapper], which still produces the error message.
typedef ErrorExtraMapper = Object? Function(dynamic json);

/// Function that handles unauthorized request.
typedef UnauthorizedRequestHandler = void Function(Response? response);

/// PlayxNetworkClient is a Wrapper around [Dio] that can perform api request
/// With better error handling and easily get the result of any api request.
class PlayxNetworkClient {
  late final DioClient _dioClient;
  late final ApiHandler _apiHandler;
  late final PlayxCancelTokenManager _cancelTokenManager;

  ///Settings for the client.
  final PlayxNetworkClientSettings settings;

  ///Creates an instance of [PlayxNetworkClient]
  ///takes [Dio] object so u can easily customize your dio options.
  /// [customHeaders] which is custom headers that can included in each request like authorization token.
  /// [customQuery] which is custom query that can included in each request.
  /// [customPathParameters] which is custom path parameters that are substituted into `{placeholder}`
  /// segments of each request path, included in each request.
  /// [onUnauthorizedRequestReceived] which is a function that is called when unauthorized request is received.
  /// [errorMapper] which is a function that converts json error response from api to error message.
  /// [hasInternetConnection] which is an optional callback (for example backed by `connectivity_plus`) used only after a connection failure to tell "no internet" ([NoInternetConnectionException]) from "server unreachable" ([ServerUnreachableException]).
  /// [errorExtraMapper] which is an optional function that converts the json error response to a custom object, exposed as `ApiException.extra`.
  /// [settings] which is a settings object that can be used to customize the client.
  PlayxNetworkClient({
    required Dio dio,
    FutureOr<Map<String, dynamic>> Function()? customHeaders,
    FutureOr<Map<String, dynamic>> Function()? customQuery,
    FutureOr<Map<String, dynamic>> Function()? customPathParameters,
    UnauthorizedRequestHandler? onUnauthorizedRequestReceived,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    FutureOr<bool> Function()? hasInternetConnection,
    this.settings = const PlayxNetworkClientSettings(),
  }) {
    _cancelTokenManager = PlayxCancelTokenManager();
    _dioClient = DioClient(
      dio: dio,
      customHeaders: customHeaders,
      customQuery: customQuery,
      customPathParameters: customPathParameters,
      settings: settings,
    );
    final logger = PlayxLogger.hasLogger('Playx Network')
        ? PlayxLogger.getLogger('Playx Network')!
        : PlayxLogger.initLogger(
            name: 'Playx Network',
            setAsDefault: false,
          );

    _apiHandler = ApiHandler(
      errorMapper: errorMapper ?? ExceptionMapper.defaultErrorMessage,
      errorExtraMapper: errorExtraMapper,
      hasInternetConnection: hasInternetConnection,
      settings: settings,
      onUnauthorizedRequestReceived: onUnauthorizedRequestReceived,
      logger: logger,
    );

    if (GetIt.instance
        .isRegistered<ExceptionMessage>(instanceName: 'exception_messages')) {
      GetIt.instance
          .unregister<ExceptionMessage>(instanceName: 'exception_messages');
    }
    GetIt.instance.registerSingleton<ExceptionMessage>(
        settings.exceptionMessages,
        instanceName: 'exception_messages');
  }

  /// Cancels all requests concurrently associated with the given [cancelTag].
  void cancelRequestsByTag(String cancelTag, {dynamic reason}) {
    _cancelTokenManager.cancelRequests(cancelTag, reason: reason);
  }

  /// Cancels all pending requests managed by this client.
  void cancelAllRequests({dynamic reason}) {
    _cancelTokenManager.cancelAllRequests(reason: reason);
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
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkResult<T>> get<T>(
    String path, {
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    String? dataKey,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _request(
      send: () => _dioClient.get(
        path,
        pathParameters: pathParameters,
        headers: headers,
        query: query,
        options: options,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: resolvedCancelToken,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      ),
      handle: (res) => _apiHandler.handleNetworkResult(
        response: res,
        cancelToken: resolvedCancelToken,
        fromJson: fromJson,
        dataKey: dataKey,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
      ),
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  /// sends a [GET] request to the given [url]
  /// and returns [List] of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkResult<List<T>>> getList<T>(
    String path, {
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    String? dataKey,
    String? itemDataKey,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _request(
      send: () => _dioClient.get(
        path,
        pathParameters: pathParameters,
        headers: headers,
        query: query,
        options: options,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: resolvedCancelToken,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      ),
      handle: (res) => _apiHandler.handleNetworkResultForList(
        response: res,
        cancelToken: resolvedCancelToken,
        fromJson: fromJson,
        dataKey: dataKey,
        itemDataKey: itemDataKey,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
      ),
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  /// Download file from the given [url]
  /// and returns [NetworkResult] of [Response].
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkResult<Response>> download(
    String path, {
    required dynamic savePath,
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ProgressCallback? onReceiveProgress,
    JsonMapper? fromJson,
    bool shouldHandleUnauthorizedRequest = true,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    PlayxNetworkClientSettings? settings,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _request(
      send: () => _dioClient.download(
        path,
        savePath: savePath,
        pathParameters: pathParameters,
        headers: headers,
        query: query,
        options: options,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: resolvedCancelToken,
        onReceiveProgress: onReceiveProgress,
        data: data,
        deleteOnError: deleteOnError,
        lengthHeader: lengthHeader,
        logSettings: settings?.logSettings,
      ),
      handle: (res) => _apiHandler.handleNetworkResultForDownload(
        response: res,
        cancelToken: resolvedCancelToken,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
        settings: settings,
      ),
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  /// sends a [POST] request to the given [url]
  /// and returns object of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkResult<T>> post<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    String? dataKey,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _request(
      send: () => _dioClient.post(
        path,
        body: body,
        pathParameters: pathParameters,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: resolvedCancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      ),
      handle: (res) => _apiHandler.handleNetworkResult(
        response: res,
        cancelToken: resolvedCancelToken,
        fromJson: fromJson,
        dataKey: dataKey,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
      ),
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  /// sends a [POST] request to the given [url]
  /// and returns [List] of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkResult<List<T>>> postList<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    String? dataKey,
    String? itemDataKey,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _request(
      send: () => _dioClient.post(
        path,
        body: body,
        pathParameters: pathParameters,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: resolvedCancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      ),
      handle: (res) => _apiHandler.handleNetworkResultForList(
        response: res,
        cancelToken: resolvedCancelToken,
        fromJson: fromJson,
        dataKey: dataKey,
        itemDataKey: itemDataKey,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
      ),
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  /// sends a [DELETE] request to the given [url]
  /// and returns object of Type [T].
  ///
  /// [fromJson] is optional. When it is omitted, any successful response is
  /// returned as `NetworkResult.success(null)`, so use `delete<void>(...)` (or
  /// a nullable [T]) for endpoints that return no body.
  /// When it is provided and the successful response has an empty body, it is
  /// still a success and [fromJson] is called with `null` (no [dataKey]
  /// extraction is attempted).
  ///
  /// Note that `204 No Content` is only a success if it is listed in
  /// [PlayxNetworkClientSettings.successRequestCodes].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkResult<T>> delete<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    JsonMapper<T>? fromJson,
    String? dataKey,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _request(
      send: () => _dioClient.delete(
        path,
        body: body,
        pathParameters: pathParameters,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: resolvedCancelToken,
        logSettings: settings?.logSettings,
      ),
      handle: (res) => _apiHandler.handleNetworkResult<T>(
        response: res,
        cancelToken: resolvedCancelToken,
        fromJson: fromJson,
        allowEmptyResponse: true,
        dataKey: dataKey,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
      ),
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  /// sends a [DELETE] request to the given [url]
  /// and returns [List] of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkResult<List<T>>> deleteList<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    required JsonMapper<T> fromJson,
    String? dataKey,
    String? itemDataKey,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _request(
      send: () => _dioClient.delete(
        path,
        body: body,
        pathParameters: pathParameters,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: resolvedCancelToken,
        logSettings: settings?.logSettings,
      ),
      handle: (res) => _apiHandler.handleNetworkResultForList(
        response: res,
        cancelToken: resolvedCancelToken,
        fromJson: fromJson,
        dataKey: dataKey,
        itemDataKey: itemDataKey,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
      ),
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  /// sends a [PUT] request to the given [url]
  /// and returns object of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkResult<T>> put<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    String? dataKey,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _request(
      send: () => _dioClient.put(
        path,
        body: body,
        pathParameters: pathParameters,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: resolvedCancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      ),
      handle: (res) => _apiHandler.handleNetworkResult(
        response: res,
        cancelToken: resolvedCancelToken,
        fromJson: fromJson,
        dataKey: dataKey,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
      ),
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  /// sends a [PUT] request to the given [url]
  /// and returns [List] of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkResult<List<T>>> putList<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    String? dataKey,
    String? itemDataKey,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _request(
      send: () => _dioClient.put(
        path,
        body: body,
        pathParameters: pathParameters,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: resolvedCancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      ),
      handle: (res) => _apiHandler.handleNetworkResultForList(
        response: res,
        cancelToken: resolvedCancelToken,
        fromJson: fromJson,
        dataKey: dataKey,
        itemDataKey: itemDataKey,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
      ),
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  /// sends a [PATCH] request to the given [url]
  /// and returns object of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkResult<T>> patch<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    String? dataKey,
    String? itemDataKey,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _request(
      send: () => _dioClient.patch(
        path,
        body: body,
        pathParameters: pathParameters,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: resolvedCancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      ),
      handle: (res) => _apiHandler.handleNetworkResult(
        response: res,
        cancelToken: resolvedCancelToken,
        fromJson: fromJson,
        dataKey: dataKey,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
      ),
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  /// sends a [PATCH] request to the given [url]
  /// and returns [List] of Type [T].
  /// You can pass your own queries, headers weather to attach custom headers or not.
  /// Or add custom options which overrides headers and custom headers.
  /// Or add cancel token to cancel the request.
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkResult<List<T>>> patchList<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required JsonMapper<T> fromJson,
    String? dataKey,
    String? itemDataKey,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _request(
      send: () => _dioClient.patch(
        path,
        body: body,
        pathParameters: pathParameters,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: resolvedCancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        logSettings: settings?.logSettings,
      ),
      handle: (res) => _apiHandler.handleNetworkResultForList(
        response: res,
        cancelToken: resolvedCancelToken,
        fromJson: fromJson,
        dataKey: dataKey,
        itemDataKey: itemDataKey,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
      ),
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  // ---------------------------------------------------------------------------
  // Streaming requests
  // ---------------------------------------------------------------------------

  /// Sends a [GET] request to the given [path] and returns a
  /// [NetworkStreamResult] wrapping a [Stream] of decoded events.
  ///
  /// The [format] parameter controls how the raw byte chunks emitted by the
  /// server are decoded before being emitted by the returned stream:
  /// - [PlayxStreamFormat.bytes] → emits `List<int>` chunks.
  /// - [PlayxStreamFormat.text]  → emits `String` chunks (UTF-8 decoded).
  /// - [PlayxStreamFormat.json]  → emits decoded JSON objects per chunk.
  /// - [PlayxStreamFormat.sse]   → emits [PlayxSseEvent]s (Server-Sent Events).
  ///
  /// When the request fails (non-success status code or a [DioException]), a
  /// [NetworkStreamResult.error] is returned containing the appropriate
  /// [NetworkException]; no stream is emitted.
  ///
  /// The returned stream is a **single-subscription** stream — consume it
  /// once. Cancelling the request via [cancelToken] or [cancelTag] also
  /// cancels the stream subscription.
  ///
  /// Example:
  /// ```dart
  /// final result = await client.getStream(
  ///   '/events',
  ///   format: PlayxStreamFormat.sse,
  /// );
  /// result.when(
  ///   success: (events) => events.listen((event) {
  ///     print('Received: ${event.data}');
  ///   }),
  ///   error: (error) => print('Error: ${error.message}'),
  /// );
  /// ```
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkStreamResult<T>> getStream<T>(
    String path, {
    Map<String, dynamic> pathParameters = const {},
    required PlayxStreamFormat format,
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _streamRequest<T>(
      send: (streamToken) => _dioClient.getStream(
        path,
        pathParameters: pathParameters,
        headers: headers,
        query: query,
        options: options,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: streamToken,
        logSettings: settings?.logSettings,
      ),
      format: format,
      cancelToken: resolvedCancelToken,
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  /// Sends a [POST] request to the given [path] and returns a
  /// [NetworkStreamResult] wrapping a [Stream] of decoded events.
  ///
  /// See [getStream] for the meaning of [format] and the streaming semantics.
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkStreamResult<T>> postStream<T>(
    String path, {
    Map<String, dynamic> pathParameters = const {},
    required PlayxStreamFormat format,
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) async {
    final resolvedCancelToken =
        _resolveCancelToken(cancelToken, cancelTag, cancelOld);
    return _streamRequest<T>(
      send: (streamToken) => _dioClient.postStream(
        path,
        pathParameters: pathParameters,
        body: body,
        headers: headers,
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: streamToken,
        logSettings: settings?.logSettings,
      ),
      format: format,
      cancelToken: resolvedCancelToken,
      shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
      settings: settings,
      errorMapper: errorMapper,
      errorExtraMapper: errorExtraMapper,
    );
  }

  /// Convenience method for consuming Server-Sent Events (SSE) via a [GET]
  /// request. Returns a [NetworkStreamResult] of [PlayxSseEvent].
  ///
  /// This is [getStream] with `format: PlayxStreamFormat.sse`, plus the
  /// `Accept: text/event-stream` and `Cache-Control: no-cache` headers unless
  /// you set them yourself in [headers] or `options.headers`.
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkStreamResult<PlayxSseEvent>> getSse(
    String path, {
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) =>
      getStream<PlayxSseEvent>(
        path,
        pathParameters: pathParameters,
        format: PlayxStreamFormat.sse,
        headers: _withSseHeaders(headers, options),
        query: query,
        options: options,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: cancelToken,
        cancelTag: cancelTag,
        cancelOld: cancelOld,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );

  /// Convenience method for consuming Server-Sent Events (SSE) via a [POST]
  /// request. Returns a [NetworkStreamResult] of [PlayxSseEvent].
  ///
  /// This is [postStream] with `format: PlayxStreamFormat.sse`, plus the SSE
  /// request headers described in [getSse].
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the request is sent.
  /// Set [attachCustomPathParameters] to `false` to skip any client-level `customPathParameters`.
  Future<NetworkStreamResult<PlayxSseEvent>> postSse(
    String path, {
    Map<String, dynamic> pathParameters = const {},
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld = true,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
    bool shouldHandleUnauthorizedRequest = true,
    PlayxNetworkClientSettings? settings,
  }) =>
      postStream<PlayxSseEvent>(
        path,
        pathParameters: pathParameters,
        format: PlayxStreamFormat.sse,
        body: body,
        headers: _withSseHeaders(headers, options),
        query: query,
        options: options,
        contentType: contentType,
        attachCustomHeaders: attachCustomHeaders,
        attachCustomQuery: attachCustomQuery,
        attachCustomPathParameters: attachCustomPathParameters,
        cancelToken: cancelToken,
        cancelTag: cancelTag,
        cancelOld: cancelOld,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );

  /// Returns the token of [cancelTag] from the cancel token manager, or
  /// [cancelToken] when no tag is given.
  CancelToken? _resolveCancelToken(
    CancelToken? cancelToken,
    String? cancelTag,
    bool cancelOld,
  ) =>
      cancelTag != null
          ? _cancelTokenManager.getToken(cancelTag, cancelOld: cancelOld)
          : cancelToken;

  /// Sends a request with [send], turns the response into a result with
  /// [handle], and maps anything thrown by either into a
  /// [NetworkResult.error].
  Future<NetworkResult<R>> _request<R>({
    required Future<Response<dynamic>> Function() send,
    required Future<NetworkResult<R>> Function(Response<dynamic> response)
        handle,
    required bool shouldHandleUnauthorizedRequest,
    PlayxNetworkClientSettings? settings,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
  }) async {
    try {
      return await handle(await send());
      // ignore: avoid_catches_without_on_clauses
    } catch (error, stackTrace) {
      return _apiHandler.handleDioException<R>(
        error: error,
        stackTrace: stackTrace,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
      );
    }
  }

  /// Sends a streaming request with [send] and wraps the response body in a
  /// [NetworkStreamResult]. [send] receives a request-scoped cancel token that
  /// is linked to [cancelToken], see [_streamToken]. Anything thrown while
  /// connecting becomes a [NetworkStreamResult.error].
  Future<NetworkStreamResult<R>> _streamRequest<R>({
    required Future<ResponseBody> Function(CancelToken streamToken) send,
    required PlayxStreamFormat format,
    required CancelToken? cancelToken,
    required bool shouldHandleUnauthorizedRequest,
    PlayxNetworkClientSettings? settings,
    ErrorMapper? errorMapper,
    ErrorExtraMapper? errorExtraMapper,
  }) async {
    final streamToken = _streamToken(cancelToken);
    try {
      final res = await send(streamToken);
      return await _apiHandler.handleStreamResult<R>(
        responseBody: res,
        statusCode: res.statusCode,
        statusMessage: res.statusMessage,
        format: format,
        cancelToken: cancelToken,
        abort: () => streamToken.cancel(),
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (error, stackTrace) {
      final failed = await _apiHandler.handleDioException<R>(
        error: error,
        stackTrace: stackTrace,
        shouldHandleUnauthorizedRequest: shouldHandleUnauthorizedRequest,
        settings: settings,
        errorMapper: errorMapper,
        errorExtraMapper: errorExtraMapper,
      );
      return NetworkStreamResult.error(failed.error!);
    }
  }

  /// Creates a [CancelToken] owned by a single stream request and linked to
  /// the caller's [parent] token. Cancelling [parent] cancels the request;
  /// the library can cancel the request to release the connection (when the
  /// stream listener cancels) without ever cancelling the caller's token.
  CancelToken _streamToken(CancelToken? parent) {
    final token = CancelToken();
    parent?.whenCancel.then((e) => token.cancel(e.error));
    return token;
  }

  /// Adds the default SSE request headers unless the caller already set them.
  Map<String, dynamic> _withSseHeaders(
    Map<String, dynamic> headers,
    Options? options,
  ) {
    bool has(String name) => [headers, options?.headers ?? const {}].any(
          (map) => map.keys.any((key) => key.toLowerCase() == name),
        );
    return {
      if (!has('accept')) 'Accept': 'text/event-stream',
      if (!has('cache-control')) 'Cache-Control': 'no-cache',
      ...headers,
    };
  }
}
