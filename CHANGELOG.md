# Changelog

## 2.0.0

A major release: it raises the minimum Dart and Flutter versions and adds new exception types (see the breaking changes below). It brings streaming, path parameters, custom error objects, a finer-grained set of connection errors, and many fixes to error handling. There is also a new [documentation site](https://playx-flutter.github.io/playx_network/).

### Breaking changes

- **Minimum versions**: `playx_core ^2.0.0` requires Dart `>=3.12.0` and Flutter `>=3.44.0`, so these are now the minimum versions of `playx_network` too.
- **New exception types**: `NetworkException` is a sealed class, so an exhaustive `switch` over it must handle the new subclasses `ServerUnreachableException`, `CorsException`, `SecureConnectionException` and `ReceiveTimeoutException` (or keep a catch-all case).
- **Slow responses**: Dio's `receiveTimeout` is now a `ReceiveTimeoutException` instead of a `SendTimeoutException`. Code that caught `SendTimeoutException` for slow responses should also catch `ReceiveTimeoutException`.

### New features

#### Streaming and SSE

- `getStream` and `postStream` consume streaming endpoints (SSE, NDJSON, chunked text and binary) through the new sealed `NetworkStreamResult`, which has `when`, `map`, `mapAsync`, `mapStream`, `mapStreamAsync` and `toList()`.
- `getSse` and `postSse` are conveniences for Server-Sent Events, with the `PlayxSseEvent` model. They send `Accept: text/event-stream`.
- `PlayxStreamFormat` selects how bytes are decoded: `bytes`, `text`, `json` (one JSON document per line, NDJSON) or `sse`.
- Decoding uses a streaming UTF-8 decoder, so multibyte characters split across chunks are reassembled. The SSE parser follows the specification: CR, LF and CRLF line endings, a leading BOM, a persistent last event id, and no events from partial lines or data-less blocks.
- The stream follows its listener: pause and resume are honoured, and cancelling the subscription, cancelling the token, or a source error aborts the HTTP request. A stream always completes after a terminal error. Error response bodies are read (up to 64 KB) so the error mapper receives the server's message.
- `toList()` returns a `NetworkResult.error` if the stream errors. It never completes for endless streams.
- Streams support path parameters, and merge `options.headers` instead of replacing them. The idle receive timeout is disabled unless `options.receiveTimeout` is set.

#### Path parameters

- `pathParameters` substitutes `{placeholder}` segments in the path of every request (for example `'users/{userId}'` with `{'userId': 42}`). Values are URL-encoded.
- `customPathParameters` on `PlayxNetworkClient` (and `attachCustomPathParameters` per request) supplies app-wide values, like `customQuery` does for query parameters.

#### Custom error objects

- `errorExtraMapper` (client-level and per request) maps an error response to your own object, exposed as `ApiException.extra`. Read it with `result.errorExtraAs<E>()` or `exception.extraAs<E>()`, no cast needed. `ErrorMapper` is unchanged.

#### Empty responses

- `treatEmptyResponseAsSuccess` (default `false`) returns `NetworkResult.success([])` for list requests that succeed with an empty body or an empty list, instead of an `EmptyResponseException`.
- `fromJson` is optional on `delete`. Without it any successful response is `NetworkResult.success(null)` (use `delete<void>`), and with it an empty body is a success and the mapper receives `null`.
- Documented that `204 No Content` needs `successRequestCodes: [200, 201, 204]`. The default is unchanged.

#### Connection failures

- `ServerUnreachableException` (connection refused, reset, closed or timed out, no route to host) and, on the web, `CorsException`, so not every failed connection is reported as `NoInternetConnectionException`. The exception is chosen from the OS error. A failure that can't be identified stays `NoInternetConnectionException`.
- The optional `hasInternetConnection` callback on `PlayxNetworkClient` (for example backed by `connectivity_plus`) tells offline from unreachable reliably. It is only called after a connection failure.
- `SecureConnectionException` for rejected certificates and failed TLS handshakes (Dio reports a handshake failure as `unknown` or `connectionError`). The connectivity callback is not called for them.
- New `ExceptionMessage` getters `serverUnreachable`, `corsError`, `secureConnectionError` and `receiveTimeout`. They have defaults (`defaultError`, and `sendTimeout` for `receiveTimeout`), so existing subclasses keep compiling. English and Arabic provide their own.

### Changes

- A response body that cannot be parsed (for example invalid JSON) is reported as `InvalidFormatException`. It was an `UnexpectedErrorException`, and the `InvalidFormatException` branch could never be reached.
- Dio's `transformTimeout` (parsing took too long) is an `UnableToProcessException`.
- Requests made with a Dio that keeps the default `validateStatus` are handled consistently: error responses of stream requests keep the API message and `extra` data, and a status listed in `successRequestCodes` that Dio rejects (for example `304`) is a success for every request type.

### Bug fixes

- **Cancellation**: cancelling a request exactly while its response was being mapped could throw an uncaught `Bad state: Future already completed`. The race is handled and the request returns a `RequestCanceledException`. Downloads also no longer let non-`Exception` errors (such as a `StateError`) escape.
- **Default error parsing**: `DefaultApiError` reads Strapi's `message: [{messages: [...]}]` (that branch could never run), joins list messages such as `message: ["a", "b"]`, supports `{"error": "..."}`, and reads each field on its own so a wrongly typed `statusCode` no longer discards the message. Blank messages are treated as missing.
- **Per-request settings**: custom `exceptionMessages`, `shouldShowApiErrors` and `unauthorizedRequestCodes` passed in a request's `settings` now apply to error status codes of every request type, including errors Dio throws as `badResponse`. Only the client-level settings were used before.
- Copying a `Dio` for per-request log settings no longer duplicates Dio's default interceptor.
- Fixed the non-exhaustive switch over `DioExceptionType` by handling `transformTimeout`, introduced in Dio 5.10.

### Dependencies

- `playx_core ^2.0.0`, `dio ^5.11.1`.
- Widened ranges so apps can pick their versions: `sentry_dio >=9.16.0 <11.0.0`, `talker` and `talker_dio_logger` `>=5.1.16 <6.0.0`, `dio_web_adapter >=2.1.2 <3.0.0`. `sentry_dio` is only re-exported; apps that move to `sentry_dio` 10 should read its migration notes (Android `minSdk` 26, Swift Package Manager on Apple platforms, span streaming on by default).
- `package:web` is now a direct dependency.

### Documentation and tooling

- A documentation site with guides and the API reference, published to GitHub Pages.
- A rewritten README.
- CI runs format, analysis and tests with a 90% coverage gate on every pull request, validates the package with a publish dry run, and publishing skips versions that are already on pub.dev.

## 1.0.0
- **Nested JSON Key Extraction**: Added `dataKey` parameter to all network requests to extract nested JSON values before parsing.
- **Item-Level Nested Key Extraction**: Added `itemDataKey` to all list-returning requests (`getList`, `postList`, etc.) to unwrap each list item (e.g., `itemDataKey: 'attributes'`) before passing it to the mapper.
- **Smart Request Cancellation Manager**: Added `cancelTag` parameter to manage and cancel multiple requests at once with automatic `cancelOld` support.
- **Mapping Cancellation**: Better support for canceling requests during JSON mapping in isolates. Now, when a request is canceled, the mapping process is also canceled to save resources and improve performance.

## 0.6.0
- Updated dependencies to their latest versions.
- PATCH Request Support: Added new methods (patch and patchList) to easily perform PATCH API requests.
- Per-Request Error Mapping: You can now pass a custom ErrorMapper to individual API calls for more specific error handling.
- Granular Logging Control: Added new settings to control exactly what gets printed in the logs (e.g., toggle response data, request headers, etc.).
- Added dio_smart_retry package to support retrying failed requests with exponential backoff.


## 0.5.1
- Updated dependencies to their latest versions.
- Enhanced logging errors and exceptions to provide more detailed information.

## 0.5.0

> Note: This version contains breaking changes.

###  New Features

* **Export `DioClient`**: A simple and customizable HTTP client based on Dio is now available directly from the `playx_network` package.

###   Improvements

#### Logger Overhaul

* Replaced `pretty_dio_logger` with `talker_dio_logger` for better log control and Talker integration.
* Updated `PlayxNetworkLoggerSettings` to support detailed logging configuration.
* Integrated `PlayxLogger` for consistent logging across the Playx ecosystem.

### Other
- Updated dependencies to their latest versions.
- Bump minimum Dart SDK version to 3.5.0 and Flutter SDK version to 3.24.0.
- Migrated Android example project to Kotlin DSL.


## 0.4.0
> Note: This version contains breaking changes.

## Breaking Changes
- NetworkResult<T> now includes data and error fields for easier access instead of `networkData` and `networkError` getters.
- Renamed FormatException → InvalidFormatException to avoid conflict with Dart’s built-in FormatException.

## New Features && Enhancements
- Update dio to v5.8.0+1
- Support FileAccessMode in Dio.download to change download file opening mode.

### NetworkResult
- New `mapDataAsyncOrNull` Method which maps the success data to another type asynchronously, With option to map the error case or return null.
- `when` method now returns the value instead of void.

### NetworkException
- NetworkException now extends Exception for better error handling.
- All exception classes now follow a streamlined format with default values for status codes.



## 0.3.1 - 0.3.2
- fix: bug when initializing PlayxNetworkClient.


## 0.3.0

- **Mapping Enhancements**:
  - Enhanced mapping of Dio responses with support for processing in an isolate using the `work_manager` package or the `compute` method.
  - Added parameters for mapping options in `PlayxNetworkClientSettings`:
    - `useIsolateForMappingJson`: Determines whether to use an isolate for mapping JSON responses.
    - `useWorkManagerForMappingJsonInIsolate`: Specifies whether to use `work_manager` or the `compute` function for JSON mapping in an isolate.
  - Added the ability to override `PlayxNetworkClientSettings` for individual requests, similar to overriding `logSettings` or `exceptionMessages`.

- **NetworkResult Enhancements**:
  - Added the following convenience getters to the `NetworkResult` class:
    - `isSuccess`: Checks if the network call is successful.
    - `isError`: Checks if the network call has failed.
    - `networkData`: Returns the data if the call is successful, otherwise returns `null`.
    - `networkError`: Returns the error if the call has failed.

- **Asynchronous Mapping**:
  - Introduced new mapping methods for `NetworkResult`:
    - `mapDataAsync`: Maps a network response (success or error) to a desired model asynchronously.
    - `mapDataAsyncInIsolate`: Maps a network response asynchronously in an isolate, with configurable options:
      - `mapper`: The function for transforming data.
      - `exceptionMessage`: A message to display in case of exceptions.
      - `useWorkManager`: Determines whether to use `work_manager` or `compute` for JSON mapping.
    - `mapAsyncInIsolate`: Separately maps success and error cases asynchronously in an isolate, with configurable options:
      - `success`: The function for mapping successful responses.
      - `error`: The function for mapping error responses.
      - `useWorkManager`: Determines whether to use `work_manager` or `compute`.


## 0.2.3
- fix: Bug causing error not being reported successfully.
- feat: Update `sentry_dio`package to v8.11.0.

## 0.2.2
- Add ability to download content using dio `download` method.

## 0.2.0 - 0.2.1
> Note: This version contains breaking changes.

##### Breaking Changes
- **Combined `PlayxNetworkClient` Settings:**
  - Merged settings for `PlayxNetworkClient` into a new `PlayxNetworkClientSettings` class.
  - Renamed `LoggerSettings` to `PlayxNetworkLoggerSettings`.

##### New Features
- **Custom Queries Support:**
  - Added the ability to include custom queries in network requests, enhancing flexibility for API interactions.
  - Users can decide whether to use custom queries on a per-request basis by using the `attachCustomQuery` option.

##### Improvements
- **Enhanced `PlayxNetworkLoggerSettings`:**
  - Added options for attaching a logger in debug and release modes (`attachLoggerOnDebug` and `attachLoggerOnRelease`).

- **Updated Dio Package:**
  - Upgraded Dio package to v5.7.0 for improved performance and features.


## 0.1.2

##### New Features
- **Isolate-Based Data Processing:**
  - Integrated Dart's `Isolate` to handle data processing in network responses, offloading CPU-intensive tasks to separate threads, which improves app performance, particularly in scenarios involving large datasets.
- **Sentry Dio Integration:**
  - Added the Sentry Dio package to automatically capture and report errors in network requests to Sentry. This integration provides better monitoring and error tracking for network-related issues.

##### Improvements
- **Updated `JsonMapper` Signature:**
  - The `JsonMapper<T>` signature has been updated from `T Function(dynamic json)` to `FutureOr<T> Function(dynamic json)` to support both synchronous and asynchronous JSON processing. This allows for more flexible and efficient handling of JSON data.

##### Bug Fixes
- Fixed an issue where `getList` and `postList` methods did not return results when the API response was not a list. Now, proper error handling ensures that non-list responses are processed correctly, preventing potential runtime errors.

## 0.1.1
- Update packages.

## 0.1.0
> Note: This version contains breaking changes.

- Update packages.
- Update `onUnauthorizedRequestReceived` callback to take `Response` instead of `void` to be able to customize unauthorized error handling based on response.
- Add `name` field for default error model.

## 0.0.9
- Update packages.
- Add unauthorizedRequestCodes to be able to handle different unauthorized request status codes returned from the api and fire onUnauthorizedRequestReceived callback.
- Add successRequestCodes to be able to handle different success request status codes returned from the api and fire onUnauthorizedRequestReceived callback.
- Enhance printing non api error messages.

## 0.0.8
- Update packages.
- Add `statusCode` to `ApiException` to be able to handle different error status codes returned from the api.

## 0.0.7
- Update packages.
- Bug fix, causing `onUnauthorizedRequestReceived` not called when receiving unauthorized request on certain cases.

## 0.0.6
- Add ability to not handle unauthorized requests on each request.
- [Breaking Change]! : Each Network Exception now takes errorMessage of type String instead of exceptionMessage

## 0.0.5
- Enhancements for default error model.

## 0.0.4
- Make `customHeaders` to be of type function that return a map to be updated correctly.

## 0.0.3
- fix some bugs causing error not being reported successfully.

## 0.0.2
- update from json to take dynamic json instead of map.

## 0.0.1
- initial release