// Bo phan tich cau noi tieng cho (quy tac, khong dung AI tra phi). Thuan Dart, khong phu thuoc Flutter.
//
// Cach noi quy uoc: [Ten khach] - [mon] - [so can] - [so tien] - [no].
// Quy uoc tien khi noi: don vi ngam la NGHIN dong ("ba tram tam" = 380.000d); "trieu", "cu" = trieu;
// "lit" = tram nghin; "chuc" = muoi nghin; "ruong" = them nua don vi ngay truoc.

import '../data/txn_type.dart';
import 'vn_spoken.dart';
import 'vn_text.dart';

// ─── Kieu du lieu vao/ra ─────────────────────────────────────────────────────

class ParserCustomer {
  final String id;
  final String name;
  final String? alias;

  /// So no hien tai neu biet (de hieu "tra het no").
  final int? debt;

  const ParserCustomer({required this.id, required this.name, this.alias, this.debt});
}

class ParserProduct {
  final String id;
  final String name;
  final String? alias;
  final int pricePerKg;

  const ParserProduct({
    required this.id,
    required this.name,
    this.alias,
    this.pricePerKg = 0,
  });
}

enum UtteranceKind { transaction, deleteLast, editLast, unknown }

/// Xanh = da hieu, vang = chua chac (xem lai), do = khong hieu.
enum ParseLevel { green, yellow, red }

class ParsedUtterance {
  final String rawText;
  final UtteranceKind kind;
  final TxnType? type;

  final String? customerId;
  final String? customerName;

  /// Khach le (khong ten).
  final bool walkIn;

  /// Khop tu 2 khach tro len (khong chon duoc).
  final List<String> ambiguousCustomerIds;

  final String? productId;
  final String? productName;
  final int? weightGram;
  final int? amount;
  final int? paidAmount;
  final int? pigCount;
  final double confidence;
  final ParseLevel level;
  final List<String> warnings;

  const ParsedUtterance({
    required this.rawText,
    required this.kind,
    this.type,
    this.customerId,
    this.customerName,
    this.walkIn = false,
    this.ambiguousCustomerIds = const [],
    this.productId,
    this.productName,
    this.weightGram,
    this.amount,
    this.paidAmount,
    this.pigCount,
    this.confidence = 0,
    this.level = ParseLevel.red,
    this.warnings = const [],
  });

  int? get debtAmount =>
      (amount == null || paidAmount == null) ? null : amount! - paidAmount!;

  ParsedUtterance withKind(UtteranceKind k, String raw) => ParsedUtterance(
        rawText: raw,
        kind: k,
        type: type,
        customerId: customerId,
        customerName: customerName,
        walkIn: walkIn,
        ambiguousCustomerIds: ambiguousCustomerIds,
        productId: productId,
        productName: productName,
        weightGram: weightGram,
        amount: amount,
        paidAmount: paidAmount,
        pigCount: pigCount,
        confidence: confidence,
        level: level,
        warnings: warnings,
      );

  @override
  String toString() =>
      'Parsed($kind $type kh=${customerName ?? customerId}${walkIn ? ' le' : ''} '
      'mon=$productName kg=$weightGram tien=$amount tra=$paidAmount $level ${confidence.toStringAsFixed(2)})';
}

// ─── Tu vung ─────────────────────────────────────────────────────────────────

const _rawDigit = <String, int>{
  'một': 1, 'mốt': 1, 'hai': 2, 'ba': 3, 'bốn': 4, 'tư': 4, 'năm': 5, 'lăm': 5,
  'sáu': 6, 'bảy': 7, 'bẩy': 7, 'tám': 8, 'chín': 9,
};
const _plainDigit = <String, int>{
  'mot': 1, 'hai': 2, 'ba': 3, 'bon': 4, 'tu': 4, 'nam': 5, 'lam': 5,
  'sau': 6, 'bay': 7, 'tam': 8, 'chin': 9,
};
const _rawScale = <String, double>{
  'nghìn': 1e3, 'ngàn': 1e3, 'triệu': 1e6, 'củ': 1e6, 'tỷ': 1e9, 'tỉ': 1e9,
  'chục': 1e4, 'lít': 1e5, 'k': 1e3, 'tr': 1e6,
};
const _plainScale = <String, double>{
  'nghin': 1e3, 'ngan': 1e3, 'trieu': 1e6, 'cu': 1e6, 'ty': 1e9, 'ti': 1e9,
  'chuc': 1e4, 'lit': 1e5, 'k': 1e3, 'tr': 1e6,
};
const _rawWeight = <String, double>{
  'cân': 1.0, 'ký': 1.0, 'kí': 1.0, 'kg': 1.0, 'kilo': 1.0, 'lạng': 0.1,
};
const _plainWeight = <String, double>{
  'can': 1.0, 'ky': 1.0, 'ki': 1.0, 'kg': 1.0, 'kilo': 1.0, 'lang': 0.1,
};

const _honorificRaw = {
  'cô', 'chị', 'anh', 'bác', 'chú', 'dì', 'cậu', 'mợ', 'ông', 'bà', 'em', 'thím', 'dượng',
};
const _honorificPlainUnmarked = {'co', 'anh', 'bac', 'chu', 'cau', 'ong', 'em', 'thim', 'chi'};
const _honorificPlainAll = {
  'co', 'chi', 'anh', 'bac', 'chu', 'di', 'cau', 'mo', 'ong', 'ba', 'em', 'thim', 'duong',
};

