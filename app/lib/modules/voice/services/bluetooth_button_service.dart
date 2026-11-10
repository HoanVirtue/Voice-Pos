import 'dart:async';

import 'package:flutter/services.dart';

import '../config/voice_config.dart';

/// Bat phim cua nut bluetooth (remote chup anh, tai nghe) de bat dau/ket thuc ghi.
///
/// Cach lam: dang ky `HardwareKeyboard` - thiet bi bluetooth ghep nhu ban phim/
/// remote se gui phim `mediaPlayPause`, `volumeUp`, `camera`... vao app khi app
/// dang mo va co foreground.
///
/// GIOI HAN:
/// - Android: chay duoc khi app o foreground (man hinh quay luon sang, nho
///   wakelock). Khi tat man hinh / app xuong nen, he dieu hanh khong chuyen phim
///   cho app (can MediaSession + foreground service - chua lam).
/// - iOS: phim media cua tai nghe di qua `MPRemoteCommandCenter` chu khong phai
///   `HardwareKeyboard`; remote chup anh kieu "volume up" cung khong toi Flutter.
///   Chi remote dang ban phim bluetooth that moi chay. Phuong an du phong: nut
///   ghi am to tren man hinh (cham), hoac them plugin/native cau noi
///   `MPRemoteCommandCenter` (play/pause) sau.
/// - Web/desktop: phim nong tren ban phim (xem [triggerKeys]).
class BluetoothButtonService {
  /// Cac phim duoc coi la "nut bam": thuong gap o remote chup anh & tai nghe.
  static final Set<LogicalKeyboardKey> triggerKeys = {
    LogicalKeyboardKey.mediaPlayPause,
    LogicalKeyboardKey.mediaPlay,
    LogicalKeyboardKey.mediaPause,
    LogicalKeyboardKey.mediaRecord,
    LogicalKeyboardKey.mediaTrackNext,
    LogicalKeyboardKey.audioVolumeUp,
    LogicalKeyboardKey.audioVolumeDown,
    LogicalKeyboardKey.camera,
    LogicalKeyboardKey.headsetHook,
  };

  final Duration debounce;
  final DateTime Function() _now;

  final _pressCtrl = StreamController<LogicalKeyboardKey>.broadcast();
  bool _attached = false;
  DateTime? _lastPress;

  BluetoothButtonService({
    this.debounce = VoiceConfig.buttonDebounce,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Moi lan bam (da loc debounce) phat ra phim da bam.
  Stream<LogicalKeyboardKey> get presses => _pressCtrl.stream;

  bool get attached => _attached;

  void attach() {
    if (_attached) return;
    HardwareKeyboard.instance.addHandler(_onKey);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    _attached = false;
  }

  bool _onKey(KeyEvent event) => handleKeyEvent(event);

  /// Tach ra de test. Tra true neu su kien bi "an" (khong cho he thong xu ly,
  /// vd khong doi am luong).
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!triggerKeys.contains(event.logicalKey)) return false;

    final now = _now();
    final last = _lastPress;
    if (last != null && now.difference(last) < debounce) return true;
    _lastPress = now;
    _pressCtrl.add(event.logicalKey);
    return true;
  }

  void dispose() {
    detach();
    _pressCtrl.close();
  }
}
