import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'developer_settings.dart';

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

  String toDisplayString() {
    final buf = StringBuffer();
    buf.writeln('Time: ${timestamp.toIso8601String()}');
    buf.writeln('Source: $source');
    buf.writeln('Error: $message');
    if (stackTrace != null) {
      buf.writeln('Stack Trace:');
      buf.write(stackTrace);
    }
    return buf.toString();
  }
}

class ErrorLog {
  static final List<ErrorEntry> _entries = [];
  static bool _loaded = false;
  static DateTime? _lastAgePrune;

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
    _pruneByCount();
    _pruneByAgeIfNeeded();
    await _save();
  }

  /// Remove oldest entries exceeding the cap.
  static void _pruneByCount() {
    final cap = DeveloperSettings.logCap;
    if (_entries.length > cap) {
      _entries.removeRange(0, _entries.length - cap);
    }
  }

  /// Remove entries older than the age limit, at most once per day.
  static void _pruneByAgeIfNeeded() {
    final now = DateTime.now();
    if (_lastAgePrune != null &&
        now.difference(_lastAgePrune!).inHours < 24) {
      return;
    }
    _lastAgePrune = now;
    final cutoff = now.subtract(Duration(days: DeveloperSettings.logAgeDays));
    _entries.removeWhere((e) => e.timestamp.isBefore(cutoff));
  }

  static Future<void> clear() async {
    _entries.clear();
    await _save();
  }

  static Future<void> deleteEntry(ErrorEntry entry) async {
    _entries.remove(entry);
    await _save();
  }

  /// Export all entries as a .log text file. Returns the file path.
  static Future<String> exportLog() async {
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // Collect unique sources
    final sources = _entries.map((e) => e.source).toSet();
    final sourceStr = sources.length <= 3
        ? sources.join('_').replaceAll(RegExp(r'[^\w]'), '')
        : '${sources.length}sources';

    final fileName = '${date}_$sourceStr.log';
    final file = File('${dir.path}/$fileName');

    final buf = StringBuffer();
    buf.writeln('OpenGrains Error Log');
    buf.writeln('Exported: ${now.toIso8601String()}');
    buf.writeln('Entries: ${_entries.length}');
    buf.writeln('=' * 60);
    for (final entry in _entries) {
      buf.writeln();
      buf.writeln(entry.toDisplayString());
      buf.writeln('-' * 40);
    }
    await file.writeAsString(buf.toString());
    return file.path;
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
