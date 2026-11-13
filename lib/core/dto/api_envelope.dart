/// Kontrak data canonical (DTO) yang dipakai seluruh provider.
///
/// Semua sumber data (REST, scraper client-side) wajib mengembalikan bentuk
/// objek yang sama agar layer UI tidak perlu tahu asal datanya.
library;

class ApiError {
  const ApiError({
    required this.code,
    required this.message,
    this.provider,
    this.retryable = false,
  });

  final String code;
  final String message;
  final String? provider;
  final bool retryable;

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (provider != null) 'provider': provider,
    'retryable': retryable,
  };
}

/// Envelope seragam untuk semua response.
class ApiEnvelope<T> {
  const ApiEnvelope({this.data, this.meta = const {}, this.error});

  final T? data;
  final Map<String, dynamic> meta;
  final ApiError? error;

  bool get isSuccess => error == null && data != null;

  factory ApiEnvelope.success(T data, {Map<String, dynamic> meta = const {}}) =>
      ApiEnvelope<T>(data: data, meta: meta);

  factory ApiEnvelope.failure(ApiError error, {Map<String, dynamic> meta = const {}}) =>
      ApiEnvelope<T>(data: null, meta: meta, error: error);
}

/// Identitas anime yang unik lintas provider: `{providerId}:{providerLocalId}`.
class AnimeId {
  const AnimeId(this.providerId, this.localId);

  final String providerId;
  final String localId;

  String get composite => '$providerId:$localId';

  static AnimeId? parse(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    return AnimeId(parts.first, parts.sublist(1).join(':'));
  }
}
