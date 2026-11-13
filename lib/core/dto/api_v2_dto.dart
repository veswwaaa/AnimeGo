/// Canonical Provider Contract v2 - tipe Dart.
///
/// Sumber kebenaran: `anime-api/src/shared/contracts.ts` (TypeScript).
///
/// Semua response provider (REST maupun client-side scraper) dinormalisasi ke
/// bentuk di bawah ini, sehingga UI/consumer tidak perlu branching berdasarkan
/// asal data.
///
/// Konvensi:
/// - Field baru selalu nullable/optional agar APK lama tidak break.
/// - Breaking change harus lewat version path (`/api/v2/...`).
library;

/// Versi kontrak yang dipakai file ini.
const String kApiContractVersion = 'v2';

/// Kode error kanonik, dipakai consumer untuk branching yang stabil.
class ApiErrorCode {
  const ApiErrorCode._();

  static const String badRequest = 'BAD_REQUEST';
  static const String notFound = 'NOT_FOUND';
  static const String upstreamError = 'UPSTREAM_ERROR';
  static const String upstreamTimeout = 'UPSTREAM_TIMEOUT';
  static const String parseError = 'PARSE_ERROR';
  static const String rateLimited = 'RATE_LIMITED';
  static const String internalError = 'INTERNAL_ERROR';
}

/// Error kanonik dari backend.
class ApiV2Error {
  const ApiV2Error({
    required this.code,
    required this.message,
    this.provider,
    this.retryable = false,
    this.status,
  });

  final String code;
  final String message;
  final String? provider;
  final bool retryable;
  final int? status;

  factory ApiV2Error.fromJson(Map<String, dynamic> json) {
    return ApiV2Error(
      code: json['code']?.toString() ?? ApiErrorCode.internalError,
      message: json['message']?.toString() ?? 'Unknown error',
      provider: json['provider']?.toString(),
      retryable: json['retryable'] == true,
      status: _asInt(json['status']),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (provider != null) 'provider': provider,
    'retryable': retryable,
    if (status != null) 'status': status,
  };
}

/// Metadata response (cache, timing, pagination).
class ApiV2Meta {
  const ApiV2Meta({
    this.provider,
    this.contractVersion,
    this.timestamp,
    this.cacheAgeSeconds,
    this.total,
    this.extra = const {},
  });

  final String? provider;
  final String? contractVersion;
  final int? timestamp;
  final int? cacheAgeSeconds;
  final int? total;
  final Map<String, dynamic> extra;

  factory ApiV2Meta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ApiV2Meta();
    final known = <String>{
      'provider',
      'contractVersion',
      'timestamp',
      'cacheAgeSeconds',
      'total',
    };
    return ApiV2Meta(
      provider: json['provider']?.toString(),
      contractVersion: json['contractVersion']?.toString(),
      timestamp: _asInt(json['timestamp']),
      cacheAgeSeconds: _asInt(json['cacheAgeSeconds']),
      total: _asInt(json['total']),
      extra: {
        for (final entry in json.entries)
          if (!known.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    if (provider != null) 'provider': provider,
    if (contractVersion != null) 'contractVersion': contractVersion,
    if (timestamp != null) 'timestamp': timestamp,
    if (cacheAgeSeconds != null) 'cacheAgeSeconds': cacheAgeSeconds,
    if (total != null) 'total': total,
    ...extra,
  };
}

/// Envelope seragam untuk seluruh response provider v2.
class ApiV2Envelope<T> {
  const ApiV2Envelope({
    required this.success,
    required this.data,
    required this.meta,
    required this.error,
  });

  final bool success;
  final T? data;
  final ApiV2Meta meta;
  final ApiV2Error? error;

  bool get isSuccess => success && error == null && data != null;

}

/// Parse envelope generik dengan decoder per tipe data.
///
/// Decode error tidak dilempar; Instead dikembalikan sebagai envelope failure
/// supaya consumer punya satu jalur error handling.
ApiV2Envelope<T> parseApiV2Envelope<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic> json) decodeData,
) {
  final meta = ApiV2Meta.fromJson(json['meta'] as Map<String, dynamic>?);
  final errorJson = json['error'];

  if (errorJson is Map<String, dynamic>) {
    return ApiV2Envelope<T>(
      success: json['success'] == true,
      data: null,
      meta: meta,
      error: ApiV2Error.fromJson(errorJson),
    );
  }

  final dataJson = json['data'];
  if (dataJson is! Map<String, dynamic>) {
    return ApiV2Envelope<T>(
      success: false,
      data: null,
      meta: meta,
      error: ApiV2Error(
        code: ApiErrorCode.parseError,
        message: 'Payload data tidak valid',
        provider: meta.provider,
      ),
    );
  }

  try {
    return ApiV2Envelope<T>(
      success: json['success'] == true,
      data: decodeData(dataJson),
      meta: meta,
      error: null,
    );
  } catch (error) {
    return ApiV2Envelope<T>(
      success: false,
      data: null,
      meta: meta,
      error: ApiV2Error(
        code: ApiErrorCode.parseError,
        message: error.toString(),
        provider: meta.provider,
      ),
    );
  }
}

/// Satu hasil pencarian (ringkas).
class ApiSearchItem {
  const ApiSearchItem({
    required this.id,
    required this.provider,
    required this.title,
    this.image,
    this.description,
    this.genres = const [],
    this.status,
    this.rating,
    this.year,
    this.totalEpisodes,
    required this.url,
  });

