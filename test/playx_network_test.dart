import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:playx_network/playx_network.dart';
import 'package:playx_network/src/utils/path_utils.dart';

/// A minimal Dio interceptor that short-circuits every request and records the
/// final `requestOptions.path` so tests can assert path-parameter substitution
/// without performing real network I/O.
class _PathCapturingInterceptor extends Interceptor {
  String? lastPath;
  Map<String, dynamic>? lastQueryParameters;
  String? lastMethod;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    lastPath = options.path;
    lastQueryParameters = options.queryParameters;
    lastMethod = options.method;
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        // Return a JSON list so both single-item mappers (`fromJson: (j) => j`)
        // and list-returning handlers (`getList`, `postList`, ...) succeed.
        data: <Map<String, dynamic>>[
          <String, dynamic>{'ok': true},
        ],
      ),
    );
  }
}

/// Builds a [PlayxNetworkClient] backed by a Dio instance wired to a
/// [_PathCapturingInterceptor]. The interceptor is returned so the test can
/// inspect the dispatched path.
({PlayxNetworkClient client, _PathCapturingInterceptor interceptor})
    _createClient({
  FutureOr<Map<String, dynamic>> Function()? customPathParameters,
  String baseUrl = 'https://example.com/api/',
}) {
  final interceptor = _PathCapturingInterceptor();
  final dio = Dio(BaseOptions(baseUrl: baseUrl))..interceptors.add(interceptor);
  final client = PlayxNetworkClient(
    dio: dio,
    customPathParameters: customPathParameters,
    settings: const PlayxNetworkClientSettings(
      useIsolateForMappingJson: false,
      useWorkMangerForMappingJsonInIsolate: false,
    ),
  );
  return (client: client, interceptor: interceptor);
}

