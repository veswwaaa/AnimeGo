import 'dart:convert';

import 'package:flutter/material.dart';

/// Normalisasi URL gambar anime: ensure https, cdn host untuk myanimelist.
String normalizeAnimeImageUrl(String? rawUrl, {required String fallbackTitle}) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty) {
    return fallbackImageForTitle(fallbackTitle);
  }

  final parsed = Uri.tryParse(value);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    return fallbackImageForTitle(fallbackTitle);
  }

  var normalized = parsed;
  if (normalized.scheme == 'http') {
    normalized = normalized.replace(scheme: 'https');
  }

  if (normalized.host == 'myanimelist.net' &&
      normalized.pathSegments.isNotEmpty &&
      normalized.pathSegments.first == 'images') {
    normalized = normalized.replace(host: 'cdn.myanimelist.net');
  }

  return normalized.toString();
}

String fallbackImageForTitle(String title) {
  return 'https://picsum.photos/seed/${Uri.encodeComponent(title)}/400/600';
}

int parseEpisodeCount(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

String extractBestImageUrl(dynamic images, {required String fallbackTitle}) {
  if (images is! Map<String, dynamic>) {
    return fallbackImageForTitle(fallbackTitle);
  }

  final webp = images['webp'];
  if (webp is Map<String, dynamic>) {
    final large = webp['large_image_url']?.toString();
    if (large != null && large.trim().isNotEmpty) {
      return normalizeAnimeImageUrl(large, fallbackTitle: fallbackTitle);
    }

    final normal = webp['image_url']?.toString();
    if (normal != null && normal.trim().isNotEmpty) {
      return normalizeAnimeImageUrl(normal, fallbackTitle: fallbackTitle);
    }
  }

  final jpg = images['jpg'];
  if (jpg is Map<String, dynamic>) {
    final large = jpg['large_image_url']?.toString();
    if (large != null && large.trim().isNotEmpty) {
      return normalizeAnimeImageUrl(large, fallbackTitle: fallbackTitle);
    }

    final normal = jpg['image_url']?.toString();
    if (normal != null && normal.trim().isNotEmpty) {
      return normalizeAnimeImageUrl(normal, fallbackTitle: fallbackTitle);
    }
  }

  return fallbackImageForTitle(fallbackTitle);
}

Widget buildSafeAnimeImage(
  String imageUrl, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  return Image.network(
    normalizeAnimeImageUrl(imageUrl, fallbackTitle: 'unknown'),
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, __, ___) => Container(
      width: width,
      height: height,
      color: const Color(0xFF1C1C24),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
    ),
  );
}

String toBase64(String input) {
  List<int> bytes = utf8.encode(input);
  String base64Encoded = base64Encode(bytes);
  return base64Encoded;
}
