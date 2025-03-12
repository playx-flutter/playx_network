# Playx  Network
[![pub package](https://img.shields.io/pub/v/playx_network.svg?color=1284C5)](https://pub.dev/packages/playx_network)

Wrapper around [`Dio`](https://pub.dev/packages/dio) that can perform API requests with better error handling and easily get the result of any API request.

## Features
-  Perform GET, POST, PUT,, and DELETE HTTP methods for retrieving from and sending data to a server.
- Better Error handling for API and [`Dio`](https://pub.dev/packages/dio) Errors with the ability to customize these errors.
- Each request is wrapped by `NetworkResult` which returns whether success or failure of the API request.
- No need to use try catch anymore as every request is handled.
- Logs network calls in a pretty, easy to read format

## Installation

In `pubspec.yaml` add these lines to `dependencies`

```yaml  
playx_network: ^0.4.0
```  

## Usage

We can use `PlayxNetworkClient`  to perform GET, POST, PUT,, and DELETE HTTP methods for retrieving from and sending data to a server.

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
          senTimeout: const Duration(seconds: 20),
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
