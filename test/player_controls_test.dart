import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:animego/core/player/player_controls_controller.dart';

void main() {
  group('PlayerControlsController auto-hide', () {
    test('kontrol tersembunyi otomatis setelah 3 detik idle saat playing', () {
      fakeAsync((async) {
        final controller = PlayerControlsController();
        controller.onPlayingChanged(true);
        expect(controller.visible, isTrue);

        async.elapse(const Duration(seconds: 3));
        expect(controller.visible, isFalse);
        controller.dispose();
      });
    });

    test('kontrol tetap terlihat saat pause', () {
      fakeAsync((async) {
        final controller = PlayerControlsController();
        controller.onPlayingChanged(false);
        async.elapse(const Duration(seconds: 5));
        expect(controller.visible, isTrue);
        controller.dispose();
      });
    });

    test('tap menyalakan kontrol kembali dan menjadwalkan auto-hide', () {
      fakeAsync((async) {
        final controller = PlayerControlsController();
        controller.onPlayingChanged(true);
        async.elapse(const Duration(seconds: 3));
        expect(controller.visible, isFalse);

        controller.toggle();
        expect(controller.visible, isTrue);

        async.elapse(const Duration(seconds: 3));
        expect(controller.visible, isFalse);
        controller.dispose();
      });
    });

    test('tap saat kontrol terlihat menyembunyikan kontrol seketika', () {
      fakeAsync((async) {
        final controller = PlayerControlsController();
        controller.onPlayingChanged(true);
        controller.toggle();
        expect(controller.visible, isFalse);
        controller.dispose();
      });
    });
  });

  group('Double tap seek', () {
    test('bagian kiri mundur 10 detik', () {
      final controller = PlayerControlsController();
      final delta = controller.doubleTapDelta(localX: 50, width: 200);
      expect(delta, const Duration(seconds: -10));
      controller.dispose();
    });

    test('bagian kanan maju 10 detik', () {
      final controller = PlayerControlsController();
      final delta = controller.doubleTapDelta(localX: 150, width: 200);
      expect(delta, const Duration(seconds: 10));
      controller.dispose();
    });

    test('lebar tidak valid menghasilkan delta nol', () {
      final controller = PlayerControlsController();
      expect(
        controller.doubleTapDelta(localX: 10, width: 0),
        Duration.zero,
      );
      controller.dispose();
    });

    test('seek tidak mendahului 0 dan tidak melewati durasi', () {
      final controller = PlayerControlsController();
      expect(
        controller.clampSeekTarget(
          const Duration(seconds: -5),
          const Duration(seconds: 100),
        ),
        Duration.zero,
      );
      expect(
        controller.clampSeekTarget(
          const Duration(seconds: 130),
          const Duration(seconds: 100),
        ),
        const Duration(seconds: 100),
      );
      controller.dispose();
    });
  });
}
