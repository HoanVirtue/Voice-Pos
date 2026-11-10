// Doc so thanh chu tieng Viet (de app doc lai bang giong). Thuan Dart.

const _digits = ['không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];

String _readUnder100(int n, {required bool hasHundred}) {
  if (n < 10) {
    return hasHundred ? 'linh ${_digits[n]}' : _digits[n];
  }
  if (n == 10) return 'mười';
  if (n < 20) {
    final u = n % 10;
    return 'mười ${u == 5 ? 'lăm' : _digits[u]}';
  }
  final t = n ~/ 10;
  final u = n % 10;
  final head = '${_digits[t]} mươi';
  if (u == 0) return head;
  final tail = switch (u) { 1 => 'mốt', 5 => 'lăm', _ => _digits[u] };
  return '$head $tail';
}

String _readGroup(int n, {required bool full}) {
  // n trong 0..999. [full]: nhom khong phai nhom dau, phai doc "khong tram".
  final h = n ~/ 100;
  final r = n % 100;
  final parts = <String>[];
  if (h > 0) {
    parts.add('${_digits[h]} trăm');
  } else if (full && r > 0) {
    parts.add('không trăm');
  }
  if (r > 0) {
    parts.add(_readUnder100(r, hasHundred: h > 0 || full));
  }
  return parts.join(' ');
}

/// Doc so nguyen khong am: 380000 -> "ba trăm tám mươi nghìn".
String numberToSpoken(int n) {
  if (n == 0) return 'không';
  if (n < 0) return 'âm ${numberToSpoken(-n)}';
  const scales = ['', 'nghìn', 'triệu', 'tỷ'];
  final groups = <int>[];
  var rest = n;
  while (rest > 0) {
    groups.add(rest % 1000);
    rest ~/= 1000;
  }
  final parts = <String>[];
  for (var i = groups.length - 1; i >= 0; i--) {
    final g = groups[i];
    if (g == 0) continue;
    final isFirst = i == groups.length - 1;
    final scale = i < scales.length ? scales[i] : '';
    final text = _readGroup(g, full: !isFirst);
    parts.add(scale.isEmpty ? text : '$text $scale');
  }
  return parts.join(' ');
}

/// "ba trăm tám mươi nghìn đồng".
String moneyToSpoken(int vnd) => '${numberToSpoken(vnd)} đồng';

/// "hai cân rưỡi" / "năm trăm gam" tu gram.
String weightToSpoken(int gram) {
  if (gram < 1000) return '${numberToSpoken(gram)} gam';
  final kg = gram ~/ 1000;
  final rem = gram % 1000;
  if (rem == 0) return '${numberToSpoken(kg)} ký';
  if (rem == 500) return '${numberToSpoken(kg)} ký rưỡi';
  return '${numberToSpoken(kg)} ký ${numberToSpoken(rem)} gam';
}
