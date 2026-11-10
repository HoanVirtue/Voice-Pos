/// Cau hinh giong noi. KHONG chua token: token Blaze lay tu BE qua
/// `GET /api/v1/voice/stt-token` (xem `SttTokenApi`).
class VoiceConfig {
  VoiceConfig._();

  /// Blaze STT realtime (giong app cu).
  static const sttWsUrl = 'wss://api.blaze.vn/v1/stt/realtime';
  static const sttLanguage = 'vi';
  static const sttModel = 'stt-stream-1.5';

  /// PCM16 mono 16 kHz, dung cho ca streaming lan file ghi am.
  static const sampleRate = 16000;

  /// Cho phan hoi `ready` toi da bay nhieu giay sau khi gui token.
  static const readyTimeout = Duration(seconds: 10);

  /// Ngung bam lien tiep (nut bluetooth hay doi phim) trong khoang nay bi bo qua.
  static const buttonDebounce = Duration(milliseconds: 500);

  /// Giong doc lai (TTS).
  static const ttsLanguage = 'vi-VN';
  static const ttsSpeechRate = 0.45;
}
