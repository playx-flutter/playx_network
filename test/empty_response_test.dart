import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';

/// Short-circuits every request with a fixed [data] payload and status code.
class _FixedResponseInterceptor extends Interceptor {
  _FixedResponseInterceptor(this.data, {this.statusCode = 200});

  final dynamic data;
  final int statusCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: statusCode,
        data: data,
      ),
    );
  }
}

PlayxNetworkClient _client(
  dynamic data, {
  bool treatEmptyResponseAsSuccess = false,
  int statusCode = 200,
  List<int> successRequestCodes = const [200, 201],
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.com/'))
    ..interceptors.add(_FixedResponseInterceptor(data, statusCode: statusCode));
  return PlayxNetworkClient(
    dio: dio,
    settings: PlayxNetworkClientSettings(
      useIsolateForMappingJson: false,
      useWorkMangerForMappingJsonInIsolate: false,
      treatEmptyResponseAsSuccess: treatEmptyResponseAsSuccess,
      successRequestCodes: successRequestCodes,
    ),
  );
}

String _fromJson(dynamic json) => json.toString();

void main() {
  group('treatEmptyResponseAsSuccess (lists)', () {
    test(
      'defaults to false and keeps returning EmptyResponseException',
      () async {
        expect(
          const PlayxNetworkClientSettings().treatEmptyResponseAsSuccess,
          isFalse,
        );
        final result = await _client(
          <dynamic>[],
        ).getList<String>('items', fromJson: _fromJson);
        expect(result.isError, isTrue);
        expect(result.error, isA<EmptyResponseException>());
      },
    );

    test(
      'empty list [] returns a successful empty list when enabled',
      () async {
        final result = await _client(
          <dynamic>[],
          treatEmptyResponseAsSuccess: true,
        ).getList<String>('items', fromJson: _fromJson);
        expect(result.isSuccess, isTrue);
        expect(result.data, isEmpty);
      },
    );

    test(
      'empty string body returns a successful empty list when enabled',
      () async {
        final result = await _client(
          '',
          treatEmptyResponseAsSuccess: true,
        ).getList<String>('items', fromJson: _fromJson);
        expect(result.isSuccess, isTrue);
        expect(result.data, isEmpty);
      },
    );

    test('null body returns a successful empty list when enabled', () async {
      final result = await _client(
        null,
        treatEmptyResponseAsSuccess: true,
      ).getList<String>('items', fromJson: _fromJson);
      expect(result.isSuccess, isTrue);
      expect(result.data, isEmpty);
    });

    test('empty body is still an error when disabled', () async {
      final result = await _client(
        '',
      ).getList<String>('items', fromJson: _fromJson);
      expect(result.error, isA<EmptyResponseException>());
    });

    test('empty list under dataKey returns a successful empty list', () async {
      final result = await _client(
        {'data': <dynamic>[]},
        treatEmptyResponseAsSuccess: true,
      ).getList<String>('items', fromJson: _fromJson, dataKey: 'data');
      expect(result.isSuccess, isTrue);
      expect(result.data, isEmpty);
    });

    test('non-empty lists are unaffected', () async {
      final result = await _client(
        [1, 2],
        treatEmptyResponseAsSuccess: true,
      ).getList<String>('items', fromJson: _fromJson);
      expect(result.data, ['1', '2']);
    });

    test('works for postList too', () async {
      final result = await _client(
        <dynamic>[],
        treatEmptyResponseAsSuccess: true,
      ).postList<String>('items', fromJson: _fromJson);
      expect(result.isSuccess, isTrue);
      expect(result.data, isEmpty);
    });

    test('per-request settings can enable it on a default client', () async {
      final result = await _client(<dynamic>[]).getList<String>(
        'items',
        fromJson: _fromJson,
        settings: const PlayxNetworkClientSettings(
          useIsolateForMappingJson: false,
          useWorkMangerForMappingJsonInIsolate: false,
          treatEmptyResponseAsSuccess: true,
        ),
      );
      expect(result.isSuccess, isTrue);
      expect(result.data, isEmpty);
    });

    test('per-request settings can disable it on an enabled client', () async {
      final result =
          await _client(
            <dynamic>[],
            treatEmptyResponseAsSuccess: true,
          ).getList<String>(
            'items',
            fromJson: _fromJson,
            settings: const PlayxNetworkClientSettings(
              useIsolateForMappingJson: false,
              useWorkMangerForMappingJsonInIsolate: false,
            ),
          );
      expect(result.error, isA<EmptyResponseException>());
    });

    test('copyWith carries the flag', () {
      const base = PlayxNetworkClientSettings();
      expect(
        base
            .copyWith(treatEmptyResponseAsSuccess: true)
            .treatEmptyResponseAsSuccess,
        isTrue,
      );
      expect(
        base
            .copyWith(treatEmptyResponseAsSuccess: true)
            .copyWith()
            .treatEmptyResponseAsSuccess,
        isTrue,
      );
    });

    test('error status codes are still errors', () async {
      final result = await _client(
        <dynamic>[],
        treatEmptyResponseAsSuccess: true,
        statusCode: 500,
      ).getList<String>('items', fromJson: _fromJson);
      expect(result.isError, isTrue);
      expect(result.error, isNot(isA<EmptyResponseException>()));
    });
  });

  group('treatEmptyResponseAsSuccess (single objects)', () {
    test('does not affect single-object requests', () async {
      final result = await _client(
        '',
        treatEmptyResponseAsSuccess: true,
      ).get<String>('item', fromJson: _fromJson);
      expect(result.isError, isTrue);
      expect(result.error, isA<EmptyResponseException>());
    });
  });

  group('delete without body', () {
    test('fromJson is optional: empty 200 body is a success', () async {
      final result = await _client('').delete<void>('items/1');
      expect(result.isSuccess, isTrue);
    });

    test('fromJson is optional: untyped call succeeds with null', () async {
      final result = await _client(null).delete('items/1');
      expect(result.isSuccess, isTrue);
      expect(result.data, isNull);
    });

    test('without fromJson a body is ignored and still a success', () async {
      final result = await _client({'deleted': true}).delete<void>('items/1');
      expect(result.isSuccess, isTrue);
    });

    test('nullable T works without fromJson', () async {
      final result = await _client('').delete<String?>('items/1');
      expect(result.isSuccess, isTrue);
      expect(result.data, isNull);
    });

    test('non-nullable T without fromJson reports UnableToProcess', () async {
      final result = await _client('').delete<String>('items/1');
      expect(result.isError, isTrue);
      expect(result.error, isA<UnableToProcessException>());
    });

    test('with fromJson and an empty body the mapper gets null', () async {
      Object? received = 'unset';
      final result = await _client('').delete<String>(
        'items/1',
        fromJson: (json) {
          received = json;
          return 'deleted';
        },
      );
      expect(received, isNull);
      expect(result.isSuccess, isTrue);
      expect(result.data, 'deleted');
    });

    test(
      'dataKey is skipped on an empty body and the mapper gets null',
      () async {
        Object? received = 'unset';
        final result = await _client(null).delete<String>(
          'items/1',
          dataKey: 'data',
          fromJson: (json) {
            received = json;
            return 'ok';
          },
        );
        expect(received, isNull);
        expect(result.data, 'ok');
      },
    );

    test('a mapper that cannot handle null reports UnableToProcess', () async {
      final result = await _client('').delete<String>(
        'items/1',
        fromJson: (json) => (json as Map)['id'].toString(),
      );
      expect(result.error, isA<UnableToProcessException>());
    });

    test('with fromJson and a body it maps normally', () async {
      final result = await _client({'id': 5}).delete<String>(
        'items/1',
        fromJson: (json) => (json as Map)['id'].toString(),
      );
      expect(result.data, '5');
    });

    test('204 is an error with the default success codes', () async {
      final result = await _client('', statusCode: 204).delete<void>('items/1');
      expect(result.isError, isTrue);
    });

    test('204 is a success when added to successRequestCodes', () async {
      final result = await _client(
        '',
        statusCode: 204,
        successRequestCodes: const [200, 201, 204],
      ).delete<void>('items/1');
      expect(result.isSuccess, isTrue);
    });

    test('error status codes are still errors', () async {
      final result = await _client('', statusCode: 500).delete<void>('x');
      expect(result.isError, isTrue);
    });

    test('get is unchanged: an empty body is still an error', () async {
      final result = await _client(
        '',
      ).get<String>('items/1', fromJson: _fromJson);
      expect(result.error, isA<EmptyResponseException>());
    });
  });
}
