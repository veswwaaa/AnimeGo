import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import 'log_dev_storage_stub.dart';

/// Log untuk keperluan debugging selama development.
void logDev(String text, {String prefix = 'Dev Log:'}) {
  print('$prefix $text');
  unawaited(appendDevLogEntry('$prefix $text'));
}

void logInfo(String message) {
  developer.log(message, name: 'ExampleScreen');
}

void logError(String message, Object error, StackTrace stackTrace) {
  developer.log(
    message,
    name: 'ExampleScreen',
    error: error,
    stackTrace: stackTrace,
  );
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
