import 'dart:async';

import 'package:dio/dio.dart';

// ignore: avoid_classes_with_only_static_members
class DioClient {
  final Dio dio;
  final FutureOr<Map<String, dynamic>> Function()? customHeaders;
  final FutureOr<Map<String, dynamic>> Function()? customQuery;

  DioClient({required this.dio, this.customHeaders, this.customQuery});

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
  }) async {
    return dio.get(path,
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
  }) async {
    return dio.post(
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
  }) async {
    return dio.delete(
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
  }) async {
    return dio.put(
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