/// Tu bo nghia / khong tinh la "khong hieu".
const _knownPlain = {
  'lay', 'mua', 'ban', 'tra', 'no', 'ghi', 'dua', 'mang', 'di', 'chi', 'de', 'cho', 'roi',
  'lai', 'so', 'het', 'luon', 'thi', 'la', 'da', 'va', 'cua', 'voi', 'a', 'nhe', 'nha', 'nhi',
  'cai', 'cau', 'vua', 'tien', 'dong', 'd', 'mai', 'hom', 'nay', 'ngay', 'khach', 'them', 'nua',
  'con', 'bot', 'truoc', 'day', 'thu', 'nop', 'cam', 'dem', 'theo', 'nhap', 'lon', 'heo',
  'sau', 'mat', 'xoa', 'sua', 'nham', 'khong', 'ra', 'chua', 'thieu', 'it', 'nhieu',
  'ca', 'mot', 'cu', 'gia', 'tinh', 'ho', 'giup', 'dum', 'xin', 'oi', 'u',
};

/// Danh tu "mua <x>" / "tien <x>" -> chi khac.
const _expenseNouns = {
  'tui', 'da', 'muoi', 'nilon', 'nylon', 'day', 'xang', 'dau', 'bao', 'hop', 'nuoc', 'rau',
  'dien', 'cong', 'than', 'xe', 'gas', 'thung', 'khan', 'dao', 'thot', 'thue', 'mo', 'chuyen',
  'lam', 'an', 'com', 'bua', 'sang', 'cafe',
};

/// Ten mon tieng cho: khoa chinh -> cac cach goi khac (khong dau).
const _productSynonyms = <String, List<String>>{
  'ba chi': ['ba roi', 'thit ba chi', 'ba chi'],
  'nac vai': ['nac vai', 'thit vai'],
  'suon': ['suon non', 'suon'],
  'nac dam': ['nac dam'],
  'chan gio': ['chan gio', 'gio heo'],
  'mong': ['nac mong', 'mong'],
  'xuong': ['xuong ong', 'xuong'],
  'than': ['than lon', 'than'],
  'dui': ['dui'],
};

// ─── Token ───────────────────────────────────────────────────────────────────

class _Tok {
  final String raw;
  final String plain;
  final bool sepBefore;
  final double? numVal;
  final int? digit;
  final double? scale;
  final double? wFactor;
  final bool isTram;
  final bool isMuoi;
  final bool isLinh;
  final bool isLe;
  final bool isRuoi;
  final bool isNua;
  bool masked = false;

  _Tok._({
    required this.raw,
    required this.plain,
    required this.sepBefore,
    this.numVal,
    this.digit,
    this.scale,
    this.wFactor,
    this.isTram = false,
    this.isMuoi = false,
    this.isLinh = false,
    this.isLe = false,
    this.isRuoi = false,
    this.isNua = false,
  });

  factory _Tok.word(String raw, bool sepBefore) {
    final plain = removeAccents(raw);
    final unmarked = raw == plain;
    int? digit = _rawDigit[raw] ?? (unmarked ? _plainDigit[plain] : null);
    double? scale = _rawScale[raw] ?? (unmarked ? _plainScale[plain] : null);
    double? w = _rawWeight[raw] ?? (unmarked ? _plainWeight[plain] : null);
    return _Tok._(
      raw: raw,
      plain: plain,
      sepBefore: sepBefore,
      digit: digit,
      scale: scale,
      wFactor: w,
      isTram: raw == 'trăm' || (unmarked && plain == 'tram'),
      isMuoi: raw == 'mười' || raw == 'mươi' || (unmarked && plain == 'muoi'),
      isLinh: raw == 'linh' || (unmarked && plain == 'linh'),
      isLe: raw == 'lẻ' || (unmarked && plain == 'le'),
      isRuoi: raw == 'rưỡi' || raw == 'rưởi' || (unmarked && plain == 'ruoi'),
      isNua: raw == 'nửa' || (unmarked && plain == 'nua'),
    );
  }

  factory _Tok.number(String text, bool sepBefore) => _Tok._(
        raw: text,
        plain: text,
        sepBefore: sepBefore,
        numVal: _parseNumber(text),
      );

  bool get isNumberTok => numVal != null;

  static double _parseNumber(String s) {
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) return double.parse(s.replaceAll('.', ''));
    if (RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(s)) return double.parse(s.replaceAll(',', ''));
    final t = s.replaceAll(',', '.');
    final v = double.tryParse(t);
    if (v != null) return v;
    return double.tryParse(t.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }
}

List<_Tok> _lex(String text) {
  final re = RegExp(r'\d+(?:[.,]\d+)*|[\p{L}\p{M}]+|[,;.!?]', unicode: true);
  final toks = <_Tok>[];
  var sep = false;
  for (final m in re.allMatches(text.toLowerCase())) {
    final s = m.group(0)!;
    if (s == ',' || s == ';' || s == '.' || s == '!' || s == '?') {
      sep = true;
      continue;
    }
    if (RegExp(r'^\d').hasMatch(s)) {
      toks.add(_Tok.number(s, sep));
    } else {
      toks.add(_Tok.word(s, sep));
    }
    sep = false;
  }
  return toks;
}

// ─── Doc so ──────────────────────────────────────────────────────────────────

class _Group {
  final double value;
  final int next;
  final bool endedTram;
  final bool single;
  final bool digitTok;
  const _Group(this.value, this.next, {this.endedTram = false, this.single = false, this.digitTok = false});
}

int? _small(List<_Tok> r, int j) {
  if (j >= r.length) return null;
  final t = r[j];
  if (t.digit != null) return t.digit;
  final v = t.numVal;
  if (v != null && v >= 1 && v <= 9 && v == v.roundToDouble()) return v.round();
  return null;
}

