import 'dart:async';

import 'package:playx_core/playx_core.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/handler/api_handler.dart';

/// Generic Wrapper class that represents a successful network response.
class NetworkSuccess<T> extends NetworkResult<T> {
  @override
  final T data;

  const NetworkSuccess(this.data);

  @override
  String toString() => 'NetworkSuccess: $data';
}

/// Generic Wrapper class that represents a failed network response.
class NetworkError<T> extends NetworkResult<T> {
  @override
  final NetworkException error;

  const NetworkError(this.error);

  @override
  String toString() => 'NetworkError: $error => ${error.message}';
}

/// Generic Wrapper class for handling network results.
/// - If successful, returns a [NetworkSuccess].
/// - If failed, returns a [NetworkError] with a [NetworkException].
sealed class NetworkResult<T> {
  const NetworkResult();

  const factory NetworkResult.success(T data) = NetworkSuccess;
  const factory NetworkResult.error(NetworkException error) = NetworkError;

  /// Checks if the network response is successful.
  bool get isSuccess => this is NetworkSuccess<T>;

  /// Checks if the network response contains an error.
  bool get isError => this is NetworkError<T>;

  /// Retrieves the success data if available, otherwise `null`.
  T? get data => (this is NetworkSuccess<T>) ? (this as NetworkSuccess<T>).data : null;

  /// Retrieves the error if the request failed, otherwise `null`.
  NetworkException? get error => (this is NetworkError<T>) ? (this as NetworkError<T>).error : null;


  /// Performs an action based on whether the network call was successful or not.
  NetworkResult<T> when({
    required void Function(T success) success,
    required void Function(NetworkException error) error,
  }) {
    switch (this) {
      case NetworkSuccess<T>():
        success((this as NetworkSuccess<T>).data);
        break;
      case NetworkError<T>():
        error((this as NetworkError<T>).error);
        break;
    }
    return this;
  }

  /// Transforms the network result into a desired type.
  S map<S>({
    required S Function(NetworkSuccess<T> data) success,
    required S Function(NetworkError<T> error) error,
  }) {
    return switch (this) {
      NetworkSuccess<T>() => success(this as NetworkSuccess<T>),
      NetworkError<T>() => error(this as NetworkError<T>),
    };
  }

  /// Transforms the network result asynchronously into a desired type.
  Future<S> mapAsync<S>({
    required Future<S> Function(NetworkSuccess<T> data) success,
    required Future<S> Function(NetworkError<T> error) error,
  }) async {
    return switch (this) {
      NetworkSuccess<T>() => success(this as NetworkSuccess<T>),
      NetworkError<T>() => error(this as NetworkError<T>),
    };
  }


  /// Maps the success case to another type asynchronously, preserving the error case.
  FutureOr<NetworkResult<S>> mapDataAsync<S>({
    required Mapper<T, NetworkResult<S>> mapper,
  }) async {
    return switch (this) {
      NetworkSuccess<T>() => await mapper((this as NetworkSuccess<T>).data),
      NetworkError<T>() => NetworkResult.error((this as NetworkError<T>).error),
    };
  }

  /// Maps the success data to another type asynchronously, With option to map the error case or return null.
  FutureOr<S?> mapDataAsyncOrNull<S>({
    required Mapper<T, S> mapper,
    Mapper<NetworkException, S>? errorMapper,
  }) async {
    return switch (this) {
      NetworkSuccess<T>() => await mapper((this as NetworkSuccess<T>).data),
      NetworkError<T>() => errorMapper?.call((this as NetworkError<T>).error),
    };
  }


  /// Maps the network request whether it's success or error to your desired model asynchronously in an isolate.
  ///
  /// [mapper] is the function that maps the data to your desired model.
  /// [exceptionMessage] is the message that will be shown when an exception occurs.
  /// [useWorkManager] is used to determine whether to use work manager for mapping json in isolate or use [compute] function.
  Future<NetworkResult<S>> mapDataAsyncInIsolate<S>({
    required Mapper<T, NetworkResult<S>> mapper,
    String? exceptionMessage,
    bool useWorkManager = true,
  }) async {
    try {
      return await mapAsyncInIsolate(
        success: mapper,
        error: (error) async => NetworkResult.error(error),
        useWorkManager: useWorkManager,
      );
    } catch (e, s) {
      return ApiHandler.unableToProcessException(
        e: e,
        s: s,
        exceptionMessage: exceptionMessage ?? _exceptionMessages?.unableToProcess ?? 'unableToProcess',
      );
    }
  }

  /// Maps the network request whether it's success or error to your desired model asynchronously in an isolate.
  ///
  /// [success] is the function that maps the success data to your desired model.
  /// [error] is the function that maps the error data to your desired model.
  /// [useWorkManager] is used to determine whether to use work manager for mapping json in isolate or use [compute] function.
  Future<S> mapAsyncInIsolate<S>({
    required Mapper<T, S> success,
    required Mapper<NetworkException, S> error,
    bool useWorkManager = true,
  }) async {
    return MapUtils.mapAsyncInIsolate(
      data: this,
      mapper: (NetworkResult<T> res) async {
        return switch (res) {
          NetworkSuccess<T>() => await success(res.data),
          NetworkError<T>() => await error(res.error),
        };
      },
      useWorkManager: useWorkManager,
    );
  }

  ExceptionMessage? get _exceptionMessages =>
      GetIt.instance.isRegistered<ExceptionMessage>(instanceName: 'exception_messages')
          ? GetIt.instance.get<ExceptionMessage>(instanceName: 'exception_messages')
          : null;
}
