import 'package:playx_core/playx_core.dart';
import 'package:playx_network/playx_network.dart';

/// Logs errors of the response handling, honouring the log settings.
///
/// Logging is skipped when the effective settings (the per-request [settings]
/// if given, otherwise the client-level ones) have logging disabled.
class HandlerLogger {
  HandlerLogger({required this.logger, required this.settings});

  final PlayxBaseLogger logger;
  final PlayxNetworkClientSettings settings;

  void error({
    String? text,
    Object? error,
    dynamic stackTrace,
    PlayxNetworkClientSettings? settings,
  }) {
    if ((settings ?? this.settings).logSettings.enabled) {
      logger.e(text, error: error, stackTrace: stackTrace);
    }
  }
}
