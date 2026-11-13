import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../utils/http_client.dart';
import 'anime_provider.dart';

/// Cara parameter URL di-encode oleh provider.
enum ParamEncoding { plain, query, base64 }

/// Base class untuk semua provider yang berbasis REST (backend HTTP).
///
/// Menyeragamkan detail HTTP: User-Agent browser, retry + backoff + jitter,
/// timeout, dan encoding parameter URL (base64 vs query component).
abstract class RestProviderBase implements AnimeProvider {
  RestProviderBase({http.Client? client, Random? random})
      : _client = client ?? http.Client(),
        _random = random ?? Random();

  final http.Client _client;
  final Random _random;
  bool _closed = false;

  /// Base URL backend yang dipakai provider ini.
  String get baseUrl;

  /// Header tambahan per provider.
  Map<String, String> get extraHeaders => const <String, String>{};

  /// Cara provider meng-encode parameter URL.
  ParamEncoding get paramEncoding => ParamEncoding.query;

  @override
  String get kind => 'rest';

  /// Menutup HTTP client milik provider.
  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }

  /// Melakukan GET dengan retry + backoff.
  Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 20),
    int maxAttempts = 2,
  }) {
    return _send(
      () => _client.get(Uri.parse(url), headers: _mergeHeaders(headers)),
      timeout: timeout,
      maxAttempts: maxAttempts,
      url: url,
    );
  }

  /// Melakukan POST form-urlencoded dengan retry + backoff.
  Future<http.Response> post(
    String url, {
    required Map<String, String> headers,
    Map<String, String>? body,
    Duration timeout = const Duration(seconds: 20),
    int maxAttempts = 2,
  }) {
    return _send(
      () => _client.post(
        Uri.parse(url),
        headers: _mergeHeaders(headers),
        body: body,
      ),
      timeout: timeout,
      maxAttempts: maxAttempts,
      url: url,
    );
  }

  /// Encoding parameter URL sesuai [paramEncoding].
  String encodeParam(String value) {
    switch (paramEncoding) {
      case ParamEncoding.base64:
        return base64Encode(utf8.encode(value));
      case ParamEncoding.query:
      case ParamEncoding.plain:
        return Uri.encodeQueryComponent(value);
    }
  }

  Map<String, String> _mergeHeaders(Map<String, String>? headers) {
    return <String, String>{
      ...kDefaultBrowserHeaders,
      ...extraHeaders,
      ...?headers,
    };
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required Duration timeout,
    required int maxAttempts,
    required String url,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await request().timeout(timeout);
        if (response.statusCode >= 500 || response.statusCode == 429) {
          if (attempt < maxAttempts) {
            await _backoff(attempt);
            continue;
          }
          throw ProviderHttpException(
            'Status ' + response.statusCode.toString() + ' dari ' + url,
            statusCode: response.statusCode,
          );
        }
        return response;
      } on ProviderHttpException {
        rethrow;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt >= maxAttempts) break;
        await _backoff(attempt);
      }
    }

    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
    throw ProviderHttpException('Request gagal setelah retry: ' + url);
  }

  /// Backoff eksponensial ringan + jitter supaya beberapa perangkat tidak
  /// retry bersamaan dan terlihat seperti bot scraping.
  Future<void> _backoff(int attempt) {
    final base = 400 * attempt;
    final jitter = _random.nextInt(250);
    return Future<void>.delayed(Duration(milliseconds: base + jitter));
  }
}