_Group? _readGroup(List<_Tok> r, int i) {
  if (i >= r.length) return null;
  final t = r[i];
  if (t.isMuoi) {
    var v = 10.0;
    var j = i + 1;
    final d = _small(r, j);
    if (d != null) {
      v += d;
      j++;
    }
    return _Group(v, j);
  }
  final d = _small(r, i);
  if (d != null) {
    if (i + 1 < r.length && r[i + 1].isTram) {
      var v = d * 100.0;
      var j = i + 2;
      var ended = true;
      if (j < r.length && (r[j].isLinh || r[j].isLe) && _small(r, j + 1) != null) {
        v += _small(r, j + 1)!;
        j += 2;
        ended = false;
      } else if (j < r.length && r[j].isMuoi) {
        v += 10;
        j++;
        final d3 = _small(r, j);
        if (d3 != null) {
          v += d3;
          j++;
        }
        ended = false;
      } else {
        final d2 = _small(r, j);
        if (d2 != null) {
          if (j + 1 < r.length && r[j + 1].isMuoi) {
            v += d2 * 10;
            j += 2;
            final d3 = _small(r, j);
            if (d3 != null) {
              v += d3;
              j++;
            }
          } else {
            final d3 = _small(r, j + 1);
            final blocked = j + 2 < r.length && (r[j + 2].isTram || r[j + 2].isMuoi);
            if (d3 != null && !blocked) {
              v += d2 * 10 + d3;
              j += 2;
            } else {
              v += d2 * 10; // "ba tram tam" = 380
              j += 1;
            }
          }
          ended = false;
        }
      }
      return _Group(v, j, endedTram: ended);
    }
    if (i + 1 < r.length && r[i + 1].isMuoi) {
      var v = d * 10.0;
      var j = i + 2;
      final d2 = _small(r, j);
      if (d2 != null) {
        v += d2;
        j++;
      }
      return _Group(v, j);
    }
    return _Group(d.toDouble(), i + 1, single: true, digitTok: t.isNumberTok);
  }
  if (t.isNumberTok) {
    return _Group(t.numVal!, i + 1, digitTok: true);
  }
  return null;
}

class _Val {
  final double? vnd;
  final double? plain;
  const _Val({this.vnd, this.plain});
}

/// Gia tri tien (dong) cua mot cum so; hoac so tron nho (<10) neu khong co don vi.
_Val? _evalRun(List<_Tok> r) {
  double total = 0;
  double? lastUnit;
  var i = 0;
  while (i < r.length) {
    final t = r[i];
    if (t.isRuoi) {
      if (lastUnit == null) return null;
      total += lastUnit / 2;
      lastUnit = lastUnit / 2;
      i++;
      continue;
    }
    final g = _readGroup(r, i);
    if (g == null) return null;
    i = g.next;
    if (i < r.length && r[i].scale != null) {
      total += g.value * r[i].scale!;
      lastUnit = r[i].scale;
      i++;
    } else if (lastUnit == null) {
      if (total == 0 && g.value < 10 && (g.single || g.digitTok)) {
        if (i == r.length) return _Val(plain: g.value);
        if (r[i].isRuoi && i + 1 == r.length) return _Val(plain: g.value + 0.5);
      }
      final mult = (g.digitTok && g.value >= 10000) ? 1.0 : 1000.0;
      total += g.value * mult;
      lastUnit = g.endedTram ? 100 * mult : mult;
    } else if (g.single) {
      total += g.value * lastUnit / 10;
      lastUnit = lastUnit / 10;
    } else {
      final mult = lastUnit >= 1e6 ? 1000.0 : (lastUnit == 1e3 ? 1.0 : 1000.0);
      total += g.value * mult;
      lastUnit = g.endedTram ? 100 * mult : mult;
    }
  }
  return _Val(vnd: total);
}

/// Doc mot cum so tieng Viet / chu so tu chuoi (tien, dong). Tien ich cho o nhap tay: "380", "ba tram tam", "1,2 trieu".
/// Tra null neu khong doc duoc. So tron <10 khong don vi coi la nghin (khac luc dang noi lan voi can).
int? parseMoneyText(String text) {
  final toks = _lex(text);
  if (toks.isEmpty) return null;
  final v = _evalRun(toks);
  if (v == null) return null;
  if (v.vnd != null) return v.vnd!.round();
  if (v.plain != null) return (v.plain! * 1000).round();
  return null;
}

// ─── Bo phan tich ────────────────────────────────────────────────────────────

class _Span {
  final int start;
  final int end; // exclusive
  final int vnd;
  const _Span(this.start, this.end, this.vnd);
}

class _CustCand {
  final ParserCustomer customer;
  final List<String> tokens;
  final bool stripped;
  final String? honor;

  /// Ten day du bat dau bang xung ho: tu dau phai khop tuyet doi ("chu" khac "chi").
  final bool honorExact;
  const _CustCand(this.customer, this.tokens, this.stripped, this.honor, {this.honorExact = false});
}

class _Match {
  final int start;
  final int len;
  final double sim;
  const _Match(this.start, this.len, this.sim);
}

class MarketParser {
  const MarketParser();

  ParsedUtterance parse(
    String text, {
    List<ParserCustomer> customers = const [],
    List<ParserProduct> products = const [],
  }) =>
      _Run(text, customers, products).run();
}

class _Run {
  final String text;
  final List<ParserCustomer> customers;
  final List<ParserProduct> products;
  late final List<_Tok> t;
  late final bool marks;
  final List<String> warnings = [];

  _Run(this.text, this.customers, this.products);

  ParsedUtterance _unknown() => ParsedUtterance(
        rawText: text,
        kind: UtteranceKind.unknown,
        confidence: 0,
        level: ParseLevel.red,
        warnings: const ['Không hiểu câu nói'],
      );

