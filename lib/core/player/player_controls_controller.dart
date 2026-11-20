import 'dart:async';

import 'package:flutter/foundation.dart';

/// Mengatur perilaku auto-hide kontrol video dan perhitungan seek
/// (terpisah dari widget player agar bisa diuji tanpa mpv).
///
/// Aturan:
/// - Kontrol terlihat kembali setiap kali playback berjalan atau user
///   berinteraksi (tap).
/// - Kontrol disembunyikan otomatis setelah [hideDelay] idle, dan hanya
///   jika playback sedang berjalan. Saat pause kontrol tetap terlihat.
class PlayerControlsController extends ChangeNotifier {
  PlayerControlsController({this.hideDelay = const Duration(seconds: 3)});

  /// Jeda idle sebelum kontrol disembunyikan.
  final Duration hideDelay;

  /// Durasi lompatan saat double tap.
  static const Duration doubleTapSeekDelta = Duration(seconds: 10);

  /// Posisi playback terkini; dipakai bar progress dan timestamp.
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(
    Duration.zero,
  );

  bool _visible = true;
  bool _playing = false;
  Timer? _hideTimer;

  /// Apakah kontrol sedang terlihat.
  bool get visible => _visible;

  /// Apakah playback sedang berjalan.
  bool get playing => _playing;

  /// Dipanggil saat status playback berubah.
  void onPlayingChanged(bool playing) {
    _playing = playing;
    if (playing) {
      showTemporarily();
    } else {
      notifyListeners();
    }
  }

  /// Tampilkan kontrol lalu jadwalkan auto-hide.
  void showTemporarily() {
    if (!_visible) {
      _visible = true;
      notifyListeners();
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(hideDelay, () {
      if (_playing) {
        _visible = false;
        notifyListeners();
      }
    });
  }

  /// Tap pada area video: tampilkan/sembunyikan kontrol.
  void toggle() {
    if (_visible) {
      _hideTimer?.cancel();
      _visible = false;
      notifyListeners();
      return;
    }
    showTemporarily();
  }

  /// Delta seek untuk double tap: bagian kiri mundur, kanan maju.
  ///
  /// Mengembalikan [Duration.zero] bila lebar tidak valid.
  Duration doubleTapDelta({required double localX, required double width}) {
    if (width <= 0) return Duration.zero;
    final isLeftHalf = localX < width / 2;
    return isLeftHalf
        ? -doubleTapSeekDelta
        : doubleTapSeekDelta;
  }

  /// Membatasi target seek agar tidak sebelum 0 atau melewati durasi.
  Duration clampSeekTarget(Duration target, Duration duration) {
    var result = target;
    if (duration > Duration.zero && result > duration) {
      result = duration;
    }
    if (result < Duration.zero) {
      result = Duration.zero;
    }
    return result;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    position.dispose();
    super.dispose();
  }
}
