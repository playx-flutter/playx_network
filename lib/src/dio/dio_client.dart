import 'dart:async';

import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/utils/path_utils.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

/// A client for making network requests using Dio.
class DioClient {
  final Dio dio;
  final FutureOr<Map<String, dynamic>> Function()? customHeaders;
  final FutureOr<Map<String, dynamic>> Function()? customQuery;
  final FutureOr<Map<String, dynamic>> Function()? customPathParameters;

  final PlayxNetworkClientSettings settings;

  DioClient({
    required this.dio,
    this.customHeaders,
    this.customQuery,
    this.customPathParameters,
    required this.settings,
  }) {
    if (settings.logSettings.enabled) {
      dio.interceptors.add(
        settings.logSettings.buildTalkerDioLogger(),
      );
    }
  }

  /// Resolves the request [path] by substituting `{placeholder}` segments
  /// with the merged [pathParameters] and any [customPathParameters] when
  /// [attachCustomPathParameters] is `true`.
  Future<String> _resolvePath(
    String path,
    Map<String, dynamic> pathParameters,
    bool attachCustomPathParameters,
  ) async {
    // Nothing to substitute, so avoid running the (possibly async) callback.
    if (!path.contains('{')) return path;
    final merged = <String, dynamic>{
      if (attachCustomPathParameters && customPathParameters != null)
        ...?await customPathParameters?.call(),
      ...pathParameters,
    };
    return substitutePathParameters(path, merged);
  }

  /// The client-level custom headers, or nothing when they should not be
  /// attached.
  Future<Map<String, dynamic>> _customHeadersFor(bool attach) async =>
      attach && customHeaders != null
          ? await customHeaders!()
          : const <String, dynamic>{};

  /// The client-level custom query parameters, or nothing when they should not
  /// be attached.
  Future<Map<String, dynamic>> _customQueryFor(bool attach) async =>
      attach && customQuery != null
          ? await customQuery!()
          : const <String, dynamic>{};

  Dio _getDioInstance({
    PlayxNetworkLoggerSettings? logSettings,
  }) {
    if (logSettings == null || logSettings == settings.logSettings) {
      return dio;
    }

    // Swap the logger for one built from the per-request log settings, or
    // drop it when logging is disabled for this request.
    final interceptors = dio.interceptors.toList()
      ..removeWhere((element) => element is TalkerDioLogger);
    if (logSettings.enabled) {
      interceptors.add(logSettings.buildTalkerDioLogger());
    }
    return dio.copyWith(interceptors: interceptors);
  }

  /// sends a [GET] request to the given [url]
  ///
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the
  /// request is sent. Set [attachCustomPathParameters] to `false` to skip any
  /// client-level `customPathParameters`.
  Future<Response> get<T>(
    String path, {
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    PlayxNetworkLoggerSettings? logSettings,
  }) async {
    final resolvedPath =
        await _resolvePath(path, pathParameters, attachCustomPathParameters);
    return _getDioInstance(logSettings: logSettings).get(resolvedPath,
        queryParameters: {
          ...await _customQueryFor(attachCustomQuery),
          ...query,
        },
        options: options ??
            Options(
              headers: {
                ...await _customHeadersFor(attachCustomHeaders),
                ...headers,
              },
            ),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress);
  }