  ParsedUtterance run() {
    t = _lex(text);
    if (t.isEmpty) return _unknown();
    marks = t.any((e) => e.raw != e.plain);

    // ── Lenh xoa / sua giao dich gan nhat ──
    final first = t.first;
    final plainAll = t.map((e) => e.plain).join(' ');
    if (first.raw == 'xóa' || first.raw == 'xoá' || first.plain == 'xoa' || first.raw == 'hủy' ||
        first.raw == 'huỷ' ||
        plainAll.startsWith('bo cau') ||
        plainAll.startsWith('bo cai') ||
        plainAll.startsWith('bo giao dich')) {
      return ParsedUtterance(
        rawText: text,
        kind: UtteranceKind.deleteLast,
        confidence: 0.9,
        level: ParseLevel.green,
      );
    }
    if (first.plain == 'sua' || first.plain == 'nham') {
      var skip = 1;
      while (skip < t.length && const {'lai', 'roi', 'la'}.contains(t[skip].plain)) {
        skip++;
      }
      final rest = t.skip(skip).map((e) => e.raw).join(' ');
      final inner = _Run(rest, customers, products).run();
      return inner.withKind(UtteranceKind.editLast, text);
    }

    // ── Co hieu loai giao dich (tinh truoc khi che token) ──
    bool has(List<String> seq) {
      for (var i = 0; i + seq.length <= t.length; i++) {
        var ok = true;
        for (var k = 0; k < seq.length; k++) {
          if (t[i + k].plain != seq[k]) {
            ok = false;
            break;
          }
        }
        if (ok) return true;
      }
      return false;
    }

    bool hasTok(String p) => t.any((e) => e.plain == p);

    final isDebtPay = has(['tra', 'no']) || has(['thu', 'no']) || has(['tra', 'tien', 'no']) ||
        has(['nop', 'no']) || has(['dua', 'no']) || has(['tra', 'het', 'no']) ||
        has(['tra', 'bot', 'no']) || has(['gui', 'no']);
    final isCashOut = has(['mang', 'di']) || has(['mang', 'tien', 'di']) || has(['di', 'cho']) ||
        has(['cam', 'di']) || has(['dem', 'di']) || has(['mang', 'theo']) || has(['mang', 'tien', 'theo']);
    final pigWord = hasTok('lon') || hasTok('heo');
    final isBuyPig = ((hasTok('mua') || hasTok('nhap')) && pigWord) ||
        has(['tra', 'lai']) || has(['mua', 'con']) || has(['mua', 'nguyen', 'con']);

    // ── Khach le ──
    var walkIn = false;
    for (var i = 0; i < t.length; i++) {
      if (t[i].isLe && (i == 0 || t[i - 1].plain == 'khach')) {
        t[i].masked = true;
        if (i > 0 && t[i - 1].plain == 'khach') t[i - 1].masked = true;
        walkIn = true;
        break;
      }
    }
    // "khach le" khi "le" khong o dau cau nhung dung sau "khach" da xu ly o tren.

    // ── Khach quen ──
    String? customerId;
    String? customerName;
    var ambiguous = <String>[];
    var lowSim = false;
    var unmatchedName = false;
    ParserCustomer? matchedCustomer;
    if (!walkIn) {
      final res = _matchCustomers();
      if (res != null) {
        ambiguous = res.ambiguous;
        lowSim = res.sim < 0.9;
        if (ambiguous.isEmpty) {
          matchedCustomer = res.customer;
          customerId = res.customer.id;
          customerName = res.customer.name;
        }
      } else {
        final name = _extractHonorificName();
        if (name != null) {
          customerName = name;
          unmatchedName = true;
        }
      }
    }
    final hasCustomerRef = walkIn || customerId != null || customerName != null || ambiguous.isNotEmpty;

    // ── Mon ──
    String? productId;
    String? productName;
    int productPrice = 0;
    final prod = _matchProduct();
    if (prod != null) {
      productId = prod.id;
      productName = prod.name;
      productPrice = prod.price;
    }

    // ── So con lon (mua N con lon) ──
    int? pigCount;
    if (pigWord || isBuyPig || isCashOut) {
      for (var i = 1; i < t.length; i++) {
        if (t[i].plain == 'con' && !t[i].masked && !t[i - 1].masked) {
          var s = i - 1;
          while (s - 1 >= 0 && i - (s - 1) <= 3 && !t[s - 1].masked && _isCountTok(t[s - 1]) && !t[s].sepBefore) {
            s--;
          }
          for (var from = s; from < i; from++) {
            final g = _readGroup(t.sublist(from, i), 0);
            if (g != null && g.next == i - from) {
              pigCount = g.value.round();
              for (var k = from; k <= i; k++) {
                t[k].masked = true;
              }
              break;
            }
          }
          if (pigCount != null) break;
        }
      }
    }

    // ── Can nang ──
    int? weightGram;
    {
      var found = 0;
      for (var k = 0; k < t.length; k++) {
        final u = t[k];
        if (u.masked || u.wFactor == null) continue;
        // Don vi can phai di kem so / "ruoi" / "nua" hoac dung mot minh o dau cum.
        final w = _readWeight(k);
        if (w == null) continue;
        found++;
        if (found == 1) {
          weightGram = (w * 1000).round();
        }
      }
      if (found > 1) warnings.add('Có nhiều khối lượng trong một câu');
    }

    // ── Tien ──
    final spans = _moneySpans();
    var weightFromPlain = false;
    // So tron nho (<10) khong don vi: coi la can neu chua co can.
    final moneySpans = <_Span>[];
    for (final s in spans) {
      if (s.vnd < 0) {
        // danh dau so tron nho: vnd = -(gia tri*1000)
        if (weightGram == null) {
          weightGram = (-s.vnd).round();
          weightFromPlain = true;
          for (var k = s.start; k < s.end; k++) {
            t[k].masked = true;
          }
        }
        continue;
      }
      moneySpans.add(s);
    }
    for (final s in moneySpans) {
      for (var k = s.start; k < s.end; k++) {
        t[k].masked = true;
      }
    }

    // ── Chon loai giao dich ──
    final cus = hasCustomerRef;
    var typeGuess = false;
    TxnType type;
    final expenseChi = _hasExpenseChi();
    final expenseNoun = _hasExpenseNoun();
    if (isDebtPay) {
      type = TxnType.debtPayment;
    } else if (isCashOut) {
      type = TxnType.cashOut;
    } else if (isBuyPig) {
      type = TxnType.buyPig;
    } else if (expenseChi || expenseNoun) {
      type = TxnType.expense;
    } else if (hasTok('tra') &&
        cus &&
        weightGram == null &&
        productId == null &&
        prod == null &&
        !hasTok('lay') &&
        !hasTok('mua') &&
        !hasTok('ban') &&
        !has(['tra', 'roi']) &&
        !has(['tra', 'het']) &&
        !has(['mai', 'tra']) &&
        !has(['tra', 'sau']) &&
        !has(['chua', 'tra'])) {
      type = TxnType.debtPayment;
      typeGuess = true;
    } else if (hasTok('mua') && !cus && prod == null && weightGram == null) {
      type = TxnType.expense;
      typeGuess = true;
    } else {
      type = TxnType.sale;
    }

    // ── Trang thai tra / no ──
    final debtWord = has(['no']) && !isDebtPay ||
        has(['ghi', 'no']) || has(['ghi', 'so']) || has(['de', 'day']) || has(['mai', 'tra']) ||
        has(['mai', 'dua']) || has(['tra', 'sau']) || has(['chua', 'tra']) || has(['chua', 'dua']) ||
        has(['thieu']);
    final paidWord = has(['dua', 'roi']) || has(['tra', 'roi']) || has(['da', 'tra']) ||
        has(['da', 'dua']) || has(['tra', 'het']) || has(['dua', 'het']) || has(['tra', 'luon']) ||
        has(['dua', 'tien']) || has(['tra', 'tien']);
    var half = false;
    for (var i = 0; i + 1 < t.length; i++) {
      if (t[i].digit == 1 && t[i + 1].isNua) half = true;
    }
    if (!half && hasTok('nua') && (hasTok('tra') || hasTok('no') || hasTok('dua'))) {
      // "tra nua" / "no nua" (khong co "mot")
      half = t.any((e) => e.isNua && !e.masked);
    }

    // ── Phan loai cac khoan tien theo tu dan truoc ──
    final amountSpans = <_Span>[];
    final paidSpans = <_Span>[];
    final debtSpans = <_Span>[];
    for (final s in moneySpans) {
      final p1 = _prevWord(s.start, 1);
      final p2 = _prevWord(s.start, 2);
      if (type == TxnType.sale && (p1 == 'no' || (p1 == 'con' && p2 == 'no') || (p1 == 'so' && p2 == 'ghi') ||
          (p1 == 'thieu'))) {
        debtSpans.add(s);
      } else if (type == TxnType.sale &&
          (p1 == 'tra' || p1 == 'dua' || (p2 == 'tra' && p1 == 'truoc') || (p2 == 'dua' && p1 == 'truoc') ||
              (p2 == 'da' && (p1 == 'tra' || p1 == 'dua')))) {
        paidSpans.add(s);
      } else {
        amountSpans.add(s);
      }
    }

    int? amount;
    int? paid;
    var derived = false;
    if (amountSpans.isNotEmpty) {
      amount = amountSpans.first.vnd;
      if (amountSpans.length > 1 && amountSpans.any((e) => e.vnd != amount)) {
        warnings.add('Có nhiều số tiền khác nhau');
        _conflict = true;
      }
    } else if (paidSpans.isNotEmpty && debtSpans.isNotEmpty) {
      amount = paidSpans.first.vnd + debtSpans.first.vnd;
    } else if (paidSpans.isNotEmpty) {
      amount = paidSpans.first.vnd;
    } else if (debtSpans.isNotEmpty) {
      amount = debtSpans.first.vnd;
    }

    if (amount == null && type == TxnType.debtPayment && matchedCustomer?.debt != null && matchedCustomer!.debt! > 0 &&
        (has(['het']) || has(['tat', 'ca']))) {
      amount = matchedCustomer.debt;
    }

    if (amount == null && type == TxnType.sale && weightGram != null && productPrice > 0) {
      amount = (weightGram * productPrice / 1000).round();
      derived = true;
    }

    // Tien da tra
    if (amount != null) {
      if (type != TxnType.sale) {
        paid = amount;
      } else if (paidSpans.isNotEmpty && amountSpans.isNotEmpty) {
        paid = paidSpans.first.vnd;
      } else if (debtSpans.isNotEmpty && (amountSpans.isNotEmpty)) {
        paid = amount - debtSpans.first.vnd;
      } else if (debtSpans.isNotEmpty && paidSpans.isEmpty) {
        paid = 0; // "nợ hai trăm": toàn bộ là nợ
      } else if (half) {
        paid = amount ~/ 2;
      } else if (debtWord && !paidWord) {
        paid = 0;
      } else {
        paid = amount;
      }
      if (paid < 0) paid = 0;
      if (paid > amount) {
        warnings.add('Tiền trả lớn hơn tiền hàng');
        paid = amount;
      }
    }

    // ── Do tin cay ──
    var conf = 0.95;
    final notes = <String>[];
    void pen(double v, String why) {
      conf -= v;
      notes.add(why);
    }

    if (amount == null) {
      warnings.add('Không tìm thấy số tiền');
    }
    if (derived) pen(0.3, 'Tiền tính từ cân × giá, chưa nghe thấy số tiền');
    if (ambiguous.isNotEmpty) pen(0.4, 'Có nhiều khách trùng tên');
    if (unmatchedName && type == TxnType.sale) pen(0.1, 'Chưa có khách này trong danh bạ');
    if (lowSim) pen(0.15, 'Tên khách nghe chưa rõ');
    final debtLike = (type == TxnType.sale && paid != null && amount != null && paid < amount) ||
        type == TxnType.debtPayment;
    if (debtLike && customerId == null) {
      pen(0.45, type == TxnType.debtPayment ? 'Thu nợ nhưng không rõ khách' : 'Ghi nợ nhưng không rõ khách');
    }
    if (typeGuess) pen(0.2, 'Đoán loại giao dịch');
    if (_conflict) pen(0.2, 'Nhiều số tiền');
    if (type == TxnType.sale && amount != null && weightGram != null && productPrice > 0 && !derived) {
      final exp = weightGram * productPrice / 1000;
      if (exp > 0 && (amount - exp).abs() / exp > 0.2) {
        pen(0.3, 'Tiền lệch hơn 20% so với cân × giá');
      }
    }
    if (type == TxnType.sale && amount != null && amount > 3000000) pen(0.25, 'Số tiền lớn bất thường');
    if (weightFromPlain) pen(0.1, 'Số nhỏ không đơn vị, tạm hiểu là cân');
    if (warnings.contains('Có nhiều khối lượng trong một câu')) pen(0.2, 'Nhiều món');
    final unknown = _countUnknown();
    if (unknown >= 5) {
      pen(0.35, 'Nhiều từ không hiểu');
    } else if (unknown >= 3) {
      pen(0.2, 'Còn từ không hiểu');
    }
    warnings.addAll(notes);

    final level = amount == null
        ? ParseLevel.red
        : conf >= 0.8
            ? ParseLevel.green
            : ParseLevel.yellow; // co so tien thi toi thieu la vang (xem lai), khong do
    if (amount == null) conf = conf.clamp(0.0, 0.3);

    return ParsedUtterance(
      rawText: text,
      kind: UtteranceKind.transaction,
      type: type,
      customerId: customerId,
      customerName: customerName,
      walkIn: walkIn,
      ambiguousCustomerIds: ambiguous,
      productId: productId,
      productName: productName,
      weightGram: weightGram,
      amount: amount,
      paidAmount: paid,
      pigCount: pigCount,
      confidence: conf.clamp(0.0, 1.0),
      level: level,
      warnings: warnings,
    );
  }

