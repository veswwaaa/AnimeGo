import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'mal_models.dart';

/// Klien HTTP tipis ke MyAnimeList, dipakai [MalAuthService] dan gateway.
///
/// Wrapper ini memusatkan penanganan error HTTP sehingga seluruh lapisan atas
/// hanya melihat [MalAuthException] dengan pesan yang bisa ditampilkan user.
class MalHttpClient {
  MalHttpClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Map<String, String> _formHeaders = {
    'Content-Type': 'application/x-www-form-urlencoded',
    'Accept': 'application/json',
  };

  void close() => _client.close();

  /// POST form-encoded ke endpoint token MAL.
  Future<Map<String, dynamic>> postForm(
    String url,
    Map<String, String> body,
  ) async {
    final target = Uri.parse(url);
    return _send(
      () => _client.post(target, headers: _formHeaders, body: body),
    );
  }

  /// PUT form-encoded (dipakai untuk update list MAL).
  ///
  /// Header bearer wajib karena endpoint list MAL memverifikasi access token.
  Future<Map<String, dynamic>> putForm(
    String url,
    Map<String, String> body, {
    Map<String, String> headers = const {},
  }) async {
    final target = Uri.parse(url);
    return _send(
      () => _client.put(
        target,
        headers: {..._formHeaders, ...headers},
        body: body,
      ),
    );
  }

  /// DELETE dengan header bearer (dipakai untuk hapus anime dari list MAL).
  Future<Map<String, dynamic>> deleteJson(
    String url,
    Map<String, String> headers,
  ) async {
    final target = Uri.parse(url);
    return _send(() => _client.delete(target, headers: headers));
  }

  /// GET JSON ke API MAL.
  Future<Map<String, dynamic>> getJson(
    String url,
    Map<String, String> headers,
  ) async {
    final target = Uri.parse(url);
    return _send(() => _client.get(target, headers: headers));
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    late http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const MalAuthException('Permintaan ke MyAnimeList terlalu lama.');
    } catch (_) {
      throw const MalAuthException(
        'Tidak dapat terhubung ke MyAnimeList. Periksa koneksi internet Anda.',
      );
    }

    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MalAuthException(
        _extractError(decoded) ?? 'MyAnimeList menolak permintaan.',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) return parsed;
      return <String, dynamic>{'data': parsed};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String? _extractError(Map<String, dynamic> decoded) {
    final error = decoded['error'];
    if (error is Map && error['message'] != null) {
      return error['message'].toString();
    }
    if (error is String && error.isNotEmpty) return error;
    if (decoded['message'] != null) return decoded['message'].toString();
    return null;
  }
}
