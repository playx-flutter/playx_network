
import 'package:dio/dio.dart';

// ignore: avoid_classes_with_only_static_members
class DioClient {
  final Dio dio;
  final String? token;
  DioClient({required this.dio, this.token});

  static Dio createDioClient({required String baseUrl,}) {
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
  Future<Response> get<T>(
    String path, {
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    bool attachToken = true,
    CancelToken? cancelToken,
  }) async {

    return dio.get(
      path,
      queryParameters: query,
      options: Options(
        headers: {
          // 'accept-lang': Lang.current.languageCode,

          if (attachToken && token != null) 'authorization': 'Bearer $token',
          ...headers,
        },
      ),
      cancelToken: cancelToken,
    );
  }

  Future<Response> post<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    String? contentType,
    bool attachToken = true,
    CancelToken? cancelToken,
  }) async {
    return dio.post(
      path,
      data: body,
      queryParameters: query,
      options: Options(
        headers: {
          // 'accept-lang': Lang.current.languageCode,
          if (attachToken && token != null) 'authorization': 'Bearer $token',
          ...headers,
        },
        contentType: contentType,
      ),
      cancelToken: cancelToken,
    );
  }

  Future<Response> delete<T>(
    String path, {
    Object body = const {},
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> query = const {},
    String? contentType,
    bool attachToken = true,
    CancelToken? cancelToken,
  }) async {
    return dio.delete(
      path,
      data: body,
      queryParameters: query,
      options: Options(
        headers: {
          // 'accept-lang': Lang.current.languageCode,
          if (attachToken && token != null) 'authorization': 'Bearer $token',
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
    String? contentType,
    bool attachToken = true,
    CancelToken? cancelToken,
  }) async {
    return dio.put(
      path,
      data: body,
      queryParameters: query,
      options: Options(
        headers: {
          // 'accept-lang': Lang.current.languageCode,
          if (attachToken && token != null) 'authorization': 'Bearer $token',
          ...headers,
        },
        contentType: contentType,
      ),
      cancelToken: cancelToken,
    );
  }
}
