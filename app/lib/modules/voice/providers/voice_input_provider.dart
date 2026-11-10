import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../services/audio_file_sink.dart';
import '../services/blaze_stt_service.dart';
import '../services/bluetooth_button_service.dart';
import '../services/stt_service.dart';
import '../services/stt_token_api.dart';
import '../services/tts_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum VoiceInputStatus { idle, connecting, recording, error }

class VoiceInputState {
  final VoiceInputStatus status;

  /// Van ban da chot: phan co san + cac cau da final.
  final String committedText;

  /// Ban nhap dang nhan dang (reset sau moi cau final).
  final String livePartial;

  final String? error;

  const VoiceInputState({
    this.status = VoiceInputStatus.idle,
    this.committedText = '',
    this.livePartial = '',
    this.error,
  });

  bool get isActive =>
      status == VoiceInputStatus.connecting || status == VoiceInputStatus.recording;

  /// Chu hien thi khi dang ghi.
  String get displayText {
    if (committedText.isEmpty) return livePartial;
    if (livePartial.isEmpty) return committedText;
    return '$committedText $livePartial';
  }

  VoiceInputState copyWith({
    VoiceInputStatus? status,
    String? committedText,
    String? livePartial,
    String? error,
  }) =>
      VoiceInputState(
        status: status ?? this.status,
        committedText: committedText ?? this.committedText,
        livePartial: livePartial ?? this.livePartial,
        error: error ?? this.error,
      );
}

/// Ket qua mot lan ghi.
class VoiceCapture {
  final String text;

  /// File ghi am goc (WAV) neu ghi duoc; null tren web hoac khi loi.
  final String? audioPath;

  const VoiceCapture({required this.text, this.audioPath});
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class VoiceInputNotifier extends StateNotifier<VoiceInputState> {
  final SttService _stt;
  final Future<String?> Function()? _newRecordingPath;
  StreamSubscription<SttMessage>? _sub;
  bool _isStarting = false;

  VoiceInputNotifier(this._stt, {Future<String?> Function()? newRecordingPath})
      : _newRecordingPath = newRecordingPath,
        super(const VoiceInputState()) {
    // Pre-warm: ket noi nen de lan bam dau khong phai cho xac thuc.
    Future.microtask(() async {
      try {
        await _stt.connect();
      } catch (_) {}
    });
  }

  /// [existingText] giu lam tien to (neu dang noi tiep vao o co san chu).
  Future<void> start([String existingText = '']) async {
    if (state.isActive || _isStarting) return;
    _isStarting = true;

    try {
      final hasPermission = await _stt.hasPermission();
      if (!mounted) return;

      if (!hasPermission) {
        debugPrint('[VoiceInput] microphone permission denied');
        state = const VoiceInputState(
          status: VoiceInputStatus.error,
          error: 'Không có quyền truy cập microphone',
        );
        return;
      }

      state = VoiceInputState(
        status: VoiceInputStatus.connecting,
        committedText: existingText.trim(),
      );

      // Huy listener cu truoc khi gan moi, tranh cau bi chot hai lan.
      await _sub?.cancel();
      _sub = _stt.messages.listen((msg) {
        if (!mounted) return;
        switch (msg) {
          case SttReady():
            state = state.copyWith(status: VoiceInputStatus.recording);

          case SttPartial(:final text):
            state = state.copyWith(
              status: VoiceInputStatus.recording,
              livePartial: text,
            );

          case SttFinal(:final text):
            final newCommitted = state.committedText.isEmpty
                ? text
                : '${state.committedText} $text';
            state = state.copyWith(
              status: VoiceInputStatus.recording,
              committedText: newCommitted,
              livePartial: '',
            );

          case SttError(:final message):
            state = VoiceInputState(
              status: VoiceInputStatus.error,
              error: message,
            );
        }
      });

      final path = await _newRecordingPath?.call();
      await _stt.start(recordToPath: path);
    } finally {
      _isStarting = false;
    }
  }

  /// Dung ghi: tra chu (da chot + ban nhap con lai) va duong dan file ghi am.
  Future<VoiceCapture> stop() async {
    final text = state.displayText;
    String? audioPath;
    try {
      audioPath = await _stt.stop();
    } catch (e) {
      debugPrint('[VoiceInput] stop failed, resetting anyway: $e');
    }
    await _sub?.cancel();
    _sub = null;
    if (mounted) state = const VoiceInputState();
    return VoiceCapture(text: text, audioPath: audioPath);
  }

  void clearError() {
    if (state.status == VoiceInputStatus.error) {
      state = const VoiceInputState();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _stt.dispose();
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final sttTokenApiProvider = Provider<SttTokenApi>((ref) {
  return SttTokenApi(dio: ref.read(dioProvider));
});

final sttServiceProvider = Provider.autoDispose<SttService>((ref) {
  final api = ref.read(sttTokenApiProvider);
  // VoiceInputNotifier.dispose() goi stt.dispose(), khong dispose hai lan o day.
  return BlazeSttService(tokenProvider: api.fetchToken);
});

final voiceInputProvider =
    StateNotifierProvider.autoDispose<VoiceInputNotifier, VoiceInputState>(
  (ref) => VoiceInputNotifier(
    ref.watch(sttServiceProvider),
    newRecordingPath: newRecordingPath,
  ),
);

final ttsServiceProvider = Provider.autoDispose<TtsService>((ref) {
  final tts = FlutterTtsService();
  ref.onDispose(tts.dispose);
  return tts;
});

final bluetoothButtonProvider = Provider.autoDispose<BluetoothButtonService>((ref) {
  final service = BluetoothButtonService()..attach();
  ref.onDispose(service.dispose);
  return service;
});