  bool _conflict = false;

  // ─── Khach ────────────────────────────────────────────────────────────────

  bool _isHonorific(int i) {
    final k = t[i];
    if (k.masked) return false;
    if (_honorificRaw.contains(k.raw)) {
      // "bà"/"dì" co dau: chac chan.
      return true;
    }
    if (marks) {
      // Cau co dau: chi tu khong dau "co/anh/..." (khong phai chi/ba/di) moi la xung ho.
      if (k.raw == k.plain && _honorificPlainUnmarked.contains(k.plain) && k.plain != 'chi') {
        return i + 1 < t.length;
      }
      return false;
    }
    if (_honorificPlainUnmarked.contains(k.plain)) {
      if (k.plain == 'chi') {
        // "chi nam tram" la chi tien; "chi ha lay ..." la chi Ha.
        if (i + 1 >= t.length) return false;
        final n = t[i + 1];
        if (n.numVal != null || n.digit != null || n.isMuoi || n.plain == 'tien') return false;
        return true;
      }
      return i + 1 < t.length;
    }
    return false;
  }

  bool _hasExpenseChi() {
    for (var i = 0; i < t.length; i++) {
      final k = t[i];
      if (k.masked) continue;
      if (k.raw == 'chi') {
        if (!_isHonorific(i)) return true;
      }
    }
    return false;
  }

