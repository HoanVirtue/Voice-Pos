/// Tien ich thoi gian (gio Viet Nam, UTC+7, khong doi gio) va dinh dang tien/khoi luong.
/// Quy uoc: luu UTC, hien thi gio VN. Tien `int` dong (64-bit tren may ao Dart). Khoi luong `int` gram.
class VnTime {
  VnTime._();

  static const Duration offset = Duration(hours: 7);

  /// UTC -> "gio tuong" VN (DateTime UTC nhung cac truong la gio dia phuong VN).
  static DateTime toVn(DateTime utc) => utc.toUtc().add(offset);

  /// Ngay VN dang `yyyy-MM-dd` cua mot thoi diem UTC.
  static String dateString(DateTime utc) {
    final v = toVn(utc);
    return '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
  }

  /// Ngay VN hien tai.
  static String today([DateTime? nowUtc]) => dateString(nowUtc ?? DateTime.now().toUtc());

  /// [00:00, 24:00) gio VN cua [date] (`yyyy-MM-dd`) quy ra UTC: (from, toExclusive).
  static (DateTime, DateTime) dayRangeUtc(String date) {
    final p = date.split('-').map(int.parse).toList();
    final startVn = DateTime.utc(p[0], p[1], p[2]);
    final from = startVn.subtract(offset);
    return (from, from.add(const Duration(days: 1)));
  }

  /// Cong/tru ngay tren chuoi `yyyy-MM-dd`.
  static String addDays(String date, int days) {
    final p = date.split('-').map(int.parse).toList();
    final d = DateTime.utc(p[0], p[1], p[2]).add(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// "09/11/2026" tu `yyyy-MM-dd`.
  static String dmy(String date) {
    final p = date.split('-');
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  /// "14:05" gio VN.
  static String hm(DateTime utc) {
    final v = toVn(utc);
    return '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }
}

/// "1.200.000 đ".
String formatMoney(int vnd) {
  final neg = vnd < 0;
  final s = vnd.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}$buf đ';
}

/// "2,5 kg" / "500 g" tu gram.
String formatWeight(int gram) {
  if (gram < 1000) return '$gram g';
  final kg = gram / 1000;
  final text = kg == kg.roundToDouble()
      ? kg.round().toString()
      : kg.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',');
  return '$text kg';
}
