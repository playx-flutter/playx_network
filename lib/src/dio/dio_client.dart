import 'dart:async';

import 'package:playx_network/playx_network.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

// ignore: avoid_classes_with_only_static_members
/// A client for making network requests using Dio.
class DioClient {
  final Dio dio;
  final FutureOr<Map<String, dynamic>> Function()? customHeaders;
  final FutureOr<Map<String, dynamic>> Function()? customQuery;

  final PlayxNetworkClientSettings settings;

  bool attachLogSettings(PlayxNetworkLoggerSettings logSettings) =>
      logSettings.enabled;

  DioClient(
      {required this.dio,
      this.customHeaders,
      this.customQuery,
      required this.settings}) {
    if(settings.logSettings.enabled) {
      dio.interceptors.add(
        settings.logSettings.buildTalkerDioLogger(),
      );
    }
  }

  Dio _getDioInstance({
    PlayxNetworkLoggerSettings? logSettings,
  }) {
    if (logSettings == null || logSettings == settings.logSettings) {
      return dio;
    }

    final shouldAttachLogSettings = attachLogSettings(logSettings);

    final interceptors = dio.interceptors.toList();
    if (shouldAttachLogSettings) {
      interceptors.removeWhere((element) => element is TalkerDioLogger);
      interceptors.add(logSettings.buildTalkerDioLogger());
    } else {
      interceptors.removeWhere((element) => element is TalkerDioLogger);
    }
    final updatedDio = dio.copyWith(interceptors: interceptors);
    return updatedDio;
  }

  /// sends a [GET] request to the given [url]
  Future<Response> get<T>(
    String path, {
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    PlayxNetworkLoggerSettings? logSettings,
  }) async {
    return _getDioInstance(logSettings: logSettings).get(path,
        queryParameters: {
          if (attachCustomQuery && customQuery != null)
            ...?await customQuery?.call(),
          ...query,
        },
        options: options ??
            Options(
              headers: {
                if (attachCustomHeaders && customHeaders != null)
                  ...?await customHeaders?.call(),
                ...headers,
              },
            ),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress);
  }

  /// Download file from the given [url]
  Future<Response> download<T>(
    String path, {
    required dynamic savePath,
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    Object? data,
    PlayxNetworkLoggerSettings? logSettings,
        FileAccessMode fileAccessMode =FileAccessMode.write
  }) async {
    return _getDioInstance(logSettings: logSettings).download(
      path,
      savePath,
      queryParameters: {
        if (attachCustomQuery && customQuery != null)
          ...?await customQuery?.call(),
        ...query,
      },
      options: options ??
          Options(
            headers: {
              if (attachCustomHeaders && customHeaders != null)
                ...?await customHeaders?.call(),
              ...headers,
            },
          ),
      fileAccessMode:fileAccessMode,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      deleteOnError: deleteOnError,
      lengthHeader: lengthHeader,
      data: data,
    );
  }

  /// sends a [POST] request to the given [url]
  Future<Response> post<T>(
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
    PlayxNetworkLoggerSettings? logSettings,
  }) async {
    return _getDioInstance(logSettings: logSettings).post(
      path,
      data: body,
      queryParameters: {
        if (attachCustomQuery && customQuery != null)
          ...?await customQuery?.call(),
        ...query,
      },
      options: options ??
          Options(
            headers: {
              if (attachCustomHeaders && customHeaders != null)
                ...?await customHeaders?.call(),
              ...headers,
            },
            contentType: contentType,
          ),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response> delete<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    String? contentType,
    bool attachCustomHeaders = true,
    bool attachCustomQuery = true,
    CancelToken? cancelToken,
    PlayxNetworkLoggerSettings? logSettings,
  }) async {
    return _getDioInstance(logSettings: logSettings).delete(
      path,
      data: body,
      queryParameters: {
        if (attachCustomQuery && customQuery != null)
          ...?await customQuery?.call(),
        ...query,
      },
      options: options ??
          Options(
            headers: {
              if (attachCustomHeaders && customHeaders != null)
                ...?await customHeaders?.call(),
              ...headers,
            },
            contentType: contentType,
          ),
      cancelToken: cancelToken,
    );
  }

  Future<Response> put<T>(
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
    PlayxNetworkLoggerSettings? logSettings,
  }) async {
    return _getDioInstance(logSettings: logSettings).put(
      path,
      data: body,
      queryParameters: {
        if (attachCustomQuery && customQuery != null)
          ...?await customQuery?.call(),
        ...query,
      },
      options: options ??
          Options(
            headers: {
              if (attachCustomHeaders && customHeaders != null)
                ...?await customHeaders?.call(),
              ...headers,
            },
            contentType: contentType,
          ),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
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
    dio.interceptors.addAll(interceptors ?? this.interceptors);
    dio.transformer = transformer ?? this.transformer;
    return dio;
  }
}
