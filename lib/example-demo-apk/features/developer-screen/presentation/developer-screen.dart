import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/log_dev_storage_stub.dart';

class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  late Future<List<DevLogEntry>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = readDevLogEntries();
  }

  void _refreshLogs() {
    setState(() {
      _logsFuture = readDevLogEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Console'),
        actions: [
          IconButton(
            onPressed: _refreshLogs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: Container(
          width: 360,
          height: 320,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: FutureBuilder<List<DevLogEntry>>(
            future: _logsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final logs = (snapshot.data ?? const []).reversed.toList();
              if (logs.isEmpty) {
                return const Center(
                  child: Text(
                    'No logs available.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTimestamp(log.timestamp),
                        style: const TextStyle(
                          color: Colors.lightBlueAccent,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        log.message,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(String rawTimestamp) {
    final parsed = DateTime.tryParse(rawTimestamp);
    if (parsed == null) {
      return rawTimestamp;
    }

    final year = parsed.year.toString().padLeft(4, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    final second = parsed.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }
}