  bool _hasExpenseNoun() {
    for (var i = 0; i + 1 < t.length; i++) {
      if ((t[i].plain == 'mua' || t[i].plain == 'tien') && _expenseNouns.contains(t[i + 1].plain) && !t[i + 1].masked) {
        return true;
      }
    }
    return false;
  }

  bool _isCountTok(_Tok k) => k.digit != null || k.isMuoi || k.isNumberTok || k.isTram;

  String? _prevWord(int idx, int back) {
    var i = idx - 1;
    var n = 0;
    while (i >= 0) {
      if (!t[i].masked || t[i].plain == 'no' || t[i].plain == 'tra' || t[i].plain == 'dua') {
        n++;
        if (n == back) return t[i].plain;
      }
      i--;
    }
    return null;
  }

  ({ParserCustomer customer, double sim, List<String> ambiguous})? _matchCustomers() {
    if (customers.isEmpty) return null;
    final cands = <_CustCand>[];
    for (final c in customers) {
      for (final n in [c.name, if (c.alias != null && c.alias!.trim().isNotEmpty) c.alias!]) {
        final p = _plainWords(n);
        if (p.isEmpty) continue;
        cands.add(_CustCand(c, p, false, null,
            honorExact: p.length >= 2 && _honorificPlainAll.contains(p.first)));
        if (p.length >= 2 && _honorificPlainAll.contains(p.first)) {
          final rest = p.sublist(1);
          final single = rest.length == 1 && (_plainDigit.containsKey(rest[0]) || _knownPlain.contains(rest[0]));
          if (!single) cands.add(_CustCand(c, rest, true, p.first));
        }
      }
    }

    final best = <String, ({double score, _Match m, double sim})>{};
    for (final cand in cands) {
      final m = _bestWindow(cand.tokens, honorExact: cand.honorExact);
      if (m == null) continue;
      // Ten chi gom mot so/tu bo nghia: chi chap nhan o dau cau.
      if (cand.tokens.length == 1 &&
          (_plainDigit.containsKey(cand.tokens[0]) || _knownPlain.contains(cand.tokens[0])) &&
          m.start != 0) {
        continue;
      }
      var score = m.sim * (cand.stripped ? 0.95 : 1.0);
      if (cand.stripped && m.start > 0 && _isHonorific(m.start - 1)) {
        if (t[m.start - 1].plain != cand.honor) score -= 0.3;
      }
      if (score < 0.75) continue;
      final cur = best[cand.customer.id];
      if (cur == null || score > cur.score || (score == cur.score && m.len > cur.m.len)) {
        best[cand.customer.id] = (score: score, m: m, sim: m.sim);
      }
    }
    if (best.isEmpty) return null;

    final entries = best.entries.toList()
      ..sort((a, b) {
        final c = b.value.score.compareTo(a.value.score);
        return c != 0 ? c : b.value.m.len.compareTo(a.value.m.len);
      });
    final top = entries.first;
    final topM = top.value.m;
    final amb = <String>[];
    for (final e in entries.skip(1)) {
      final overlap = e.value.m.start < topM.start + topM.len && topM.start < e.value.m.start + e.value.m.len;
      if (overlap && e.value.score >= top.value.score - 0.06) amb.add(e.key);
    }

    for (var k = topM.start; k < topM.start + topM.len; k++) {
      t[k].masked = true;
    }
    if (topM.start > 0 && _isHonorific(topM.start - 1)) t[topM.start - 1].masked = true;

    final customer = customers.firstWhere((c) => c.id == top.key);
    return (
      customer: customer,
      sim: top.value.sim,
      ambiguous: amb.isEmpty ? const <String>[] : [top.key, ...amb],
    );
  }

