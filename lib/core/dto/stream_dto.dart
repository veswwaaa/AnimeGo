import 'api_envelope.dart';

/// Hasil resolusi stream yang seragam lintas provider.
class StreamDto {
  const StreamDto({
    required this.episodeId,
    required this.type,
    required this.url,
    this.mirrors = const [],
    this.headers = const {},
    this.expiresAt,
  });

  final AnimeId episodeId;

  /// `direct` | `hls` | `embed`.
  final String type;
  final String url;
  final List<StreamMirror> mirrors;
  final Map<String, String> headers;
  final DateTime? expiresAt;

  Map<String, dynamic> toJson() => {
    'episodeId': episodeId.composite,
    'type': type,
    'url': url,
    'mirrors': mirrors.map((m) => m.toJson()).toList(),
    'headers': headers,
    'expiresAt': expiresAt?.toIso8601String(),
  };
}

class StreamMirror {
  const StreamMirror({required this.url, this.label, this.quality});

  final String url;
  final String? label;
  final String? quality;

  Map<String, dynamic> toJson() => {
    'url': url,
    'label': label,
    'quality': quality,
  };
}
