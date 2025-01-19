import 'package:playx_core/playx_core.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/handler/api_handler.dart';

/// Generic Wrapper class that happens when receiving a valid network response.
class NetworkSuccess<T> extends NetworkResult<T> {
  final T data;

  const NetworkSuccess(this.data);
}

/// Generic Wrapper class that happens when an error happens.
class NetworkError<T> extends NetworkResult<T> {
  final NetworkException error;

  const NetworkError(this.error);
}

/// Generic Wrapper class for the result of network response.
/// when the network call is successful it returns [NetworkSuccess].
/// else it returns error with [NetworkException].
sealed class NetworkResult<T> {
  const NetworkResult();

  const factory NetworkResult.success(T data) = NetworkSuccess;

  const factory NetworkResult.error(NetworkException error) = NetworkError;

  /// Returns true if the network call is successful.
  bool get isSuccess => this is NetworkSuccess<T>;

  /// Returns true if the network call is failed.
  bool get isError => this is NetworkError<T>;

  /// Returns the data if the network call is successful.
  /// Otherwise, it returns null.
  T? get networkData => (this as NetworkSuccess<T>).data;

  /// Returns the error if the network call is failed.
  NetworkException? get networkError => (this as NetworkError<T>).error;

  ///Helps determining whether the network call is successful or not.
  void when({
    required Function(T success) success,
    required Function(NetworkException error) error,
  }) {
    switch (this) {
      case NetworkSuccess _:
        final data = (this as NetworkSuccess<T>).data;
        success(data);
      case NetworkError _:
        final exception = (this as NetworkError<T>).error;
        error(exception);
    }
  }

  ///Maps the network request whether it's success or error to your desired model.
  S map<S>({
    required S Function(NetworkSuccess<T> data) success,
    required S Function(NetworkError<T> error) error,
  }) {
    switch (this) {
      case NetworkSuccess _:
        return success(this as NetworkSuccess<T>);
      case NetworkError _:
        return error(this as NetworkError<T>);
    }
  }

  ///Maps the network request whether it's success or error to your desired model asynchronously.
  Future<S> mapAsync<S>({
    required Future<S> Function(NetworkSuccess<T> data) success,
    required Future<S> Function(NetworkError<T> error) error,
  }) {
    switch (this) {
      case NetworkSuccess _:
        return success(this as NetworkSuccess<T>);
      case NetworkError _:
        return error(this as NetworkError<T>);
    }
  }

  /// Maps the network request whether it's success or error to your desired model asynchronously.
  Future<NetworkResult<S>> mapDataAsync<S>({
    required Mapper<T, NetworkResult<S>> mapper,
  }) async {
    switch (this) {
      case NetworkSuccess _:
        final data = (this as NetworkSuccess<T>).data;
        return mapper(data);
      case NetworkError _:
        return NetworkResult.error((this as NetworkError<T>).error);
    }
  }

  ExceptionMessage get _exceptionMessages =>
      GetIt.instance.get<ExceptionMessage>();

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
      return mapAsyncInIsolate(
        success: (data) async {
          final res = await mapper(data);
          return res;
        },
        error: (error) async {
          return NetworkResult.error(error);
        },
        useWorkManager: useWorkManager,
      );
    } catch (e, s) {
      return ApiHandler.unableToProcessException(
          e: e,
          s: s,
          exceptionMessage:
              exceptionMessage ?? _exceptionMessages.unableToProcess);
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
        switch (res) {
          case NetworkSuccess():
            return await success(res.data);
          case NetworkError():
            return await error(res.error);
        }
      },
      useWorkManager: useWorkManager,
    );
  }
}
