import 'package:banhang_app/modules/voice/services/bluetooth_button_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

KeyDownEvent _down(LogicalKeyboardKey logical, PhysicalKeyboardKey physical) =>
    KeyDownEvent(
      physicalKey: physical,
      logicalKey: logical,
      timeStamp: Duration.zero,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('phim media phat ra su kien va bi an', () async {
    final svc = BluetoothButtonService();
    final got = <LogicalKeyboardKey>[];
    svc.presses.listen(got.add);

    final handled = svc.handleKeyEvent(
      _down(LogicalKeyboardKey.mediaPlayPause, PhysicalKeyboardKey.mediaPlayPause),
    );
    await Future<void>.delayed(Duration.zero);

    expect(handled, isTrue);
    expect(got, [LogicalKeyboardKey.mediaPlayPause]);
    svc.dispose();
  });

  test('phim thuong (chu cai) bi bo qua', () {
    final svc = BluetoothButtonService();
    final handled = svc.handleKeyEvent(
      _down(LogicalKeyboardKey.keyA, PhysicalKeyboardKey.keyA),
    );
    expect(handled, isFalse);
    svc.dispose();
  });

  test('chi tinh KeyDown, bo qua KeyUp', () {
    final svc = BluetoothButtonService();
    final handled = svc.handleKeyEvent(const KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.mediaPlayPause,
      logicalKey: LogicalKeyboardKey.mediaPlayPause,
      timeStamp: Duration.zero,
    ));
    expect(handled, isFalse);
    svc.dispose();
  });

  test('debounce: bam lien tiep trong khoang ngan chi tinh mot lan', () async {
    var now = DateTime(2026, 1, 1, 8);
    final svc = BluetoothButtonService(
      debounce: const Duration(milliseconds: 500),
      now: () => now,
    );
    var count = 0;
    svc.presses.listen((_) => count++);
    final e = _down(LogicalKeyboardKey.audioVolumeUp, PhysicalKeyboardKey.audioVolumeUp);

    svc.handleKeyEvent(e);
    now = now.add(const Duration(milliseconds: 200));
    svc.handleKeyEvent(e); // bi bo (van tra true de he thong khong doi am luong)
    now = now.add(const Duration(milliseconds: 600));
    svc.handleKeyEvent(e);
    await Future<void>.delayed(Duration.zero);

    expect(count, 2);
    svc.dispose();
  });

  test('attach/detach dang ky va huy handler', () {
    final svc = BluetoothButtonService();
    svc.attach();
    expect(svc.attached, isTrue);
    svc.detach();
    expect(svc.attached, isFalse);
    svc.dispose();
  });
}
