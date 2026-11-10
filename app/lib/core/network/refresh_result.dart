/// Ket qua mot lan gia han access token.
///
/// Chi [rejected] noi len dieu gi do ve token. [unavailable] (timeout, mat
/// mang, 5xx) khong duoc phep xoa phien dang nhap con hieu luc.
enum RefreshResult {
  /// Da nhan va luu access token moi.
  ok,

  /// Server tu choi refresh token: het han hoac khong hop le.
  rejected,

  /// Khong toi duoc server hoac tra loi khong lien quan toi token.
  unavailable,
}
