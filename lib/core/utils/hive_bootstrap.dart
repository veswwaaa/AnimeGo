import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

Future<void>? _hiveInitFuture;

Future<void> ensureHiveInitialized() {
  final existing = _hiveInitFuture;
  if (existing != null) {
    return existing;
  }

  final completer = Completer<void>();
  _hiveInitFuture = completer.future;

  () async {
    try {
      await Hive.initFlutter();
      completer.complete();
    } catch (error, stackTrace) {
      _hiveInitFuture = null;
      completer.completeError(error, stackTrace);
    }
  }();

  return _hiveInitFuture!;
}
