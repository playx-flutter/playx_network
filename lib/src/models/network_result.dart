import 'exceptions/network_exception.dart';

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
}
