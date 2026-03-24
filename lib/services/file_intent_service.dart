import 'dart:async';
import 'package:flutter/services.dart';

/// Handles files opened via OS "Open with..." or file associations.
/// Uses a platform channel to receive file paths from native code.
class FileIntentService {
  static const _channel = MethodChannel('photography_toolbox/file_intent');
  static const _eventChannel =
      EventChannel('photography_toolbox/file_intent/events');

  /// File path waiting to be processed by the target page.
  static String? pendingFilePath;

  static final _controller = StreamController<String>.broadcast();

  /// Stream of file paths received from OS file association intents.
  static Stream<String> get incomingFiles => _controller.stream;
  static bool _initialized = false;

  /// Initialize the service. Call once from main app state.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Listen for files arriving while the app is running (warm start)
    try {
      _eventChannel.receiveBroadcastStream().listen((event) {
        if (event is String && event.isNotEmpty) {
          _controller.add(event);
        }
      }, onError: (_) {});
    } catch (_) {
      // Platform channel not available (e.g., desktop)
    }

    // Check for initial file from cold start
    try {
      final initialFile =
          await _channel.invokeMethod<String>('getInitialFile');
      if (initialFile != null && initialFile.isNotEmpty) {
        _controller.add(initialFile);
      }
    } catch (_) {
      // Platform channel not available (e.g., desktop)
    }
  }
}
