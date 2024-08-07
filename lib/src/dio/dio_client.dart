import 'package:dio/dio.dart';

// ignore: avoid_classes_with_only_static_members
class DioClient {
  final Dio dio;
  final Future<Map<String, dynamic>> Function()? customHeaders;

  DioClient({required this.dio, this.customHeaders});

  /// sends a [GET] request to the given [url]
  Future<Response> get<T>(
    String path, {
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    Options? options,
    bool attachCustomHeaders = true,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return dio.get(path,
        queryParameters: query,
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
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    return dio.post(
      path,
      data: body,
      queryParameters: query,
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
    CancelToken? cancelToken,
  }) async {
    return dio.delete(
      path,
      data: body,
      queryParameters: query,
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
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    return dio.put(
      path,
      data: body,
      queryParameters: query,
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