  /// Khach chua co trong danh ba: lay "xung ho + ten" (them toi da vai tu).
  String? _extractHonorificName() {
    for (var i = 0; i + 1 < t.length; i++) {
      if (!_isHonorific(i)) continue;
      final n = t[i + 1];
      if (n.masked || n.sepBefore) continue;
      if (_isStop(n)) continue;
      final idx = <int>[i, i + 1];
      var j = i + 2;
      while (j < t.length && idx.length < 5) {
        final k = t[j];
        if (k.masked || k.sepBefore || _isStop(k) || _isNumericish(k) || k.wFactor != null) break;
        idx.add(j);
        j++;
      }
      for (final k in idx) {
        t[k].masked = true;
      }
      return idx.map((k) => _title(t[k].raw)).join(' ');
    }
    return null;
  }

  bool _isStop(_Tok k) {
    if (marks) return _knownRaw.contains(k.raw);
    return _knownPlain.contains(k.plain);
  }

  static const _knownRaw = {
    'lấy', 'mua', 'bán', 'trả', 'nợ', 'ghi', 'đưa', 'mang', 'chi', 'để', 'cho', 'rồi', 'lại', 'sổ',
    'hết', 'luôn', 'thì', 'là', 'đã', 'và', 'của', 'với', 'ạ', 'à', 'nhé', 'nha', 'nhỉ', 'cái',
    'câu', 'vừa', 'tiền', 'đồng', 'mai', 'hôm', 'nay', 'ngày', 'khách', 'thêm', 'nữa', 'còn',
    'bớt', 'trước', 'đây', 'thu', 'nộp', 'cầm', 'đem', 'nhập', 'lợn', 'heo', 'xóa', 'sửa', 'nhầm',
    'thiếu', 'chưa', 'mặt',
  };

  bool _isNumericish(_Tok k) =>
      k.numVal != null || k.digit != null || k.isMuoi || k.isTram || k.scale != null || k.isRuoi || k.isNua;

