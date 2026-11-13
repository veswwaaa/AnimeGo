import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;

/// User-Agent default yang dipakai untuk semua request keluar.
///
/// Beberapa situs akan menolak request yang tidak punya User-Agent browser.
const String kDefaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

/// Header default yang meniru request browser biasa.
const Map<String, String> kDefaultBrowserHeaders = {
  'User-Agent': kDefaultUserAgent,
  'Accept':
      'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  'Accept-Language': 'id-ID,id;q=0.9,en-US;q=0.8',
};

/// Error terstandardisasi agar kegagalan provider bisa dipetakan ke
/// [ApiError] tanpa harus parsing pesan string.
class ProviderHttpException implements Exception {
  const ProviderHttpException(
    this.message, {
    this.statusCode,
    this.retryable = true,
  });

  final String message;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() =>
      'ProviderHttpException(' + (statusCode?.toString() ?? '-') + '): ' + message;
}

/// Melakukan GET dengan retry + backoff.
///
/// Dipakai seluruh provider (REST maupun scraper) sehingga tidak ada lagi
/// implementasi HTTP yang tersebar di banyak file.
Future<http.Response> httpGetWithRetry(
  Uri uri, {
  required Duration timeout,
  int maxAttempts = 3,
  Map<String, String>? headers,
}) async {
  return _withRetry(
    () => http.get(uri, headers: mergeHeaders(headers)).timeout(timeout),
    maxAttempts: maxAttempts,
  );
}

/// Melakukan POST (form-urlencoded) dengan retry + backoff.
Future<http.Response> httpPostWithRetry(
  Uri uri, {
  required Duration timeout,
  int maxAttempts = 3,
  Map<String, String>? headers,
  Map<String, String>? body,
}) async {
  return _withRetry(
    () => http
        .post(uri, headers: mergeHeaders(headers), body: body)
        .timeout(timeout),
    maxAttempts: maxAttempts,
  );
}

/// Melakukan HEAD sambil mengikuti redirect, mengembalikan URL akhir.
Future<String> httpHeadFinalUrl(
  String url, {
  Duration timeout = const Duration(seconds: 15),
  Map<String, String>? headers,
}) async {
  final request = http.Request('HEAD', Uri.parse(url))
    ..followRedirects = true
    ..maxRedirects = 10;
  if (headers != null) {
    request.headers.addAll(headers);
  }

  final client = http.Client();
  try {
    final response = await client.send(request).timeout(timeout);
    await response.stream.drain<void>();
    if (response is http.BaseResponseWithUrl) {
      return (response as http.BaseResponseWithUrl).url.toString();
    }
    return request.url.toString();
  } finally {
    client.close();
  }
}

/// Menggabungkan header custom dengan header default browser.
Map<String, String> mergeHeaders(Map<String, String>? custom) {
  return {
    ...kDefaultBrowserHeaders,
    ...?custom,
  };
}

/// Menjalankan [action] dengan maksimal [maxAttempts] percobaan.
///
/// Jeda antar percobaan memakai backoff eksponensial ringan plus jitter
/// supaya tidak semua device retry bersamaan.
Future<T> _withRetry<T>(
  Future<T> Function() action, {
  required int maxAttempts,
}) async {
  final random = Random();
  Object? lastError;
  StackTrace? lastStackTrace;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;

      if (attempt >= maxAttempts) {
        break;
      }

      final delayMs = (300 * attempt) + random.nextInt(250);
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }

  if (lastError != null && lastStackTrace != null) {
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  throw TimeoutException('Request gagal setelah retry');
}
