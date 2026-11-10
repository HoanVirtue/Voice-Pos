// Tien ich van ban tieng Viet cho bo phan tich cau noi. Thuan Dart, khong phu thuoc Flutter.

const _accentGroups = <String, String>{
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<int, String> _accentMap = () {
  final m = <int, String>{};
  _accentGroups.forEach((base, chars) {
    for (final r in chars.runes) {
      m[r] = base;
    }
  });
  return m;
}();

/// Bo dau tieng Viet (ca dang dung san lan dang to hop U+0300..U+036F), chu thuong.
String removeAccents(String input) {
  final lower = input.toLowerCase();
  final sb = StringBuffer();
  for (final r in lower.runes) {
    if (r >= 0x0300 && r <= 0x036F) continue;
    sb.write(_accentMap[r] ?? String.fromCharCode(r));
  }
  return sb.toString();
}

/// Co dau (to hop hoac dung san) khong.
bool hasVietnameseMarks(String input) {
  final lower = input.toLowerCase();
  for (final r in lower.runes) {
    if ((r >= 0x0300 && r <= 0x036F) || _accentMap.containsKey(r)) return true;
  }
  return false;
}

/// Khoang cach Levenshtein.
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      cur[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Do giong 0..1 (1 = giong het) tren hai chuoi (thuong da bo dau).
double similarity(String a, String b) {
  if (a == b) return 1;
  final m = a.length > b.length ? a.length : b.length;
  if (m == 0) return 1;
  return 1 - levenshtein(a, b) / m;
}