  /// Download file from the given [url]
  ///
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the
  /// request is sent. Set [attachCustomPathParameters] to `false` to skip any
  /// client-level `customPathParameters`.
  Future<Response> download<T>(String path,
      {required dynamic savePath,
      Map<String, dynamic> pathParameters = const {},
      Map<String, dynamic> headers = const {},
      Map<String, dynamic> query = const {},
      Options? options,
      bool attachCustomHeaders = true,
      bool attachCustomQuery = true,
      bool attachCustomPathParameters = true,
      CancelToken? cancelToken,
      ProgressCallback? onReceiveProgress,
      bool deleteOnError = true,
      String lengthHeader = Headers.contentLengthHeader,
      Object? data,
      PlayxNetworkLoggerSettings? logSettings,
      FileAccessMode fileAccessMode = FileAccessMode.write}) async {
    final resolvedPath =
        await _resolvePath(path, pathParameters, attachCustomPathParameters);
    return _getDioInstance(logSettings: logSettings).download(
      resolvedPath,
      savePath,
      queryParameters: {
        ...await _customQueryFor(attachCustomQuery),
        ...query,
      },
      options: options ??
          Options(
            headers: {
              ...await _customHeadersFor(attachCustomHeaders),
              ...headers,
            },
          ),
      fileAccessMode: fileAccessMode,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      deleteOnError: deleteOnError,
      lengthHeader: lengthHeader,
      data: data,
    );
  }

