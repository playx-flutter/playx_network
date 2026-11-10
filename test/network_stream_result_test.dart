import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:playx_network/playx_network.dart';

const _error = UnexpectedErrorException(errorMessage: 'boom');

Stream<int> _numbers() => Stream.fromIterable([1, 2, 3]);

Stream<int> _failingNumbers() async* {
  yield 1;
  throw StateError('not a network exception');
}

void main() {
  group('NetworkStreamResult', () {
    test('success exposes the stream and no error', () async {
      final result = NetworkStreamResult.success(_numbers());
      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
      expect(result.error, isNull);
      expect(await result.data!.toList(), [1, 2, 3]);
      expect(result.toString(), startsWith('NetworkStreamSuccess'));
    });

    test('error exposes the exception and no stream', () {
      const result = NetworkStreamResult<int>.error(_error);
      expect(result.isError, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.data, isNull);
      expect(result.error, _error);
      expect(result.toString(), 'NetworkStreamError: $_error => boom');
    });

    test('mapAsync transforms either case', () async {
      final success = NetworkStreamResult.success(_numbers());
      const failure = NetworkStreamResult<int>.error(_error);

      expect(
        await success.mapAsync(
          success: (s) async => await s.data.length,
          error: (e) async => -1,
        ),
        3,
      );
      expect(
        await failure.mapAsync(
          success: (s) async => 0,
          error: (e) async => e.error.message.length,
        ),
        4,
      );
    });

    test('mapStreamAsync maps the stream and keeps the error', () async {
      final success = NetworkStreamResult.success(_numbers());
      final mapped = await success.mapStreamAsync<String>(
        mapper: (stream) async => stream.map((n) => 'n$n'),
      );
      expect(await mapped.data!.toList(), ['n1', 'n2', 'n3']);

      const failure = NetworkStreamResult<int>.error(_error);
      final kept = await failure.mapStreamAsync<String>(
        mapper: (stream) async => stream.map((n) => 'n$n'),
      );
      expect(kept.error, _error);
    });

    test('mapStream maps the stream and keeps the error', () async {
      final mapped = NetworkStreamResult.success(
        _numbers(),
      ).mapStream<int>(mapper: (stream) => stream.map((n) => n * 2));
      expect(await mapped.data!.toList(), [2, 4, 6]);
      const failure = NetworkStreamResult<int>.error(_error);
      expect(failure.mapStream<int>(mapper: (s) => s).error, _error);
    });
  });

  group('NetworkStreamResult.toList', () {
    test('collects the stream', () async {
      final list = await NetworkStreamResult.success(_numbers()).toList();
      expect(list.data, [1, 2, 3]);
    });

    test('a network exception in the stream becomes an error result', () async {
      final stream = Stream<int>.error(_error);
      final list = await NetworkStreamResult.success(stream).toList();
      expect(list.error, _error);
    });

    test('any other error becomes an UnexpectedErrorException', () async {
      final list = await NetworkStreamResult.success(
        _failingNumbers(),
      ).toList();
      expect(list.error, isA<UnexpectedErrorException>());
      expect(list.error!.errorMessage, 'unexpectedError');
    });

    test('uses the registered exception messages when available', () async {
      GetIt.instance.registerSingleton<ExceptionMessage>(
        const DefaultEnglishExceptionMessage(),
        instanceName: 'exception_messages',
      );
      addTearDown(
        () => GetIt.instance.unregister<ExceptionMessage>(
          instanceName: 'exception_messages',
        ),
      );

      final list = await NetworkStreamResult.success(
        _failingNumbers(),
      ).toList();
      expect(
        list.error!.errorMessage,
        const DefaultEnglishExceptionMessage().unexpectedError,
      );
    });

    test('an error result is returned unchanged', () async {
      const failure = NetworkStreamResult<int>.error(_error);
      expect((await failure.toList()).error, _error);
    });
  });
}
