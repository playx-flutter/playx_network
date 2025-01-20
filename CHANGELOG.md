# Changelog

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