  /// sends a [POST] request to the given [url]
  ///
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the
  /// request is sent. Set [attachCustomPathParameters] to `false` to skip any
  /// client-level `customPathParameters`.
  Future<Response> post<T>(
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
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    PlayxNetworkLoggerSettings? logSettings,
  }) async {
    final resolvedPath =
        await _resolvePath(path, pathParameters, attachCustomPathParameters);
    return _getDioInstance(logSettings: logSettings).post(
      resolvedPath,
      data: body,
      queryParameters: {
        ...await _customQueryFor(attachCustomQuery),
        ...query,
      },
      options: options ??
          Options(
            headers: {
              ...await _customHeadersFor(attachCustomHeaders),
              ...headers,
            },
            contentType: contentType,
          ),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// sends a [DELETE] request to the given [url]
  ///
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the
  /// request is sent. Set [attachCustomPathParameters] to `false` to skip any
  /// client-level `customPathParameters`.
  Future<Response> delete<T>(
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
    PlayxNetworkLoggerSettings? logSettings,
  }) async {
    final resolvedPath =
        await _resolvePath(path, pathParameters, attachCustomPathParameters);
    return _getDioInstance(logSettings: logSettings).delete(
      resolvedPath,
      data: body,
      queryParameters: {
        ...await _customQueryFor(attachCustomQuery),
        ...query,
      },
      options: options ??
          Options(
            headers: {
              ...await _customHeadersFor(attachCustomHeaders),
              ...headers,
            },
            contentType: contentType,
          ),
      cancelToken: cancelToken,
    );
  }

  /// sends a [PUT] request to the given [url]
  ///
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the
  /// request is sent. Set [attachCustomPathParameters] to `false` to skip any
  /// client-level `customPathParameters`.
  Future<Response> put<T>(
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
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    PlayxNetworkLoggerSettings? logSettings,
  }) async {
    final resolvedPath =
        await _resolvePath(path, pathParameters, attachCustomPathParameters);
    return _getDioInstance(logSettings: logSettings).put(
      resolvedPath,
      data: body,
      queryParameters: {
        ...await _customQueryFor(attachCustomQuery),
        ...query,
      },
      options: options ??
          Options(
            headers: {
              ...await _customHeadersFor(attachCustomHeaders),
              ...headers,
            },
            contentType: contentType,
          ),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// sends a [PATCH] request to the given [url]
  ///
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the
  /// request is sent. Set [attachCustomPathParameters] to `false` to skip any
  /// client-level `customPathParameters`.
  Future<Response> patch<T>(
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
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    PlayxNetworkLoggerSettings? logSettings,
  }) async {
    final resolvedPath =
        await _resolvePath(path, pathParameters, attachCustomPathParameters);
    return _getDioInstance(logSettings: logSettings).patch(
      resolvedPath,
      data: body,
      queryParameters: {
        ...await _customQueryFor(attachCustomQuery),
        ...query,
      },
      options: options ??
          Options(
            headers: {
              ...await _customHeadersFor(attachCustomHeaders),
              ...headers,
            },
            contentType: contentType,
          ),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Builds the [Options] for a streaming request.
  ///
  /// Headers are merged with this precedence (later wins): client-level
  /// `customHeaders`, then `options.headers`, then the per-request [headers].
  /// Unlike a plain `copyWith(headers: ...)`, headers already set on the
  /// caller's [options] are kept.
  ///
  /// Streams can stay idle for a long time between events, so unless the
  /// caller sets `options.receiveTimeout` the receive timeout is disabled
  /// (`Duration.zero`) instead of cutting the stream off after the Dio default.
  Future<Options> _resolveStreamOptions({
    Options? options,
    required Map<String, dynamic> headers,
    required bool attachCustomHeaders,
    String? contentType,
  }) async {
    return (options ?? Options()).copyWith(
      headers: {
        ...await _customHeadersFor(attachCustomHeaders),
        ...?options?.headers,
        ...headers,
      },
      contentType: contentType ?? options?.contentType,
      responseType: ResponseType.stream,
      receiveTimeout: options?.receiveTimeout ?? Duration.zero,
    );
  }

  /// Sends a [GET] request and returns the response as a raw [ResponseBody]
  /// stream instead of waiting for the whole body.
  ///
  /// [pathParameters] replaces `{placeholder}` segments in [path] before the
  /// request is sent. Set [attachCustomPathParameters] to `false` to skip any
  /// client-level `customPathParameters`.
  ///
  /// The returned [ResponseBody.stream] can be consumed chunk-by-chunk. The
  /// caller is responsible for handling the stream lifecycle (listening and
  /// cancelling).
  Future<ResponseBody> getStream(
    String path, {
    Map<String, dynamic> pathParameters = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    bool attachCustomPathParameters = true,
    CancelToken? cancelToken,
    PlayxNetworkLoggerSettings? logSettings,
  }) async {
    final resolvedPath =
        await _resolvePath(path, pathParameters, attachCustomPathParameters);
    final dio = _getDioInstance(logSettings: logSettings);
    final response = await dio.get<ResponseBody>(
      resolvedPath,
      queryParameters: {
        ...await _customQueryFor(attachCustomQuery),
        ...query,
      },
      options: await _resolveStreamOptions(
        options: options,
        headers: headers,
        attachCustomHeaders: attachCustomHeaders,
      ),
      cancelToken: cancelToken,
    );
    return response.data!;
  }

  /// Sends a [POST] request and returns the response as a raw [ResponseBody]
  /// stream instead of waiting for the whole body.
  Future<ResponseBody> postStream(
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
    PlayxNetworkLoggerSettings? logSettings,
  }) async {
    final resolvedPath =
        await _resolvePath(path, pathParameters, attachCustomPathParameters);
    final dio = _getDioInstance(logSettings: logSettings);
    final response = await dio.post<ResponseBody>(
      resolvedPath,
      data: body,
      queryParameters: {
        ...await _customQueryFor(attachCustomQuery),
        ...query,
      },
      options: await _resolveStreamOptions(
        options: options,
        headers: headers,
        attachCustomHeaders: attachCustomHeaders,
        contentType: contentType,
      ),
      cancelToken: cancelToken,
    );
    return response.data!;
  }
}

extension DioClientExtensions on Dio {
  Dio copyWith({
    BaseOptions? options,
    HttpClientAdapter? httpClientAdapter,
    List<Interceptor>? interceptors,
    Transformer? transformer,
  }) {
    final dio = Dio(
      options ?? this.options,
    );
    dio.httpClientAdapter = httpClientAdapter ?? this.httpClientAdapter;
    // A new Dio already has Dio's default interceptor; drop it so it is not
    // duplicated by the copied ones (which include the original's).
    dio.interceptors
      ..clear(keepImplyContentTypeInterceptor: false)
      ..addAll(interceptors ?? this.interceptors);
    dio.transformer = transformer ?? this.transformer;
    return dio;
  }
}
