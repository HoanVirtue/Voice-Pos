import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/voice_config.dart';
import 'audio_file_sink.dart';
import 'stt_service.dart';

/// STT realtime qua Blaze (`wss://api.blaze.vn/v1/stt/realtime`).
///
/// Tach tu module agent cua app cu. Khac biet: token KHONG nhung cung trong
/// app ma lay tu BE qua [SttTokenProvider]; va co the ghi am song song ra file
/// WAV (PCM dang stream cung duoc ghi xuong dia).
class BlazeSttService implements SttService {
  final SttTokenProvider _tokenProvider;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
  StreamSubscription<List<int>>? _audioSub;
  AudioRecorder _recorder = AudioRecorder();
  Timer? _readyTimeout;
  bool _isReady = false;
  bool _restarting = false;
  bool _expectServerClose = false;

  AudioFileSink? _sink;
  String? _recordPath;

  Completer<void>? _readyCompleter;

  final _msgCtrl = StreamController<SttMessage>.broadcast();

  BlazeSttService({required SttTokenProvider tokenProvider})
      : _tokenProvider = tokenProvider;

  @override
  Stream<SttMessage> get messages => _msgCtrl.stream;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Ket noi va xac thuc san, chua thu am. No-op neu da san sang; neu dang ket
  /// noi do thi cho ket qua do thay vi chay song song.
  @override
  Future<void> connect() async {
    if (_isReady) return;

    if (_readyCompleter != null) {
      await _readyCompleter!.future.catchError((_) {});
      return;
    }

    // Dat Completer dong bo (truoc moi await) de chan connect() chay chong.
    final completer = Completer<void>();
    _readyCompleter = completer;
    _isReady = false;

    String token;
    try {
      token = await _tokenProvider();
    } catch (e) {
      _readyCompleter = null;
      // Hoan thanh binh thuong (khong loi) de khong co future loi khong ai nghe.
      if (!completer.isCompleted) completer.complete();
      _msgCtrl.add(const SttError('Không lấy được mã giọng nói từ máy chủ'));
      return;
    }

    debugPrint('[BlazeSTT] connecting to ${VoiceConfig.sttWsUrl}');
    _channel = WebSocketChannel.connect(Uri.parse(VoiceConfig.sttWsUrl));
    _channel!.sink.add(jsonEncode({
      'token': token,
      'language': VoiceConfig.sttLanguage,
      'model': VoiceConfig.sttModel,
    }));

    _readyTimeout = Timer(VoiceConfig.readyTimeout, () {
      if (!_isReady) {
        debugPrint('[BlazeSTT] timeout waiting for ready');
        if (!completer.isCompleted) completer.completeError('timeout');
        _readyCompleter = null;
        _msgCtrl.add(const SttError('Hết thời gian kết nối STT'));
      }
    });

    _wsSub = _channel!.stream.listen(
      _onWsMessage,
      onError: (Object e) {
        debugPrint('[BlazeSTT] ws error: $e');
        _readyTimeout?.cancel();
        _isReady = false;
        if (!completer.isCompleted) completer.completeError(e);
        _readyCompleter = null;
        _msgCtrl.add(SttError(e.toString()));
      },
      onDone: () {
        debugPrint('[BlazeSTT] ws closed');
        _readyTimeout?.cancel();
        final wasReady = _isReady || _readyCompleter != null;
        _isReady = false;
        if (_readyCompleter != null) {
          if (!completer.isCompleted) completer.completeError('closed');
          _readyCompleter = null;
        }
        _channel = null;
        final wasExpected = _expectServerClose;
        _expectServerClose = false;

        if (wasExpected) {
          // Server dong vi het gio nhan roi: tu noi lai am tham.
          if (_audioSub == null) {
            Future.microtask(connect);
          } else {
            Future.microtask(_reconnectAndRestartAudio);
          }
        } else if (wasReady && _audioSub != null) {
          _msgCtrl.add(const SttError('Kết nối STT bị đóng'));
        }
      },
      cancelOnError: true,
    );

    await completer.future.catchError((_) {});
  }

  /// Bat dau phien nghe. Dung lai ket noi da pre-warm neu co.
  @override
  Future<void> start({String? recordToPath}) async {
    if (!_isReady) {
      await connect();
      if (!_isReady) return; // ket noi that bai (da phat SttError)
    }
    await _closeSink();
    if (recordToPath != null) {
      _sink = createAudioFileSink(recordToPath, sampleRate: VoiceConfig.sampleRate);
      _recordPath = _sink == null ? null : recordToPath;
    }
    _msgCtrl.add(const SttReady());
    await _startAudio();
  }

