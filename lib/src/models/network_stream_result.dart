import 'dart:async';

import 'package:playx_core/playx_core.dart';
import 'package:playx_network/playx_network.dart';

/// Generic Wrapper class that represents a successful stream network response.
class NetworkStreamSuccess<T> extends NetworkStreamResult<T> {
  @override
  final Stream<T> data;

  NetworkStreamSuccess(this.data);

  @override
  String toString() => 'NetworkStreamSuccess: $data';
}

/// Generic Wrapper class that represents a failed stream network response.
class NetworkStreamError<T> extends NetworkStreamResult<T> {
  @override
  final NetworkException error;

  const NetworkStreamError(this.error);

  @override
  String toString() => 'NetworkStreamError: $error => ${error.message}';
}

/// Generic Wrapper class for handling streaming network results.
///
/// Unlike [NetworkResult] — which resolves to a single value — a
/// [NetworkStreamResult] wraps a [Stream] of decoded events when the request
/// succeeds, or a [NetworkException] when it fails before any data is
/// received.
///
/// Use [when] to branch on success/error, [map] / [mapAsync] to transform the
/// success stream, or the [success] / [error] factories directly.
sealed class NetworkStreamResult<T> {
  const NetworkStreamResult();

  /// Creates a successful [NetworkStreamResult] wrapping the given [stream].
  factory NetworkStreamResult.success(Stream<T> stream) =>
      NetworkStreamSuccess(stream);

  /// Creates a failed [NetworkStreamResult] wrapping the given [error].
  const factory NetworkStreamResult.error(NetworkException error) =
      NetworkStreamError<T>;

  /// The success stream if this is a success, otherwise `null`.
  Stream<T>? get data => (this is NetworkStreamSuccess<T>)
      ? (this as NetworkStreamSuccess<T>).data
      : null;

  /// The error if this is an error, otherwise `null`.
  NetworkException? get error => (this is NetworkStreamError<T>)
      ? (this as NetworkStreamError<T>).error
      : null;

  /// Whether the stream request was accepted and will emit events.
  bool get isSuccess => this is NetworkStreamSuccess<T>;

  /// Whether the stream request failed before producing any data.
  bool get isError => this is NetworkStreamError<T>;

  /// Performs an action based on whether the stream request was successful or
  /// not. Returns `this` for chaining.
  NetworkStreamResult<T> when({
    required void Function(Stream<T> success) success,
    required void Function(NetworkException error) error,
  }) {
    switch (this) {
      case NetworkStreamSuccess<T>():
        success((this as NetworkStreamSuccess<T>).data);
        break;
      case NetworkStreamError<T>():
        error((this as NetworkStreamError<T>).error);
        break;
    }
    return this;
  }

  /// Synchronously transforms the stream result into a value of type [S].
  S map<S>({
    required S Function(NetworkStreamSuccess<T> data) success,
    required S Function(NetworkStreamError<T> error) error,
  }) {
    return switch (this) {
      NetworkStreamSuccess<T>() => success(this as NetworkStreamSuccess<T>),
      NetworkStreamError<T>() => error(this as NetworkStreamError<T>),
    };
  }

  /// Asynchronously transforms the stream result into a value of type [S].
  Future<S> mapAsync<S>({
    required Future<S> Function(NetworkStreamSuccess<T> data) success,
    required Future<S> Function(NetworkStreamError<T> error) error,
  }) async {
    return switch (this) {
      NetworkStreamSuccess<T>() => success(this as NetworkStreamSuccess<T>),
      NetworkStreamError<T>() => error(this as NetworkStreamError<T>),
    };
  }

  /// Maps the success stream to another type [S], preserving the error case.
  ///
  /// [mapper] is applied to the success stream and must return a new stream.
  /// If this is an error, the original [NetworkException] is preserved.
  NetworkStreamResult<S> mapStream<S>({
    required Stream<S> Function(Stream<T> stream) mapper,
  }) {
    return switch (this) {
      NetworkStreamSuccess<T>() => NetworkStreamResult.success(
          mapper((this as NetworkStreamSuccess<T>).data),
        ),
      NetworkStreamError<T>() =>
        NetworkStreamResult.error((this as NetworkStreamError<T>).error),
    };
  }

  /// Maps the success data to another type asynchronously, with the option to
  /// map the error case or return null.
  FutureOr<NetworkStreamResult<S>> mapStreamAsync<S>({
    required FutureOr<Stream<S>> Function(Stream<T> stream) mapper,
  }) async {
    return switch (this) {
      NetworkStreamSuccess<T>() => NetworkStreamResult.success(
          await mapper((this as NetworkStreamSuccess<T>).data),
        ),
      NetworkStreamError<T>() =>
        NetworkStreamResult.error((this as NetworkStreamError<T>).error),
    };
  }

  /// Maps the network stream request whether it's success or error to your
  /// desired model asynchronously in an isolate.
  Future<NetworkStreamResult<S>> mapStreamAsyncInIsolate<S>({
    required Mapper<Stream<T>, NetworkStreamResult<S>> mapper,
    String? exceptionMessage,
    bool useWorkManager = true,
  }) async {
    try {
      final result = await MapUtils.mapAsyncInIsolate(
        data: this,
        mapper: (NetworkStreamResult<T> res) async {
          return switch (res) {
            NetworkStreamSuccess<T>() => await mapper(res.data),
            NetworkStreamError<T>() => NetworkStreamResult.error(res.error),
          };
        },
        useWorkManager: useWorkManager,
      );
      return result as NetworkStreamResult<S>;
    } catch (e) {
      return NetworkStreamResult.error(UnableToProcessException(
        errorMessage: exceptionMessage ??
            _exceptionMessages?.unableToProcess ??
            'unableToProcess',
        statusCode: -1,
        shouldShowApiError: false,
      ));
    }
  }

  /// Convenience: convert this [NetworkStreamResult] into a regular
  /// [NetworkResult] by collecting the success stream into a [List].
  ///
  /// Returns a [NetworkResult] of [List<T>] containing all emitted events on
  /// success, or the original error on failure.
  Future<NetworkResult<List<T>>> toList() async {
    return switch (this) {
      NetworkStreamSuccess<T>() => NetworkResult.success(
          await (this as NetworkStreamSuccess<T>).data.toList()),
      NetworkStreamError<T>() =>
        NetworkResult.error((this as NetworkStreamError<T>).error),
    };
  }

  ExceptionMessage? get _exceptionMessages => GetIt.instance
          .isRegistered<ExceptionMessage>(instanceName: 'exception_messages')
      ? GetIt.instance.get<ExceptionMessage>(instanceName: 'exception_messages')
      : null;
}
