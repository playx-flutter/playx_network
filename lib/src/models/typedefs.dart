import 'dart:async';

import 'package:dio/dio.dart';

///Function that converts json response to the required model.
typedef JsonMapper<T> = FutureOr<T> Function(dynamic json);

///Function that converts json error response from api to error message.
typedef ErrorMapper = String? Function(dynamic json);

/// Converts the json error response of a failed request into structured data
/// (for example a custom error model) that is exposed as `ApiException.extra`.
/// It complements [ErrorMapper], which still produces the error message.
typedef ErrorExtraMapper = Object? Function(dynamic json);

/// Function that handles unauthorized request.
typedef UnauthorizedRequestHandler = void Function(Response? response);