  void _onWsMessage(dynamic data) {
    if (data is! String) return;
    try {
      final msg = jsonDecode(data) as Map<String, dynamic>;
      final type = msg['type'] as String?;
      switch (type) {
        case 'ready':
          debugPrint('[BlazeSTT] <- ready');
          _isReady = true;
          _readyTimeout?.cancel();
          _readyCompleter?.complete();
          _readyCompleter = null;
        case 'partial':
          // Nhieu lan moi giay, la loi nguoi dung: khong ghi log noi dung.
          _msgCtrl.add(SttPartial(msg['text'] as String? ?? ''));
        case 'final':
          final text = msg['text'] as String? ?? '';
          debugPrint('[BlazeSTT] <- final (${text.length} chars)');
          _msgCtrl.add(SttFinal(text));
        case 'error':
          final text = msg['text'] as String? ?? '';
          debugPrint('[BlazeSTT] <- error');
          if (text.toLowerCase().contains('timeout')) {
            _expectServerClose = true;
          } else {
            _msgCtrl.add(SttError(text));
          }
        default:
          debugPrint('[BlazeSTT] <- $type');
      }
    } catch (e) {
      debugPrint('[BlazeSTT] parse error: $e');
    }
  }

  Future<void> _startAudio() async {
    try {
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: VoiceConfig.sampleRate,
        numChannels: 1,
      ));
      var silenceStreak = 0;
      var hadAudio = false;

      _audioSub = stream.listen((chunk) {
        _channel?.sink.add(chunk);
        _sink?.add(chunk); // ghi song song ra file

        // PCM16 LE: bien do lon nhat moi chunk.
        int maxAmp = 0;
        for (int i = 0; i + 1 < chunk.length; i += 2) {
          int sample = (chunk[i + 1] << 8) | chunk[i];
          if (sample > 32767) sample -= 65536;
          final abs = sample < 0 ? -sample : sample;
          if (abs > maxAmp) maxAmp = abs;
        }

        if (maxAmp >= 20) {
          hadAudio = true;
          silenceStreak = 0;
        } else if (hadAudio && !_restarting) {
          silenceStreak++;
          // ~5s im lang sau khi da co tieng: HAL Android co the da treo mic.
          if (silenceStreak >= 25) {
            hadAudio = false;
            silenceStreak = 0;
            _restarting = true;
            debugPrint('[BlazeSTT] silence watchdog - restarting AudioRecord');
            Future.microtask(_restartAudio);
          }
        }
      });
      debugPrint('[BlazeSTT] audio streaming started');
    } catch (e) {
      debugPrint('[BlazeSTT] audio error: $e');
      _msgCtrl.add(SttError('Không thể ghi âm: $e'));
    }
  }

  Future<void> _reconnectAndRestartAudio() async {
    debugPrint('[BlazeSTT] reconnecting after server timeout (audio was active)');
    final sub = _audioSub;
    _audioSub = null;
    await sub?.cancel();
    await _recorder.stop();
    _recorder.dispose();
    _recorder = AudioRecorder();
    _wsSub?.cancel();
    _wsSub = null;
    _restarting = false;
    await connect();
    if (_isReady) await _startAudio();
  }

  Future<void> _restartAudio() async {
    final sub = _audioSub;
    _audioSub = null;
    await sub?.cancel();
    await _recorder.stop();
    _recorder.dispose();
    _recorder = AudioRecorder();
    _restarting = false;
    if (_isReady) await _startAudio();
  }

  /// Dung thu am nhung giu WebSocket de lan sau khong phai cho xac thuc.
  @override
  Future<String?> stop() async {
    debugPrint('[BlazeSTT] stopping audio (WS kept alive)');
    _restarting = false;
    final sub = _audioSub;
    _audioSub = null;
    await sub?.cancel();
    await _recorder.stop();
    _recorder.dispose();
    _recorder = AudioRecorder();
    final path = _recordPath;
    _recordPath = null;
    await _closeSink();
    return path;
  }

  Future<void> _closeSink() async {
    final sink = _sink;
    _sink = null;
    if (sink != null) {
      try {
        await sink.close();
      } catch (e) {
        debugPrint('[BlazeSTT] close audio file failed: $e');
      }
    }
  }

  @override
  void dispose() {
    _readyTimeout?.cancel();
    _readyTimeout = null;
    _isReady = false;
    _restarting = false;
    _expectServerClose = false;
    _readyCompleter = null;
    _wsSub?.cancel();
    _wsSub = null;
    _audioSub?.cancel();
    _audioSub = null;
    unawaited(_closeSink());
    _recorder.stop().ignore();
    _recorder.dispose();
    try {
      _channel?.sink.close();
    } catch (e) {
      debugPrint('[BlazeSTT] ws close on dispose failed: $e');
    }
    _channel = null;
    _msgCtrl.close();
  }
}
