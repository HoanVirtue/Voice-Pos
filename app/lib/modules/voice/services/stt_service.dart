import 'dart:async';

// ── Thong diep STT phat ra ───────────────────────────────────────────────────

sealed class SttMessage {
  const SttMessage();
}

class SttReady extends SttMessage {
  const SttReady();
}

class SttPartial extends SttMessage {
  final String text;
  const SttPartial(this.text);
}

class SttFinal extends SttMessage {
  final String text;
  const SttFinal(this.text);
}

class SttError extends SttMessage {
  final String message;
  const SttError(this.message);
}

/// Lay token STT (do BE cap). Nem loi neu khong lay duoc.
typedef SttTokenProvider = Future<String> Function();

/// Giao dien dich vu nhan dang giong noi. Cho phep thay Blaze bang nha cung cap
/// khac (hoac ban gia lap trong test) ma khong dong vao UI/provider.
abstract class SttService {
  Stream<SttMessage> get messages;

  Future<bool> hasPermission();

  /// Ket noi san (pre-warm) de lan bam dau tien khong phai cho handshake.
  Future<void> connect();

  /// Bat dau nghe. [recordToPath] != null: dong thoi ghi am ra file tai day.
  Future<void> start({String? recordToPath});

  /// Dung nghe, giu ket noi. Tra duong dan file ghi am (neu co).
  Future<String?> stop();

  void dispose();
}
