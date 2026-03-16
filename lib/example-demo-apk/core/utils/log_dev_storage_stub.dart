import 'package:hive_flutter/hive_flutter.dart';

const String _devLogsBoxName = 'dev_logs_box';
const String _devLogsKey = 'entries';
Box<dynamic>? _devLogsBox;

class DevLogEntry {
  const DevLogEntry({required this.timestamp, required this.message});

  final String timestamp;
  final String message;

  Map<String, String> toJson() => {
    'timestamp': timestamp,
    'message': message,
  };

  static DevLogEntry? fromMap(Map<dynamic, dynamic> map) {
    final timestamp = map['timestamp']?.toString().trim() ?? '';
    final message = map['message']?.toString() ?? '';
    if (timestamp.isEmpty || message.isEmpty) return null;
    return DevLogEntry(timestamp: timestamp, message: message);
  }
}

Future<Box<dynamic>> _openDevLogsBox() async {
  _devLogsBox ??= await Hive.openBox<dynamic>(_devLogsBoxName);
  return _devLogsBox!;
}

Future<void> appendDevLogEntry(String text) async {
  try {
    final box = await _openDevLogsBox();
    final stored = box.get(_devLogsKey);
    final entries = (stored is List)
        ? stored
            .whereType<Map>()
            .map((e) => {'timestamp': e['timestamp']?.toString() ?? '', 'message': e['message']?.toString() ?? ''})
            .toList()
        : <Map<String, String>>[];

    entries.add({
      'timestamp': DateTime.now().toIso8601String(),
      'message': text,
    });

    await box.put(_devLogsKey, entries);
  } catch (_) {}
}

Future<List<DevLogEntry>> readDevLogEntries() async {
  try {
    final box = await _openDevLogsBox();
    final stored = box.get(_devLogsKey);
    if (stored is! List) return const [];
    return stored
        .whereType<Map>()
        .map((e) => DevLogEntry.fromMap(e))
        .whereType<DevLogEntry>()
        .toList();
  } catch (_) {
    return const [];
  }
}