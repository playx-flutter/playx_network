# Playx  Network
[![pub package](https://img.shields.io/pub/v/playx_network.svg?color=1284C5)](https://pub.dev/packages/playx_network)

Wrapper around [`Dio`](https://pub.dev/packages/dio) that can perform API requests with better error handling and easily get the result of any API request.

## Features
- Perform GET, POST, PUT, PATCH, and DELETE HTTP methods for retrieving from and sending data to a server.
- Better Error handling for API and [`Dio`](https://pub.dev/packages/dio) Errors with the ability to customize these errors.
- Each request is wrapped by `NetworkResult` which returns whether success or failure of the API request.
- No need to use try catch anymore as every request is handled.
- Logs network calls in a pretty, easy to read format

## Installation

In `pubspec.yaml` add these lines to `dependencies`

playx_network: ^0.7.0
```  

## Usage

We can use `PlayxNetworkClient`  to perform GET, POST, PUT, PATCH, and DELETE HTTP methods for retrieving from and sending data to a server.

To use it we need to :

- Setup `PlayxNetworkClient` an configure it based on your needs.
  You should create only one instance of this network client to be used for the app depending on your use case.
   ```dart
   final PlayxNetworkClient _client = PlayxNetworkClient(
      //you can customize your dio options like base URL, connection time out.
      dio: Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        ),
      ),
      //If you want to attach a token to the client or add any custom headers to all requests.
      customHeaders: () async => {
        'authorization': 'Bearer token'
      },
      //Function that converts json error response from api to error message.
      // You should specify how to extract error message from the response.
      // defaults to as below:
      errorMapper: (json) {
        if (json.containsKey('message')) {
          return json['message'] as String? ;
        }
        return null;
      },
    );
  ```
- Now we can use the client to perform any GET, POST, PUT, and DELETE HTTP method.

  For example we will perfrom a `GET` request that gets list of cats using this api :
  `https://api.thecatapi.com/v1/images/search?limit=10`

    - First create a model for the data returned from the api.
      It should contain a from json function that takes dynamic json and converts it to the model.
        ```dart
      class Cat {
           String? id;
           String? url;
           num? width;
           num? height;
  
          Cat({
            this.id, 
            this.url, 
            this.width, 
            this.height,});
  
            Cat.fromJson(dynamic json) {
                  id = json['id'];
                  url = json['url'];
                 width = json['width'];
                height = json['height'];
              }
  
          Map<String, dynamic> toJson() {
             final map = <String, dynamic>{};
             map['id'] = id;
             map['url'] = url;
             map['width'] = width;
             map['height'] = height;
          return map;
       }}  
      ```
    - Perform the GET request :
      ```dart
          //gets list of cats by getting cats endpoint.
          final result = await _client.getList(catsEndpoint,
          // pass your own queries.
          query: {
            'limit': '10',
          },
          // Pass the from json function that was created in the cat model.
          fromJson: Cat.fromJson);
        ```
    - Handle The request result :
       ```dart
         result.when(success: (cats) {
         //Handles success here as it returns list of cats.
         }, error: (error) {
           //handle error here and display the error message.
           print("Error is : ${error.message}");
        });
      ```

      Just like that you can perform any GET, POST, PUT, and DELETE HTTP method and return it's result whether   success or failure with better error handling.



## Available Methods :
Here is all available methods of `PlayxNetworkClient` :

| Method           | Description                                                |
| -----------      | :--------------------------------------------------------  |
| get<T>           | sends a `GET` request to the given url and returns `NetworkResult` of Type [T] model.|
| getList<T>       | sends a `GET` request to the given url and returns `NetworkResult` of List of Type [T] model.                        |
| post<T>          | sends a `POST` request to the given url and returns `NetworkResult` of Type [T] model.|
| postList<T>      | sends a `POST` request to the given url and returns `NetworkResult` of List of Type [T] model.                        |
| put<T>           | sends a `PUT` request to the given url and returns `NetworkResult` of Type [T] model.|
| putList<T>       | sends a `PUT` request to the given url and returns `NetworkResult` of List of Type [T] model.                        |
| delete<T>        | sends a `DELETE` request to the given url and returns `NetworkResult` of Type [T] model.|
| deleteList<T>    | sends a `DELETE` request to the given url and returns `NetworkResult` of List of Type [T] model.                        |
| patch<T>         | sends a `PATCH` request to the given url and returns `NetworkResult` of Type [T] model.|
| patchList<T>     | sends a `PATCH` request to the given url and returns `NetworkResult` of List of Type [T] model.                        |
| getStream<T>     | sends a `GET` request and returns `NetworkStreamResult` wrapping a `Stream` of decoded events. |
| postStream<T>    | sends a `POST` request and returns `NetworkStreamResult` wrapping a `Stream` of decoded events. |
| getSse           | sends a `GET` request and returns `NetworkStreamResult` of `PlayxSseEvent` for SSE endpoints. |
| postSse          | sends a `POST` request and returns `NetworkStreamResult` of `PlayxSseEvent` for SSE endpoints. |

## Nested JSON Key Extraction
You can extract nested JSON values directly from the response before parsing using dot-notation with the `dataKey` parameter.
This is useful when you want to target a specific field in a large JSON structure without mapping the outer layers.

```dart
final result = await _client.get(
  'forecast',
  query: {
    'latitude': '30.04',
    'longitude': '31.23',
    'current_weather': 'true',
  },
  // Extract 'current_weather' directly from the response
  dataKey: 'current_weather',
  fromJson: CurrentWeather.fromJson,
);
```

## Empty List Responses
By default, a successful list request that comes back empty (an empty body or `[]`) returns an `EmptyResponseException`.
If an empty list is a valid result for your API, enable `treatEmptyResponseAsSuccess` to get `NetworkResult.success([])` instead:

```dart
final client = PlayxNetworkClient(
  dio: Dio(BaseOptions(baseUrl: _baseUrl)),
  settings: const PlayxNetworkClientSettings(
    treatEmptyResponseAsSuccess: true,
  ),
);

// Or only for a single request:
final result = await client.getList<Post>(
  'posts',
  fromJson: Post.fromJson,
  settings: const PlayxNetworkClientSettings(treatEmptyResponseAsSuccess: true),
);
// result.data is [] when the server returns [] or an empty body.
```

This applies to list requests only (`getList`, `postList`, `putList`, `deleteList`, `patchList`). Requests that return a single object (`get`, `post`, ...) still return an `EmptyResponseException` for an empty body, because there is no empty value to return for an arbitrary model. Error status codes are not affected.

### Delete requests without a body
Many APIs answer `DELETE` with an empty `200` or `204`. For `delete`, `fromJson` is optional and an empty body is always a success:

```dart
// No mapper: any successful response is NetworkResult.success(null)
final result = await client.delete<void>('posts/{id}', pathParameters: {'id': 7});

// With a mapper: it is called with `null` when the body is empty
// (no `dataKey` extraction is attempted), and with the body otherwise.
final result = await client.delete<Post?>(
  'posts/{id}',
  pathParameters: {'id': 7},
  fromJson: (json) => json == null ? null : Post.fromJson(json),
);
```

Use `void` or a nullable type when you omit `fromJson`. A non-nullable `T` without a mapper (or a mapper that cannot handle `null`) returns an `UnableToProcessException`.

### 204 No Content
`successRequestCodes` defaults to `[200, 201]`, so a `204` response is treated as an error. If your API returns `204` for successful requests, add it:

```dart
const PlayxNetworkClientSettings(successRequestCodes: [200, 201, 204]);
```

## Path Parameters
You can substitute `{placeholder}` segments in the request path with concrete values using the `pathParameters` parameter.
This keeps dynamic URLs readable and avoids manual string interpolation. Values are URL-encoded for safe path segments (spaces become `%20`).

```dart
final result = await _client.get(
  'users/{userId}/posts/{postId}',
  pathParameters: {
    'userId': 42,
    'postId': 7,
  },
  fromJson: Post.fromJson,
);
// The request is sent to: users/42/posts/7
```

Path parameters work with every HTTP method (`get`, `getList`, `post`, `postList`, `put`, `putList`, `delete`, `deleteList`, `patch`, `patchList`, `download`).

You can also attach app-wide path segments to **every** request via `customPathParameters` on `PlayxNetworkClient`, mirroring `customQuery`:

```dart
final PlayxNetworkClient _client = PlayxNetworkClient(
  dio: Dio(BaseOptions(baseUrl: _baseUrl)),
  // e.g. inject an API version segment into each path
  customPathParameters: () async => {'version': 'v2'},
);

// Sent to: v2/users/42
final result = await _client.get(
  '{version}/users/{userId}',
  pathParameters: {'userId': 42},
  fromJson: User.fromJson,
);
```

To skip the client-level `customPathParameters` for a single request, pass `attachCustomPathParameters: false`. Per-request `pathParameters` take precedence over `customPathParameters` for the same key.

## Streaming Support
`PlayxNetworkClient` can consume streaming endpoints (Server-Sent Events, NDJSON, chunked text/binary) via `getStream` and `postStream`.

Each streaming method returns a `NetworkStreamResult` — a sealed wrapper that either provides a `Stream` of decoded events (`NetworkStreamSuccess`) or a `NetworkException` (`NetworkStreamError`) if the request failed before any data was emitted.

The `PlayxStreamFormat` enum controls how raw byte chunks are decoded:

| Format | Element type | Description |
|--------|--------------|-------------|
| `PlayxStreamFormat.bytes` | `List<int>` | Raw byte chunks, no decoding. |
| `PlayxStreamFormat.text` | `String` | UTF-8 decoded text per chunk (multibyte characters split across chunks are reassembled). |
| `PlayxStreamFormat.json` | `Object` | NDJSON: one JSON-decoded value per line. Terminate each document with a newline. A malformed line emits an `UnableToProcessException` error event and the stream continues. |
| `PlayxStreamFormat.sse` | `PlayxSseEvent` | Server-Sent Events. |

### Example: Consuming an SSE endpoint

```dart
final result = await _client.getStream(
  '/events',
  format: PlayxStreamFormat.sse,
);

result.when(
  success: (events) {
    // events is a Stream<PlayxSseEvent>
    events.listen(
      (event) => print('Received: ${event.event} → ${event.data}'),
      onError: (e) => print('Stream error: $e'),
      onDone: () => print('Stream closed'),
    );
  },
  error: (error) => print('Request failed: ${error.message}'),
);
```

For convenience, `getSse` and `postSse` return a strongly-typed `NetworkStreamResult<PlayxSseEvent>` directly:

```dart
final result = await _client.getSse('/events');
```

### Example: Collecting a stream into a list

```dart
final result = await _client.getStream<String>(
  '/stream',
  format: PlayxStreamFormat.text,
);

final listResult = await result.toList(); // NetworkResult<List<String>>
listResult.when(
  success: (chunks) => print('Received ${chunks.length} chunks'),
  error: (error) => print('Error: ${error.message}'),
);
```

The returned stream is a single-subscription stream and supports cancellation via `cancelToken` or `cancelTag`, just like regular requests.

## Smart Request Cancellation
Manage and cancel multiple requests easily using `cancelTag`. 
By default, providing a `cancelTag` will automatically cancel any previous pending requests with the same tag (`cancelOld: true`).

```dart
// Subsequent calls with the same tag will cancel previous ones automatically
networkClient.getList(
  '/search?q=query',
  cancelTag: 'search_request',
  fromJson: Cat.fromJson,
);

// You can also cancel requests manually
networkClient.cancelRequestsByTag('search_request');
```

Additionally, if a request is canceled while JSON mapping is occurring in an isolate, the mapping process itself is also terminated to save resources.


## Error Message customization:
You can customize error message for the client and use your own messages.

- Create  a class that extends `ExceptionMessage` and overrides all messages with your own messages like that :

   ```dart
      class CustomExceptionMessage  extends ExceptionMessage{
      const  CustomExceptionMessage();
 
       @override
       String get badRequest =>  "Sorry, The API request is invalid or improperly formed.";

       @override
       String get conflict => "Sorry, The request wasn't completed due to a conflict.";

       @override
       String get defaultError => "Sorry, Something went wrong.";

       @override
       String get emptyResponse =>  "Sorry, Couldn't receive response from the server.";

       @override
       String get formatException => "Sorry, The request wasn't formatted correctly.";

       @override
       String get internalServerError => "Sorry, There is an internal server error";

       @override
       String get noInternetConnection =>  "Sorry, There is no internet connection.";

       @override
       String get notAcceptable => "Sorry, The request is not acceptable";

       @override
       String get notFound => "Sorry, The resource requested couldn't be found.";

       @override
       String get requestCancelled => "Sorry, The request has been canceled";

       @override
       String get requestTimeout => "Sorry, The request has timed out.";

       @override
       String get sendTimeout =>  "Sorry, The request has send timeout in connection with API server";

       @override
       String get serviceUnavailable => "Sorry, The service is unavailable";
       
       @override
       String get unableToProcess => "Sorry, Couldn't process the data.";
       
       @override
       String get unauthorizedRequest => "Sorry, The request is unauthorized.";

       @override
       String get unexpectedError => "Sorry, Something went wrong.";
       }
     ```
    -   Configure`PlayxNetworkClient`  to use `CustomExceptionMessage` that you have created.
   ```dart
   final PlayxNetworkClient _client = PlayxNetworkClient(
      exceptionMessages: const CustomExceptionMessage(),
    );
   ```

## Map Network Result
After getting the result from the API We can easily map the result to any type we want.
- Here is an example that maps list of cats to list of image urls.
  ```dart
    final NetworkResult<List<String?>> catImagesResult = result.map(success: (success) {
      final data = success.data;
      final images = data.map((e) => e.url).toList();
      return NetworkResult.success(images);
    }, error: (error) {
      return NetworkResult<List<String?>>.error(error.error);
    });
  ```

- We can also map result asynchronously using `mapAsync` like that :
  ```dart
     final NetworkResult<List<String?>> catImagesAsyncResult =await result.mapAsync(success: (success) async{
     final data = success.data;
     final images = data.map((e) => e.url).toList();
          return  NetworkResult.success(images);
      }, error: (error)async {
          return NetworkResult<List<String?>>.error(error.error);
     });
     ```


## Logging
The package uses [`pretty_dio_logger`](https://pub.dev/packages/pretty_dio_logger) pacakge to log dio requests.
### How it looks like

#### VS Code

![Request Example](https://github.com/Milad-Akarie/pretty_dio_logger/blob/master/images/request_log_vscode.png?raw=true 'Request Example')
![Error Example](https://github.com/Milad-Akarie/pretty_dio_logger/blob/master/images/error_log_vscode.png?raw=true 'Error Example')

### Android studio

![Response Example](https://github.com/Milad-Akarie/pretty_dio_logger/blob/master/images/response_log_android_studio.png?raw=true 'Response Example')

You can customize what is printed or whether it's enabled or not like this:
   ```dart
       final PlayxNetworkClient _client = PlayxNetworkClient(
      //attach logger to the client to print API requests, works only on debug mode.
      attachLoggerOnDebug: true,
      // You can customize the logger settings.
      logSettings: const LoggerSettings(
        responseBody: true,
        request = true,  
        requestHeader = true,  
        requestBody = true,  
        responseHeader = false,  
        error = true,  
        maxWidth = 90,  
        compact = true,
      ),
    );
   ```

## See Also:

[Playx](https://pub.dev/packages/playx)  : Playx eco system helps with redundant features , less code , more productivity , better organizing.

[Playx_theme](https://pub.dev/packages/playx_theme)  :Multi theme features for flutter apps from playx eco system.

[Playx_core](https://pub.dev/packages/playx_core)  :Core package for playx eco system contains shared classes and utilities.      
