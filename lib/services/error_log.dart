import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ErrorEntry {
  final DateTime timestamp;
  final String source;
  final String message;
  final String? stackTrace;

  ErrorEntry({
    required this.timestamp,
    required this.source,
    required this.message,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'message': message,
        if (stackTrace != null) 'stackTrace': stackTrace,
      };

  factory ErrorEntry.fromJson(Map<String, dynamic> json) => ErrorEntry(
        timestamp: DateTime.parse(json['timestamp'] as String),
        source: json['source'] as String,
        message: json['message'] as String,
        stackTrace: json['stackTrace'] as String?,
      );
}

class ErrorLog {
  static final List<ErrorEntry> _entries = [];
  static bool _loaded = false;

  static List<ErrorEntry> get entries => List.unmodifiable(_entries);

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/error_log.json');
  }

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final file = await _file();
      if (await file.exists()) {
        final json = await file.readAsString();
        final list = jsonDecode(json) as List;
        _entries.clear();
        _entries.addAll(
            list.map((e) => ErrorEntry.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {
      // Ignore corrupt log file
    }
    _loaded = true;
  }

  static Future<void> log(String source, Object error,
      [StackTrace? stack]) async {
    final entry = ErrorEntry(
      timestamp: DateTime.now(),
      source: source,
      message: error.toString(),
      stackTrace: stack?.toString(),
    );
    _entries.add(entry);
    await _save();
  }

  static Future<void> clear() async {
    _entries.clear();
    await _save();
  }

  static Future<void> _save() async {
    try {
      final file = await _file();
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(
              _entries.map((e) => e.toJson()).toList()));
    } catch (_) {
      // Best effort
    }
  }
}