  String _title(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  List<String> _plainWords(String s) => _lex(s).map((e) => e.plain).toList();

  _Match? _bestWindow(List<String> cand, {double minSim = 0.8, bool honorExact = false}) {
    final skip = honorExact ? 1 : 0;
    final cs = cand.skip(skip).join(' ');
    _Match? best;
    for (final len in {cand.length, cand.length - 1, cand.length + 1}) {
      if (len < 1 + skip) continue;
      for (var s = 0; s + len <= t.length; s++) {
        var ok = true;
        for (var k = 0; k < len; k++) {
          final tk = t[s + k];
          if (tk.masked || (k > 0 && tk.sepBefore)) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        if (honorExact && t[s].plain != cand.first) continue;
        final ws = t.sublist(s + skip, s + len).map((e) => e.plain).join(' ');
        if (cs.length <= 3 && ws != cs) continue;
        final sim = similarity(ws, cs);
        if (sim < minSim) continue;
        if (best == null || sim > best.sim || (sim == best.sim && len > best.len)) {
          best = _Match(s, len, sim);
        }
      }
    }
    return best;
  }

  // ─── Mon ──────────────────────────────────────────────────────────────────

  ({String id, String name, int price})? _matchProduct() {
    // Tung cum ung vien: (tokens, mon trong danh muc hoac null).
    final cands = <({List<String> tokens, ParserProduct? product, String canonical})>[];
    for (final p in products) {
      for (final n in [p.name, if (p.alias != null && p.alias!.trim().isNotEmpty) p.alias!]) {
        final w = _plainWords(n);
        if (w.isNotEmpty) cands.add((tokens: w, product: p, canonical: p.name));
      }
      final key = removeAccents(p.name).trim();
      for (final e in _productSynonyms.entries) {
        if (key == e.key || key.contains(e.key)) {
          for (final syn in e.value) {
            cands.add((tokens: syn.split(' '), product: p, canonical: p.name));
          }
        }
      }
    }
    // Cac ten co san luon duoc che (de "ba chi" khong bi doc thanh so 3) du khong co trong danh muc.
    for (final e in _productSynonyms.entries) {
      for (final syn in e.value) {
        cands.add((tokens: syn.split(' '), product: null, canonical: e.key));
      }
    }

    ({int start, int len, double sim, ParserProduct? p, String canonical})? best;
    for (final c in cands) {
      final m = _bestWindow(c.tokens, minSim: 0.85);
      if (m == null) continue;
      // Ten mon mot tu qua ngan chi chap nhan khop tuyet doi.
      if (m.sim < 1 && c.tokens.join(' ').length < 5) continue;
      final better = best == null ||
          m.len > best.len ||
          (m.len == best.len && m.sim > best.sim) ||
          (m.len == best.len && m.sim == best.sim && best.p == null && c.product != null);
      if (better) {
        best = (start: m.start, len: m.len, sim: m.sim, p: c.product, canonical: c.canonical);
      }
    }
    if (best == null) return null;
    for (var k = best.start; k < best.start + best.len; k++) {
      t[k].masked = true;
    }
    if (best.p == null) {
      // Chi nhan ra ten tieng cho, chua co trong danh muc: tra ten (khong co id) de khong mat thong tin.
      return (id: '', name: _title(best.canonical), price: 0);
    }
    return (id: best.p!.id, name: best.p!.name, price: best.p!.pricePerKg);
  }

  // ─── Can nang ─────────────────────────────────────────────────────────────

  /// Doc khoi luong (kg) quanh don vi o chi so [k]; che cac token da dung. Null neu khong phai khoi luong.
  double? _readWeight(int k) {
    final unit = t[k];
    final factor = unit.wFactor!;
    // So truoc don vi.
    var num = 1.0;
    var start = k;
    var hasNum = false;
    for (var from = (k - 3 < 0 ? 0 : k - 3); from < k; from++) {
      var ok = true;
      for (var q = from; q < k; q++) {
        if (t[q].masked || (q > from && t[q].sepBefore) || !_isCountTok(t[q])) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      final g = _readGroup(t.sublist(from, k), 0);
      if (g != null && g.next == k - from) {
        num = g.value;
        start = from;
        hasNum = true;
        break;
      }
    }
    if (!hasNum && k > 0 && !t[k - 1].masked && t[k - 1].isNua && !unit.sepBefore) {
      num = 0.5;
      start = k - 1;
      hasNum = true;
    }
    // "ky" khong co so va khong co "ruoi" phia sau la mo ho voi chu viet tat: van coi la 1 don vi.
    var total = num * factor;
    var end = k + 1;
    if (end < t.length && !t[end].masked && !t[end].sepBefore) {
      final n = t[end];
      if (n.isRuoi) {
        total += 0.5 * factor;
        end++;
      } else {
        final d = _small(t, end);
        if (d != null && factor >= 1.0 && !(n.isNumberTok && n.numVal != n.numVal!.roundToDouble())) {
          final after = end + 1 < t.length ? t[end + 1] : null;
          final blocked = after != null &&
              !after.masked &&
              !after.sepBefore &&
              (after.isTram || after.isMuoi || after.scale != null || after.plain == 'con' || after.digit != null);
          if (!blocked) {
            total += d * factor / 10; // "ba can hai" = 3,2 kg
            end++;
          }
        }
      }
    }
    for (var q = start; q < end; q++) {
      t[q].masked = true;
    }
    return total;
  }

  // ─── Tien ─────────────────────────────────────────────────────────────────

  bool _numStarter(_Tok k) => k.numVal != null || k.digit != null || k.isMuoi;

  bool _numCont(int i, int runStart) {
    final k = t[i];
    if (k.masked) return false;
    if (i > runStart && k.sepBefore) return false;
    if (k.numVal != null || k.digit != null || k.isMuoi || k.isTram || k.isLinh) return true;
    if (k.scale != null) return i > runStart || k.plain != 'k' && k.plain != 'tr';
    if (k.isRuoi) return i > runStart;
    if (k.isLe) {
      return i > runStart && t[i - 1].isTram && i + 1 < t.length && t[i + 1].digit != null;
    }
    return false;
  }

  /// Cac khoan tien trong cau. So tron nho (<10) khong don vi tra ve vnd am (= -gram).
  List<_Span> _moneySpans() {
    final out = <_Span>[];
    var i = 0;
    while (i < t.length) {
      final k = t[i];
      if (k.masked || !_numStarter(k)) {
        i++;
        continue;
      }
      var j = i + 1;
      while (j < t.length && _numCont(j, i)) {
        j++;
      }
      // Bo "dong"/"d" theo sau.
      var end = j;
      if (end < t.length && !t[end].masked && (t[end].plain == 'dong' || t[end].plain == 'd')) end++;
      final run = t.sublist(i, j);
      final v = _evalRun(run);
      if (v != null) {
        if (v.vnd != null) {
          out.add(_Span(i, end, v.vnd!.round()));
        } else if (v.plain != null) {
          out.add(_Span(i, end, -(v.plain! * 1000).round()));
        }
      }
      i = end > i ? end : i + 1;
    }
    return out;
  }

  int _countUnknown() {
    var n = 0;
    for (final k in t) {
      if (k.masked) continue;
      if (_knownPlain.contains(k.plain) && (marks ? _knownRaw.contains(k.raw) || k.raw == k.plain : true)) continue;
      if (_isNumericish(k) || k.wFactor != null) continue;
      if (_honorificRaw.contains(k.raw)) continue;
      n++;
    }
    return n;
  }
}

// ─── Doc lai bang giong ──────────────────────────────────────────────────────

/// Cau doc lai ngan cho bo me: "Cô Lan, ba trăm tám mươi nghìn đồng, đã trả".
String describeForSpeech(ParsedUtterance p) {
  switch (p.kind) {
    case UtteranceKind.deleteLast:
      return 'Đã xóa giao dịch vừa rồi';
    case UtteranceKind.unknown:
      return 'Chưa rõ, tối xem lại';
    case UtteranceKind.editLast:
    case UtteranceKind.transaction:
      break;
  }
  if (p.amount == null) return 'Chưa rõ, tối xem lại';
  final who = p.customerName ?? (p.walkIn ? 'Khách lẻ' : null);
  final money = moneyToSpoken(p.amount!);
  final parts = <String>[];
  switch (p.type ?? TxnType.sale) {
    case TxnType.sale:
      if (who != null) parts.add(who);
      parts.add(money);
      final debt = p.debtAmount ?? 0;
      if (debt <= 0) {
        parts.add('đã trả');
      } else if (p.paidAmount == 0) {
        parts.add('nợ');
      } else {
        parts.add('nợ ${moneyToSpoken(debt)}');
      }
    case TxnType.debtPayment:
      parts.add('${who ?? 'Khách'} trả nợ $money');
    case TxnType.buyPig:
      parts.add('Mua lợn $money');
    case TxnType.expense:
      parts.add('Chi $money');
    case TxnType.cashOut:
      parts.add('Mang đi chợ $money');
  }
  if (p.level == ParseLevel.yellow) parts.add('cần xem lại');
  return parts.join(', ');
}