void main() {
  group('substitutePathParameters', () {
    test('returns path unchanged when parameters map is empty', () {
      expect(
        substitutePathParameters('users/42/posts', const {}),
        'users/42/posts',
      );
    });

    test('substitutes a single placeholder', () {
      expect(
        substitutePathParameters('users/{userId}', const {'userId': 42}),
        'users/42',
      );
    });

    test('substitutes multiple placeholders', () {
      expect(
        substitutePathParameters(
          'users/{userId}/posts/{postId}',
          const {'userId': 42, 'postId': 7},
        ),
        'users/42/posts/7',
      );
    });

    test('stringifies numeric and boolean values', () {
      expect(
        substitutePathParameters(
          'items/{id}/active/{flag}',
          const {'id': 3.14, 'flag': true},
        ),
        'items/3.14/active/true',
      );
    });

    test('leaves unknown placeholders untouched', () {
      expect(
        substitutePathParameters('users/{userId}', const {'other': 1}),
        'users/{userId}',
      );
    });

    test('skips null values but replaces non-null ones', () {
      expect(
        substitutePathParameters(
          'a/{x}/b/{y}',
          const {'x': null, 'y': 5},
        ),
        'a/{x}/b/5',
      );
    });

    test('URL-encodes special characters with %20 for spaces', () {
      expect(
        substitutePathParameters(
          'search/{query}',
          const {'query': 'hello world'},
        ),
        'search/hello%20world',
      );
    });

    test('URL-encodes slashes within a segment', () {
      expect(
        substitutePathParameters(
          'files/{name}',
          const {'name': 'a/b'},
        ),
        'files/a%2Fb',
      );
    });

    test('replaces repeated occurrences of the same placeholder', () {
      expect(
        substitutePathParameters('{x}/{x}', const {'x': 1}),
        '1/1',
      );
    });
  });

  group('DioClient pathParameters', () {
    test('get substitutes path parameters before dispatch', () async {
      final interceptor = _PathCapturingInterceptor();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
        ..interceptors.add(interceptor);
      final dioClient = DioClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          useIsolateForMappingJson: false,
          useWorkMangerForMappingJsonInIsolate: false,
        ),
      );

      await dioClient.get(
        'users/{userId}/posts/{postId}',
        pathParameters: const {'userId': 42, 'postId': 7},
      );

      expect(interceptor.lastPath, 'users/42/posts/7');
      expect(interceptor.lastMethod, 'GET');
    });

    test('post substitutes path parameters before dispatch', () async {
      final interceptor = _PathCapturingInterceptor();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
        ..interceptors.add(interceptor);
      final dioClient = DioClient(
        dio: dio,
        settings: const PlayxNetworkClientSettings(
          useIsolateForMappingJson: false,
          useWorkMangerForMappingJsonInIsolate: false,
        ),
      );

      await dioClient.post(
        'users/{userId}',
        pathParameters: const {'userId': 5},
        body: const {'name': 'Omar'},
      );

      expect(interceptor.lastPath, 'users/5');
      expect(interceptor.lastMethod, 'POST');
    });

    test('customPathParameters are merged into the path', () async {
      final interceptor = _PathCapturingInterceptor();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
        ..interceptors.add(interceptor);
      final dioClient = DioClient(
        dio: dio,
        customPathParameters: () async => {'version': 'v2'},
        settings: const PlayxNetworkClientSettings(
          useIsolateForMappingJson: false,
          useWorkMangerForMappingJsonInIsolate: false,
        ),
      );

      await dioClient.get(
        '{version}/users/{userId}',
        pathParameters: const {'userId': 9},
      );

      expect(interceptor.lastPath, 'v2/users/9');
    });

    test(
        'attachCustomPathParameters=false skips custom path parameters',
        () async {
      final interceptor = _PathCapturingInterceptor();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
        ..interceptors.add(interceptor);
      final dioClient = DioClient(
        dio: dio,
        customPathParameters: () async => {'version': 'v2'},
        settings: const PlayxNetworkClientSettings(
          useIsolateForMappingJson: false,
          useWorkMangerForMappingJsonInIsolate: false,
        ),
      );

      await dioClient.get(
        '{version}/users',
        pathParameters: const {},
        attachCustomPathParameters: false,
      );

      // custom path parameters skipped -> token stays unresolved
      expect(interceptor.lastPath, '{version}/users');
    });

    test('per-request path parameters override custom path parameters',
        () async {
      final interceptor = _PathCapturingInterceptor();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'))
        ..interceptors.add(interceptor);
      final dioClient = DioClient(
        dio: dio,
        customPathParameters: () async => {'userId': 'default'},
        settings: const PlayxNetworkClientSettings(
          useIsolateForMappingJson: false,
          useWorkMangerForMappingJsonInIsolate: false,
        ),
      );

      await dioClient.get(
        'users/{userId}',
        pathParameters: const {'userId': 42},
      );

      expect(interceptor.lastPath, 'users/42');
    });
  });

  group('PlayxNetworkClient pathParameters', () {
    test('get substitutes path parameters and returns success', () async {
      final (:client, :interceptor) = _createClient();

      final result = await client.get(
        'users/{userId}/posts/{postId}',
        pathParameters: const {'userId': 42, 'postId': 7},
        fromJson: (json) => json,
      );

      expect(interceptor.lastPath, 'users/42/posts/7');
      expect(result.isSuccess, isTrue);
    });

    test('getList substitutes path parameters and returns success', () async {
      final (:client, :interceptor) = _createClient();

      final result = await client.getList(
        'users/{userId}/posts',
        pathParameters: const {'userId': 1},
        fromJson: (json) => json,
      );

      expect(interceptor.lastPath, 'users/1/posts');
      expect(result.isSuccess, isTrue);
    });

    test('post substitutes path parameters', () async {
      final (:client, :interceptor) = _createClient();

      await client.post(
        'users/{userId}',
        pathParameters: const {'userId': 5},
        body: const {'name': 'Omar'},
        fromJson: (json) => json,
      );

      expect(interceptor.lastPath, 'users/5');
      expect(interceptor.lastMethod, 'POST');
    });

    test('postList substitutes path parameters', () async {
      final (:client, :interceptor) = _createClient();

      await client.postList(
        'groups/{groupId}/members',
        pathParameters: const {'groupId': 'abc'},
        body: const {},
        fromJson: (json) => json,
      );

      expect(interceptor.lastPath, 'groups/abc/members');
    });

    test('put substitutes path parameters', () async {
      final (:client, :interceptor) = _createClient();

      await client.put(
        'users/{userId}',
        pathParameters: const {'userId': 8},
        body: const {'name': 'Updated'},
        fromJson: (json) => json,
      );

      expect(interceptor.lastPath, 'users/8');
      expect(interceptor.lastMethod, 'PUT');
    });

    test('putList substitutes path parameters', () async {
      final (:client, :interceptor) = _createClient();

      await client.putList(
        'users/{userId}/roles',
        pathParameters: const {'userId': 8},
        body: const {},
        fromJson: (json) => json,
      );

      expect(interceptor.lastPath, 'users/8/roles');
    });

    test('delete substitutes path parameters', () async {
      final (:client, :interceptor) = _createClient();

      await client.delete(
        'users/{userId}',
        pathParameters: const {'userId': 3},
        fromJson: (json) => json,
      );

      expect(interceptor.lastPath, 'users/3');
      expect(interceptor.lastMethod, 'DELETE');
    });

    test('deleteList substitutes path parameters', () async {
      final (:client, :interceptor) = _createClient();

      await client.deleteList(
        'users/{userId}/sessions',
        pathParameters: const {'userId': 3},
        fromJson: (json) => json,
      );

      expect(interceptor.lastPath, 'users/3/sessions');
    });

    test('patch substitutes path parameters', () async {
      final (:client, :interceptor) = _createClient();

      await client.patch(
        'users/{userId}',
        pathParameters: const {'userId': 11},
        body: const {'name': 'Patched'},
        fromJson: (json) => json,
      );

      expect(interceptor.lastPath, 'users/11');
      expect(interceptor.lastMethod, 'PATCH');
    });

    test('patchList substitutes path parameters', () async {
      final (:client, :interceptor) = _createClient();

      await client.patchList(
        'users/{userId}/prefs',
        pathParameters: const {'userId': 11},
        body: const {},
        fromJson: (json) => json,
      );

      expect(interceptor.lastPath, 'users/11/prefs');
    });

    test('download substitutes path parameters', () async {
      final (:client, :interceptor) = _createClient();

      // download resolves to a 200 with no body; the handler still returns a
      // NetworkResult, so we only assert the dispatched path here.
      await client.download(
        'files/{fileId}',
        savePath: '/tmp/test-download',
        pathParameters: const {'fileId': 'doc-1'},
      );

      expect(interceptor.lastPath, 'files/doc-1');
      expect(interceptor.lastMethod, 'GET');
    });

    test(
        'backward-compat: path without placeholders is sent unchanged when '
        'pathParameters is omitted', () async {
      final (:client, :interceptor) = _createClient();

      await client.get(
        'users/42/posts',
        fromJson: (json) => json,
      );

      expect(interceptor.lastPath, 'users/42/posts');
    });

    test('customPathParameters from client are applied to every request',
        () async {
      final (:client, :interceptor) = _createClient(
        customPathParameters: () async => {'version': 'v2'},
      );

      await client.get(
        '{version}/users/{userId}',
        pathParameters: const {'userId': 1},
        fromJson: (json) => json,
      );

      expect(interceptor.lastPath, 'v2/users/1');
    });

    test(
        'attachCustomPathParameters=false on the client skips custom path '
        'parameters', () async {
      final (:client, :interceptor) = _createClient(
        customPathParameters: () async => {'version': 'v2'},
      );

      await client.get(
        '{version}/users/{userId}',
        pathParameters: const {'userId': 1},
        attachCustomPathParameters: false,
        fromJson: (json) => json,
      );

      // custom skipped, only per-request param substituted
      expect(interceptor.lastPath, '{version}/users/1');
    });
  });
}
