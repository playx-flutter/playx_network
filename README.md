# Playx Network

[![pub package](https://img.shields.io/pub/v/playx_network.svg?color=1284C5)](https://pub.dev/packages/playx_network)
[![CI](https://github.com/playx-flutter/playx_network/actions/workflows/ci.yml/badge.svg)](https://github.com/playx-flutter/playx_network/actions/workflows/ci.yml)
[![pub points](https://img.shields.io/pub/points/playx_network?color=1284C5)](https://pub.dev/packages/playx_network/score)
[![documentation](https://img.shields.io/badge/docs-playx--flutter.github.io-1284C5)](https://playx-flutter.github.io/playx_network/)

A [Dio](https://pub.dev/packages/dio) wrapper that turns every request into a typed result, gives errors names you can act on, and removes the try/catch.

**[Read the documentation](https://playx-flutter.github.io/playx_network/)** · [API reference](https://playx-flutter.github.io/playx_network/api/) · [Changelog](CHANGELOG.md)

## Features

- **A result, never an exception.** Every request returns a `NetworkResult`: success with your model, or an error with a typed exception.
- **Errors you can act on.** Offline, server unreachable, CORS, bad certificate, timeouts, `404`, `422`... each has its own exception and message, ready to show to users.
- **Your models and your errors.** `fromJson` for the data, `errorMapper` for the message and `errorExtraMapper` for your own error object.
- **Parsing off the UI thread.** Map large responses in an isolate, and cancel the work with the request.
- **Streaming and SSE.** Consume Server-Sent Events, NDJSON and chunked responses as typed streams.
- **Smart cancellation.** Cancel by token or by tag, or let a new request replace the old one.
- **Conveniences.** Path parameters, `dataKey` extraction, custom headers and query, per-request settings, downloads.
- **Pretty logs.** Request, response and error logging through [Talker](https://pub.dev/packages/talker_dio_logger), with hidden headers and filters.
- **Works with any `Dio`.** Bring your own instance, interceptors and adapter. Easy to test with a fake adapter.

## Install

```bash
flutter pub add playx_network
```

Requires **Dart 3.12** and **Flutter 3.44** or newer.

## Quick start

Create one client and reuse it:

```dart
import 'package:playx_network/playx_network.dart';

final client = PlayxNetworkClient(
  dio: Dio(BaseOptions(baseUrl: 'https://api.thecatapi.com/v1/')),
  // Attached to every request, for example an auth token.
  customHeaders: () async => {'authorization': 'Bearer $token'},
);
```

Describe your data with a `fromJson`, make a request, and handle the result:

```dart
class Cat {
  Cat({this.id, this.url});

  factory Cat.fromJson(dynamic json) =>
      Cat(id: json['id'] as String?, url: json['url'] as String?);

  final String? id;
  final String? url;
}

final result = await client.getList<Cat>(
  'images/search',
  query: {'limit': 10},
  fromJson: Cat.fromJson,
);

result.when(
  success: (cats) => print('Got ${cats.length} cats'),
  error: (error) => print('Failed: ${error.message}'),
);
```

Or pattern match, and tell failures apart:

```dart
switch (result) {
  case NetworkSuccess(:final data):
    showCats(data);
  case NetworkError(:final error):
    final text = switch (error) {
      NoInternetConnectionException() => 'You are offline',
      ServerUnreachableException() => 'The server is not responding',
      UnauthorizedRequestException() => 'Please sign in again',
      ApiException(:final message) => message,
      _ => 'Something went wrong',
    };
    showMessage(text);
}
```

## Requests

| Method | Sends | Returns |
|--------|-------|---------|
| `get<T>` / `getList<T>` | `GET` | `NetworkResult<T>` / `NetworkResult<List<T>>` |
| `post<T>` / `postList<T>` | `POST` | `NetworkResult<T>` / `NetworkResult<List<T>>` |
| `put<T>` / `putList<T>` | `PUT` | `NetworkResult<T>` / `NetworkResult<List<T>>` |
| `patch<T>` / `patchList<T>` | `PATCH` | `NetworkResult<T>` / `NetworkResult<List<T>>` |
| `delete<T>` / `deleteList<T>` | `DELETE` | `NetworkResult<T>` / `NetworkResult<List<T>>` |
| `download` | `GET` | `NetworkResult<Response>` |
| `getStream<T>` / `postStream<T>` | `GET` / `POST` | `NetworkStreamResult<T>` |
| `getSse` / `postSse` | `GET` / `POST` | `NetworkStreamResult<PlayxSseEvent>` |

A few things that make requests shorter:

```dart
// Path parameters, URL-encoded for you.
await client.get<Post>('users/{userId}/posts/{postId}',
    pathParameters: {'userId': 42, 'postId': 7}, fromJson: Post.fromJson);

// Read nested data out of an envelope.
await client.get<User>('me', dataKey: 'payload.user', fromJson: User.fromJson);

// Cancel the previous search when the user keeps typing.
await client.getList<Product>('search',
    query: {'q': query}, cancelTag: 'search', fromJson: Product.fromJson);

// A DELETE with no body needs no mapper.
await client.delete<void>('posts/{id}', pathParameters: {'id': 7});
```

## Documentation

The [documentation site](https://playx-flutter.github.io/playx_network/) covers everything in depth:

| | |
|---|---|
| [Getting started](https://playx-flutter.github.io/playx_network/getting-started/) | Install, create the client, make a request. |
| [Making requests](https://playx-flutter.github.io/playx_network/guides/requests/) | All methods, path parameters, `dataKey`, downloads, per-request overrides. |
| [Handling results](https://playx-flutter.github.io/playx_network/guides/results/) | `when`, `map`, pattern matching, isolate mapping. |
| [Error handling](https://playx-flutter.github.io/playx_network/guides/errors/) | Every exception, custom error objects, empty responses, `204`. |
| [Connection failures](https://playx-flutter.github.io/playx_network/guides/connection-failures/) | Offline vs server down vs CORS vs TLS. |
| [Streaming and SSE](https://playx-flutter.github.io/playx_network/guides/streaming/) | Server-Sent Events, NDJSON, lifecycle. |
| [Cancellation](https://playx-flutter.github.io/playx_network/guides/cancellation/) | Tokens, tags and search-as-you-type. |
| [Logging](https://playx-flutter.github.io/playx_network/guides/logging/) | Settings, filters and hidden headers. |
| [Testing](https://playx-flutter.github.io/playx_network/guides/testing/) | A fake adapter for fast, offline tests. |
| [Configuration](https://playx-flutter.github.io/playx_network/configuration/) | Every client parameter and setting. |

## Example

A runnable app lives in [`example/`](example). It performs requests against public APIs and shows the results and errors.

## Contributing

Issues and pull requests are welcome at [github.com/playx-flutter/playx_network](https://github.com/playx-flutter/playx_network). Before sending a change, run:

```bash
dart format .
flutter analyze lib test
flutter test --coverage
```

The documentation lives in [`docs/`](docs) and is built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/): `pip install -r docs/requirements.txt && mkdocs serve`.

## See also

- [Playx](https://pub.dev/packages/playx): the Playx ecosystem, less code and more productivity.
- [playx_core](https://pub.dev/packages/playx_core): the shared classes and utilities this package builds on.
- [playx_theme](https://pub.dev/packages/playx_theme): multi-theme support for Flutter apps.

## License

MIT, see [LICENSE](LICENSE).
