import 'package:flutter_tts/flutter_tts.dart';

import '../config/voice_config.dart';

/// Doc ket qua bang giong noi (tieng Viet) de bo me khong can nhin man hinh.
abstract class TtsService {
  /// Doc [text]; hoan thanh khi doc xong (hoac bi [stop]).
  Future<void> speak(String text);
  Future<void> stop();
  void dispose();
}

class FlutterTtsService implements TtsService {
  final FlutterTts _tts;
  Future<void>? _init;

  FlutterTtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  Future<void> _ensureInit() => _init ??= _configure();

  Future<void> _configure() async {
    await _tts.setLanguage(VoiceConfig.ttsLanguage);
    await _tts.setSpeechRate(VoiceConfig.ttsSpeechRate);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  void dispose() {
    _tts.stop();
  }
}
