import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Token warna dari board Penpot `Anime / Video Player Screen`.
class AnimePlayerTokens {
  const AnimePlayerTokens._();

  static const Color accent = Color(0xFFE50914);
  static const Color gold = Color(0xFFFACC15);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF9AA4B2);
}

/// Tema untuk kontrol video bawaan `media_kit` (`MaterialVideoControls`).
///
/// Kontrol video (play/pause, seek bar, posisi, tombol 10 detik, tombol
/// fullscreen) memakai widget bawaan package supaya perilakunya halus dan
/// stabil. `Top Bar` tetap digambar manual oleh layar player lewat
/// [topBar] dan tidak berubah karena tema ini.
///
/// Catatan: [MaterialVideoControlsTheme.updateShouldNotify] hanya
/// memberi tahu descendants bila instance tema-nya identik. Karena itu
/// [MaterialVideoControlsThemeData] dibuat satu kali pada
/// [State.initState] supaya nilainya stabil, dan bagian yang dinamis
/// (ikon fullscreen) memakai [ValueListenableBuilder].
class AnimeVideoControlsTheme extends StatefulWidget {
  const AnimeVideoControlsTheme({
    super.key,
    required this.player,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.topBar,
    required this.child,
  });

  final Player player;

  /// Notifier status fullscreen (dipakai tombol fullscreen).
  final ValueListenable<bool> isFullscreen;

  /// Callback ketika user menekan tombol fullscreen.
  final VoidCallback onToggleFullscreen;

  /// Top bar manual (gambar sendiri sesuai desain Penpot).
  final List<Widget> topBar;

  final Widget child;

  @override
  State<AnimeVideoControlsTheme> createState() =>
      _AnimeVideoControlsThemeState();
}

class _AnimeVideoControlsThemeState extends State<AnimeVideoControlsTheme> {
  late final MaterialVideoControlsThemeData _data = _buildThemeData();

  MaterialVideoControlsThemeData _buildThemeData() {
    return MaterialVideoControlsThemeData(
      displaySeekBar: true,
      automaticallyImplySkipNextButton: false,
      automaticallyImplySkipPreviousButton: false,
      // Double tap: bagian kiri mundur 10 detik, bagian kanan maju 10 detik.
      seekOnDoubleTap: true,
      seekOnDoubleTapEnabledWhileControlsVisible: true,
      seekOnDoubleTapLayoutTapsRatios: const <int>[1, 0, 1],
      seekOnDoubleTapLayoutWidgetRatios: const <int>[1, 0, 1],
      seekOnDoubleTapBackwardDuration: const Duration(seconds: 10),
      seekOnDoubleTapForwardDuration: const Duration(seconds: 10),
      // Kontrol tampil saat player dibuka, auto-hide setelah 3 detik idle.
      visibleOnMount: true,
      controlsHoverDuration: const Duration(seconds: 3),
      controlsTransitionDuration: const Duration(milliseconds: 200),
      backdropColor: const Color(0x66000000),
      padding: EdgeInsets.zero,
      // Indikator buffering digambar sendiri oleh layar player.
      bufferingIndicatorBuilder: (context) => const SizedBox.shrink(),
      primaryButtonBar: <Widget>[
        const Spacer(flex: 2),
        _SeekButton(
          player: widget.player,
          icon: Icons.replay_10,
          seconds: -10,
          tooltip: 'Mundur 10 detik',
        ),
        const Spacer(),
        const MaterialPlayOrPauseButton(iconSize: 48.0),
        const Spacer(),
        _SeekButton(
          player: widget.player,
          icon: Icons.forward_10,
          seconds: 10,
          tooltip: 'Maju 10 detik',
        ),
        const Spacer(flex: 2),
      ],
      topButtonBar: widget.topBar,
      bottomButtonBar: <Widget>[
        const MaterialPositionIndicator(),
        const Spacer(),
        _FullscreenButton(
          isFullscreen: widget.isFullscreen,
          onPressed: widget.onToggleFullscreen,
        ),
      ],
      bottomButtonBarMargin: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 8.0,
      ),
      topButtonBarMargin: const EdgeInsets.symmetric(horizontal: 16.0),
      buttonBarHeight: 48.0,
      buttonBarButtonSize: 22.0,
      buttonBarButtonColor: AnimePlayerTokens.white,
      seekBarMargin: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 56.0,
      ),
      seekBarHeight: 3.0,
      seekBarContainerHeight: 28.0,
      seekBarColor: const Color(0x2EFFFFFF),
      seekBarPositionColor: AnimePlayerTokens.accent,
      seekBarBufferColor: const Color(0x2EFFFFFF),
      seekBarThumbSize: 12.0,
      seekBarThumbColor: AnimePlayerTokens.accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialVideoControlsTheme(
      normal: _data,
      fullscreen: _data,
      child: widget.child,
    );
  }
}

/// Tombol skip 10 detik (mundur/maju) memakai player yang sudah ada.
class _SeekButton extends StatelessWidget {
  const _SeekButton({
    required this.player,
    required this.icon,
    required this.seconds,
    required this.tooltip,
  });

  final Player player;
  final IconData icon;
  final int seconds;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        onPressed: () {
          final duration = player.state.duration;
          final target = player.state.position + Duration(seconds: seconds);
          final clamped = target < Duration.zero
              ? Duration.zero
              : (duration > Duration.zero && target > duration
                  ? duration
                  : target);
          player.seek(clamped);
        },
        icon: Icon(
          icon,
          color: AnimePlayerTokens.white,
          size: 28.0,
        ),
        tooltip: tooltip,
      ),
    );
  }
}

/// Tombol fullscreen yang menunjuk callback milik layar player.
///
/// Fullscreen dikelola manual di level screen (mengubah orientasi sistem),
/// bukan route fullscreen bawaan `media_kit`.
class _FullscreenButton extends StatelessWidget {
  const _FullscreenButton({required this.isFullscreen, required this.onPressed});

  final ValueListenable<bool> isFullscreen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isFullscreen,
      builder: (context, value, _) {
        final label = value ? 'Keluar fullscreen' : 'Fullscreen';
        return Semantics(
          button: true,
          label: label,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              value ? Icons.fullscreen_exit : Icons.fullscreen,
              color: AnimePlayerTokens.white,
              size: 22.0,
            ),
            tooltip: label,
          ),
        );
      },
    );
  }
}