  final String id;
  final String provider;
  final String title;
  final String? image;
  final String? description;
  final List<String> genres;
  final String? status;
  final double? rating;
  final int? year;
  final int? totalEpisodes;
  final String url;

  factory ApiSearchItem.fromJson(Map<String, dynamic> json) {
    return ApiSearchItem(
      id: json['id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Anime',
      image: _asString(json['image']),
      description: _asString(json['description']),
      genres: _asStringList(json['genres']),
      status: _asString(json['status']),
      rating: _asDouble(json['rating']),
      year: _asInt(json['year']),
      totalEpisodes: _asInt(json['totalEpisodes']),
      url: json['url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider,
    'title': title,
    'image': image,
    'description': description,
    'genres': genres,
    'status': status,
    'rating': rating,
    'year': year,
    'totalEpisodes': totalEpisodes,
    'url': url,
  };
}

class ApiSearchResponse {
  const ApiSearchResponse({required this.items, required this.query});

  final List<ApiSearchItem> items;
  final String query;

  factory ApiSearchResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ApiSearchResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(ApiSearchItem.fromJson)
                .toList(growable: false)
          : const <ApiSearchItem>[],
      query: json['query']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((item) => item.toJson()).toList(),
    'query': query,
  };
}

/// Detail anime canonical.
class ApiAnimeDetail {
  const ApiAnimeDetail({
    required this.id,
    required this.provider,
    required this.title,
    this.alternativeTitle,
    this.image,
    this.description,
    this.genres = const [],
    this.status,
    this.rating,
    this.year,
    this.totalEpisodes,
    required this.url,
    this.episodeListUrl,
    this.extra = const {},
  });

  final String id;
  final String provider;
  final String title;
  final String? alternativeTitle;
  final String? image;
  final String? description;
  final List<String> genres;
  final String? status;
  final double? rating;
  final int? year;
  final int? totalEpisodes;
  final String url;
  final String? episodeListUrl;
  final Map<String, dynamic> extra;

  factory ApiAnimeDetail.fromJson(Map<String, dynamic> json) {
    final rawExtra = json['extra'];
    return ApiAnimeDetail(
      id: json['id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Anime',
      alternativeTitle: _asString(json['alternativeTitle']),
      image: _asString(json['image']),
      description: _asString(json['description']),
      genres: _asStringList(json['genres']),
      status: _asString(json['status']),
      rating: _asDouble(json['rating']),
      year: _asInt(json['year']),
      totalEpisodes: _asInt(json['totalEpisodes']),
      url: json['url']?.toString() ?? '',
      episodeListUrl: _asString(json['episodeListUrl']),
      extra: rawExtra is Map<String, dynamic> ? rawExtra : const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider,
    'title': title,
    'alternativeTitle': alternativeTitle,
    'image': image,
    'description': description,
    'genres': genres,
    'status': status,
    'rating': rating,
    'year': year,
    'totalEpisodes': totalEpisodes,
    'url': url,
    'episodeListUrl': episodeListUrl,
    'extra': extra,
  };
}

/// Episode canonical. `id` berbentuk `provider:animeLocalId#number`.
class ApiEpisode {
  const ApiEpisode({
    required this.id,
    required this.animeId,
    required this.provider,
    required this.number,
    this.title,
    this.url,
    this.airingDate,
    this.extra = const {},
  });

  final String id;
  final String animeId;
  final String provider;
  final int number;
  final String? title;
  final String? url;
  final String? airingDate;
  final Map<String, dynamic> extra;

  factory ApiEpisode.fromJson(Map<String, dynamic> json) {
    final rawExtra = json['extra'];
    return ApiEpisode(
      id: json['id']?.toString() ?? '',
      animeId: json['animeId']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      number: _asInt(json['number']) ?? 0,
      title: _asString(json['title']),
      url: _asString(json['url']),
      airingDate: _asString(json['airingDate']),
      extra: rawExtra is Map<String, dynamic> ? rawExtra : const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'animeId': animeId,
    'provider': provider,
    'number': number,
    'title': title,
    'url': url,
    'airingDate': airingDate,
    'extra': extra,
  };
}

class ApiEpisodeListResponse {
  const ApiEpisodeListResponse({
    required this.animeId,
    required this.provider,
    required this.episodes,
  });

  final String animeId;
  final String provider;
  final List<ApiEpisode> episodes;

  factory ApiEpisodeListResponse.fromJson(Map<String, dynamic> json) {
    final rawEpisodes = json['episodes'];
    return ApiEpisodeListResponse(
      animeId: json['animeId']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      episodes: rawEpisodes is List
          ? rawEpisodes
                .whereType<Map<String, dynamic>>()
                .map(ApiEpisode.fromJson)
                .toList(growable: false)
          : const <ApiEpisode>[],
    );
  }

  Map<String, dynamic> toJson() => {
    'animeId': animeId,
    'provider': provider,
    'episodes': episodes.map((episode) => episode.toJson()).toList(),
  };
}

/// Mirror stream (server alternatif).
class ApiStreamMirror {
  const ApiStreamMirror({required this.url, this.label, this.quality});

  final String url;
  final String? label;
  final String? quality;

  factory ApiStreamMirror.fromJson(Map<String, dynamic> json) {
    return ApiStreamMirror(
      url: json['url']?.toString() ?? '',
      label: _asString(json['label']),
      quality: _asString(json['quality']),
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'label': label,
    'quality': quality,
  };
}

/// Stream canonical: `direct` | `hls` | `embed`.
class ApiStream {
  const ApiStream({
    required this.episodeId,
    required this.provider,
    required this.type,
    required this.url,
    this.mirrors = const [],
    this.headers = const {},
    this.expiresAt,
  });

  final String episodeId;
  final String provider;
  final String type;
  final String url;
  final List<ApiStreamMirror> mirrors;
  final Map<String, String> headers;
  final String? expiresAt;

  factory ApiStream.fromJson(Map<String, dynamic> json) {
    final rawMirrors = json['mirrors'];
    final rawHeaders = json['headers'];
    return ApiStream(
      episodeId: json['episodeId']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      type: json['type']?.toString() ?? 'direct',
      url: json['url']?.toString() ?? '',
      mirrors: rawMirrors is List
          ? rawMirrors
                .whereType<Map<String, dynamic>>()
                .map(ApiStreamMirror.fromJson)
                .toList(growable: false)
          : const <ApiStreamMirror>[],
      headers: rawHeaders is Map
          ? rawHeaders.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
      expiresAt: _asString(json['expiresAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'episodeId': episodeId,
    'provider': provider,
    'type': type,
    'url': url,
    'mirrors': mirrors.map((mirror) => mirror.toJson()).toList(),
    'headers': headers,
    'expiresAt': expiresAt,
  };
}

String? _asString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double? _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
