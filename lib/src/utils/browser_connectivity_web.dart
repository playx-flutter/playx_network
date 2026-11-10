import 'package:web/web.dart' as web;

/// Whether the browser reports that it is online (`navigator.onLine`).
///
/// `false` is reliable (the browser has no network). `true` only means a
/// network interface is up, not that the internet or the server is reachable.
bool? browserIsOnline() => web.window.navigator.onLine;
