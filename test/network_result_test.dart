import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:playx_network/playx_network.dart';

// Isolates can only run top-level or static functions.
Future<NetworkResult<String>> _toLabel(int value) async =>
    NetworkResult.success('value-$value');
Future<String> _successLabel(int value) async => 'ok-$value';
Future<String> _errorLabel(NetworkException error) async =>
    'error-${error.errorMessage}';

const _error = UnexpectedErrorException(errorMessage: 'boom');

void main() {
  group('NetworkResult', () {
    test('success exposes data and no error', () {
      const result = NetworkResult.success(5);
      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
      expect(result.data, 5);
      expect(result.error, isNull);
      expect(result.toString(), 'NetworkSuccess: 5');
    });

    test('error exposes the exception and no data', () {
      const result = NetworkResult<int>.error(_error);
      expect(result.isError, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.data, isNull);
      expect(result.error, _error);
      expect(result.toString(), 'NetworkError: $_error => boom');
    });

    test('when runs the matching callback and returns the result', () {
      var seen = '';
      const NetworkResult<int> success = NetworkResult.success(1);
      const NetworkResult<int> failure = NetworkResult.error(_error);

      expect(
        success.when(
          success: (v) => seen = 'success $v',
          error: (e) => seen = 'error',
        ),
        same(success),
      );
      expect(seen, 'success 1');

      failure.when(
        success: (v) => seen = 'success',
        error: (e) => seen = e.message,
      );
      expect(seen, 'boom');
    });

    test('map transforms either case', () {
      const NetworkResult<int> success = NetworkResult.success(2);
      const NetworkResult<int> failure = NetworkResult.error(_error);
      expect(success.map(success: (s) => s.data * 10, error: (_) => -1), 20);
      expect(
        failure.map(success: (s) => 0, error: (e) => e.error.message),
        'boom',
      );
    });

    test('mapAsync transforms either case', () async {
      const NetworkResult<int> success = NetworkResult.success(2);
      const NetworkResult<int> failure = NetworkResult.error(_error);
      expect(
        await success.mapAsync(
          success: (s) async => 's${s.data}',
          error: (e) async => 'e',
        ),
        's2',
      );
      expect(
        await failure.mapAsync(
          success: (s) async => 's',
          error: (e) async => 'e',
        ),
        'e',
      );
    });

    test('mapDataAsync maps success and keeps the error', () async {
      const NetworkResult<int> success = NetworkResult.success(3);
      const NetworkResult<int> failure = NetworkResult.error(_error);
      final mapped = await success.mapDataAsync(mapper: _toLabel);
      expect(mapped.data, 'value-3');
      final kept = await failure.mapDataAsync(mapper: _toLabel);
      expect(kept.error, _error);
    });

    test('mapDataAsyncOrNull maps success, maps or drops the error', () async {
      const NetworkResult<int> success = NetworkResult.success(4);
      const NetworkResult<int> failure = NetworkResult.error(_error);
      expect(await success.mapDataAsyncOrNull(mapper: (v) => 'v$v'), 'v4');
      expect(await failure.mapDataAsyncOrNull(mapper: (v) => 'v$v'), isNull);
      expect(
        await failure.mapDataAsyncOrNull(
          mapper: (v) => 'v$v',
          errorMapper: (e) => 'handled ${e.message}',
        ),
        'handled boom',
      );
    });

    test('mapAsyncInIsolate maps success and error in an isolate', () async {
      const NetworkResult<int> success = NetworkResult.success(7);
      const NetworkResult<int> failure = NetworkResult.error(_error);
      expect(
        await success.mapAsyncInIsolate(
          success: _successLabel,
          error: _errorLabel,
          useWorkManager: false,
        ),
        'ok-7',
      );
      expect(
        await failure.mapAsyncInIsolate(
          success: _successLabel,
          error: _errorLabel,
          useWorkManager: false,
        ),
        'error-boom',
      );
    });

    test('mapDataAsyncInIsolate maps success and keeps the error', () async {
      const NetworkResult<int> success = NetworkResult.success(8);
      const NetworkResult<int> failure = NetworkResult.error(_error);
      final mapped = await success.mapDataAsyncInIsolate(
        mapper: _toLabel,
        useWorkManager: false,
      );
      expect(mapped.data, 'value-8');
      final kept = await failure.mapDataAsyncInIsolate(
        mapper: _toLabel,
        useWorkManager: false,
      );
      expect(kept.error, _error);
    });

    test('mapDataAsyncInIsolate reports a failing mapper', () async {
      const NetworkResult<int> success = NetworkResult.success(9);
      final result = await success.mapDataAsyncInIsolate<String>(
        mapper: _failingMapper,
        useWorkManager: false,
        exceptionMessage: 'custom message',
      );
      expect(result.error, isA<UnableToProcessException>());
      expect(result.error!.errorMessage, 'custom message');
    });

    test(
      'mapDataAsyncInIsolate falls back to the registered messages',
      () async {
        GetIt.instance.registerSingleton<ExceptionMessage>(
          const DefaultEnglishExceptionMessage(),
          instanceName: 'exception_messages',
        );
        addTearDown(
          () => GetIt.instance.unregister<ExceptionMessage>(
            instanceName: 'exception_messages',
          ),
        );

        const NetworkResult<int> success = NetworkResult.success(9);
        final result = await success.mapDataAsyncInIsolate<String>(
          mapper: _failingMapper,
          useWorkManager: false,
        );
        expect(
          result.error!.errorMessage,
          const DefaultEnglishExceptionMessage().unableToProcess,
        );
      },
    );

    test('errorExtraAs reads the extra data of a failed result', () {
      const result = NetworkResult<int>.error(
        DefaultApiException(errorMessage: 'x', extra: 'payload'),
      );
      expect(result.errorExtraAs<String>(), 'payload');
      expect(result.errorExtraAs<int>(), isNull);
      expect(const NetworkResult.success(1).errorExtraAs<String>(), isNull);
    });
  });
}

Future<NetworkResult<String>> _failingMapper(int value) async =>
    throw StateError('cannot map');
