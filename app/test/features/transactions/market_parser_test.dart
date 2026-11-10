import 'package:banhang_app/features/transactions/data/txn_type.dart';
import 'package:banhang_app/features/transactions/parser/market_parser.dart';
import 'package:banhang_app/features/transactions/parser/vn_spoken.dart';
import 'package:banhang_app/features/transactions/parser/vn_text.dart';
import 'package:flutter_test/flutter_test.dart';

const parser = MarketParser();

const cLan = ParserCustomer(id: 'c-lan', name: 'Cô Lan', alias: 'Lan bán rau');
const cHa = ParserCustomer(id: 'c-ha', name: 'Chị Hà', alias: 'Hà góc chợ');
const cTu = ParserCustomer(id: 'c-tu', name: 'Anh Tú', debt: 1500000);
const cHai = ParserCustomer(id: 'c-hai', name: 'Chị Hai');
const cBa = ParserCustomer(id: 'c-ba', name: 'Cô Ba');
const cNam = ParserCustomer(id: 'c-nam', name: 'Chú Nam');
const cLan2 = ParserCustomer(id: 'c-lan2', name: 'Chị Lan');

const customers = [cLan, cHa, cTu, cHai, cBa, cNam];

const products = [
  ParserProduct(id: 'p-bc', name: 'Ba chỉ', pricePerKg: 190000),
  ParserProduct(id: 'p-nv', name: 'Nạc vai', pricePerKg: 150000),
  ParserProduct(id: 'p-s', name: 'Sườn', pricePerKg: 180000),
  ParserProduct(id: 'p-x', name: 'Xương', pricePerKg: 60000),
  ParserProduct(id: 'p-cg', name: 'Chân giò', pricePerKg: 120000),
];

ParsedUtterance p(String s, {List<ParserCustomer>? c}) =>
    parser.parse(s, customers: c ?? customers, products: products);

/// Mot ca kiem thu: cau Whisper tra ve -> ket qua mong doi.
class Case {
  final String text;
  final TxnType type;
  final int? amount;
  final int? paid;
  final String? customer;
  final bool walkIn;
  final String? product;
  final int? weight;
  final ParseLevel? level;
  final int? pigCount;

  const Case(
    this.text,
    this.type,
    this.amount, {
    this.paid,
    this.customer,
    this.walkIn = false,
    this.product,
    this.weight,
    this.level,
    this.pigCount,
  });
}

const sale = TxnType.sale;

final cases = <Case>[
  // — Cau mau trong ke hoach —
  const Case('Cô Lan, ba chỉ, hai cân, ba trăm tám', sale, 380000,
      paid: 380000, customer: 'c-lan', product: 'p-bc', weight: 2000, level: ParseLevel.green),
  const Case('Cô Lan lấy hai cân ba chỉ, ba trăm tám, đưa tiền rồi', sale, 380000,
      paid: 380000, customer: 'c-lan', product: 'p-bc', weight: 2000, level: ParseLevel.green),
  const Case('Chị Hà góc chợ lấy cân rưỡi nạc vai, hai trăm, ghi nợ', sale, 200000,
      paid: 0, customer: 'c-ha', product: 'p-nv', weight: 1500, level: ParseLevel.green),
  const Case('Chị Hà, nạc vai, cân rưỡi, hai trăm, nợ', sale, 200000,
      paid: 0, customer: 'c-ha', product: 'p-nv', weight: 1500),
  const Case('Khách lẻ năm chục', sale, 50000, paid: 50000, walkIn: true, level: ParseLevel.green),
  const Case('Lẻ năm chục', sale, 50000, paid: 50000, walkIn: true, level: ParseLevel.green),
  const Case('Lẻ bảy mươi', sale, 70000, paid: 70000, walkIn: true),
  const Case('Anh Tú trả nợ một triệu', TxnType.debtPayment, 1000000,
      paid: 1000000, customer: 'c-tu', level: ParseLevel.green),
  const Case('Mang đi chợ mười lăm triệu', TxnType.cashOut, 15000000, level: ParseLevel.green),
  const Case('Mang đi mười lăm triệu', TxnType.cashOut, 15000000),
  const Case('Mua lợn chín triệu tám', TxnType.buyPig, 9800000, level: ParseLevel.green),
  const Case('Mua lợn mười một triệu hai', TxnType.buyPig, 11200000),
  const Case('Mang đi chợ mười lăm triệu mua hai con lợn', TxnType.cashOut, 15000000, pigCount: 2),
  const Case('Trả lái hai mươi triệu', TxnType.buyPig, 20000000),
  const Case('Chi năm trăm tiền đá', TxnType.expense, 500000, level: ParseLevel.green),
  const Case('Mua túi hai chục', TxnType.expense, 20000),
  const Case('Mua đá ba chục', TxnType.expense, 30000),

  // — Doc so tien —
  const Case('Cô Lan hai trăm rưỡi', sale, 250000, customer: 'c-lan'),
  const Case('Cô Lan ba cân hai, hai trăm ba mươi', sale, 230000, customer: 'c-lan', weight: 3200),
  const Case('Chị Hà một củ', sale, 1000000, customer: 'c-ha'),
  const Case('Chị Hà một lít', sale, 100000, customer: 'c-ha'),
  const Case('Cô Lan một triệu hai', sale, 1200000, customer: 'c-lan'),
  const Case('Cô Lan hai triệu rưỡi', sale, 2500000, customer: 'c-lan'),
  const Case('Cô Lan 380', sale, 380000, customer: 'c-lan'),
  const Case('Cô Lan 380k', sale, 380000, customer: 'c-lan'),
  const Case('Cô Lan 380 nghìn', sale, 380000, customer: 'c-lan'),
  const Case('Cô Lan ba trăm tám mươi nghìn', sale, 380000, customer: 'c-lan'),
  const Case('Cô Lan một triệu hai trăm năm mươi nghìn', sale, 1250000, customer: 'c-lan'),
  const Case('Cô Lan hai mươi lăm nghìn', sale, 25000, customer: 'c-lan'),
  const Case('Cô Lan một trăm linh năm nghìn', sale, 105000, customer: 'c-lan'),
  const Case('Cô Lan một trăm lẻ năm', sale, 105000, customer: 'c-lan'),
  const Case('Cô Lan ba trăm hai lăm', sale, 325000, customer: 'c-lan'),
  const Case('Cô Lan bốn trăm rưỡi', sale, 450000, customer: 'c-lan'),
  const Case('Cô Lan năm chục rưỡi', sale, 55000, customer: 'c-lan'),
  const Case('Cô Lan hai nghìn rưỡi', sale, 2500, customer: 'c-lan'),
  const Case('Cô Lan 1.200.000', sale, 1200000, customer: 'c-lan'),
  const Case('Cô Lan 380000', sale, 380000, customer: 'c-lan'),
  const Case('Anh Tú trả nợ 500', TxnType.debtPayment, 500000, customer: 'c-tu'),
  const Case('Anh Tú trả nợ một triệu rưỡi', TxnType.debtPayment, 1500000, customer: 'c-tu'),
  const Case('Mua lợn 9 triệu 8', TxnType.buyPig, 9800000),
  const Case('Mang đi 15 triệu', TxnType.cashOut, 15000000),

  // — Can nang —
  const Case('Cô Lan 2 cân ba chỉ 380', sale, 380000, customer: 'c-lan', product: 'p-bc', weight: 2000),
  const Case('Cô Lan 2,5 cân nạc vai 375', sale, 375000,
      customer: 'c-lan', product: 'p-nv', weight: 2500, level: ParseLevel.green),
  const Case('Cô Lan năm lạng ba chỉ chín mươi lăm nghìn', sale, 95000,
      customer: 'c-lan', product: 'p-bc', weight: 500, level: ParseLevel.green),
  const Case('Cô Lan 2 cân 380', sale, 380000, customer: 'c-lan', weight: 2000),
  const Case('Cô Lan hai cân ba chỉ ba trăm bảy mươi', sale, 370000,
      customer: 'c-lan', weight: 2000, level: ParseLevel.green),
  // Thieu tien: tinh tu can x gia, danh dau vang
  const Case('Cô Lan nửa cân ba chỉ', sale, 95000,
      customer: 'c-lan', product: 'p-bc', weight: 500, level: ParseLevel.yellow),
  const Case('Cô Lan hai cân ba chỉ', sale, 380000,
      customer: 'c-lan', product: 'p-bc', weight: 2000, level: ParseLevel.yellow),
  const Case('Cô Lan một cân hai ba chỉ', sale, 228000,
      customer: 'c-lan', product: 'p-bc', weight: 1200, level: ParseLevel.yellow),
  const Case('Cô Lan cân hai ba chỉ', sale, 228000, customer: 'c-lan', weight: 1200),
  const Case('Cô Lan ba cân ba chỉ', sale, 570000,
      customer: 'c-lan', product: 'p-bc', weight: 3000, level: ParseLevel.yellow),

  // — Tra / no —
  const Case('Cô Lan lấy ba trăm tám, trả hai trăm', sale, 380000, paid: 200000, customer: 'c-lan'),
  const Case('Cô Lan ba trăm tám nợ một trăm', sale, 380000, paid: 280000, customer: 'c-lan'),
  const Case('Cô Lan lấy nạc vai nợ hai trăm', sale, 200000, paid: 0, customer: 'c-lan'),
  const Case('Cô Lan ba trăm tám trả một nửa', sale, 380000, paid: 190000, customer: 'c-lan'),
  const Case('Chị Hà hai trăm, để đấy', sale, 200000, paid: 0, customer: 'c-ha'),
  const Case('Chị Hà hai trăm mai trả', sale, 200000, paid: 0, customer: 'c-ha'),
  const Case('Chị Hà hai trăm ghi sổ', sale, 200000, paid: 0, customer: 'c-ha'),
  const Case('Chị Hà hai trăm trả rồi', sale, 200000, paid: 200000, customer: 'c-ha'),
  const Case('Chị Hà hai trăm đưa tiền rồi', sale, 200000, paid: 200000, customer: 'c-ha'),
  const Case('Chị Hà hai trăm', sale, 200000, paid: 200000, customer: 'c-ha'),

  // — Ten khach —
  const Case('Cô Lan hai trăm', sale, 200000, customer: 'c-lan'),
  const Case('Lan hai trăm', sale, 200000, customer: 'c-lan'),
  const Case('Cô Ba hai cân ba chỉ ba trăm tám', sale, 380000,
      customer: 'c-ba', product: 'p-bc', weight: 2000, level: ParseLevel.green),
  const Case('Chị Hai lấy ba trăm', sale, 300000, customer: 'c-hai', level: ParseLevel.green),
  const Case('Chú Nam ba trăm', sale, 300000, customer: 'c-nam', level: ParseLevel.green),
  const Case('Anh Tú hai trăm', sale, 200000, customer: 'c-tu'),
  const Case('Cô Lan bán rau hai trăm', sale, 200000, customer: 'c-lan'),

  // — Khong dau (Whisper / go tay) —
  const Case('co lan hai tram ruoi', sale, 250000, customer: 'c-lan'),
  const Case('chi ha goc cho hai tram', sale, 200000, customer: 'c-ha'),
  const Case('lay hai can ba chi ba tram tam', sale, 380000, weight: 2000, product: 'p-bc'),
  const Case('chi nam tram tien da', TxnType.expense, 500000),
  const Case('mang di muoi lam trieu', TxnType.cashOut, 15000000),
  const Case('tra no anh tu mot trieu', TxnType.debtPayment, 1000000, customer: 'c-tu'),
  const Case('mua lon chin trieu tam', TxnType.buyPig, 9800000),
  const Case('le nam chuc', sale, 50000, walkIn: true),

  // — Ten chua co trong danh ba —
  const Case('Anh Minh ba trăm', sale, 300000, level: ParseLevel.green),
  const Case('Anh Minh ba trăm nợ', sale, 300000, paid: 0, level: ParseLevel.yellow),
  const Case('Anh Tư hai trăm', sale, 200000),
  const Case('Chị Hạnh hai trăm', sale, 200000),
  // Gan giong ten quen (Hà góc chợ): van gan khach do nhung danh dau vang.
  const Case('Chị Hạnh góc chợ hai trăm', sale, 200000, customer: 'c-ha', level: ParseLevel.yellow),

  // — Do tin cay —
  const Case('Cô Lan hai cân ba chỉ năm trăm', sale, 500000,
      customer: 'c-lan', weight: 2000, level: ParseLevel.yellow),
  const Case('Cô Lan bốn triệu', sale, 4000000, customer: 'c-lan', level: ParseLevel.yellow),
  const Case('Mang đi hai mươi triệu', TxnType.cashOut, 20000000, level: ParseLevel.green),

  // — Khong tim thay tien -> do —
  const Case('Cô Lan hai cân', sale, null, level: ParseLevel.red),
  const Case('Cô Lan ba chỉ', sale, null, level: ParseLevel.red),
  const Case('Cô Lan', sale, null, level: ParseLevel.red),
];

void main() {
  group('Cau mau -> ket qua', () {
    for (final c in cases) {
      test(c.text, () {
        final r = p(c.text);
        expect(r.kind, UtteranceKind.transaction, reason: '$r');
        expect(r.type, c.type, reason: '$r');
        expect(r.amount, c.amount, reason: '$r');
        if (c.paid != null) expect(r.paidAmount, c.paid, reason: '$r');
        if (c.customer != null) expect(r.customerId, c.customer, reason: '$r');
        expect(r.walkIn, c.walkIn, reason: '$r');
        if (c.product != null) expect(r.productId, c.product, reason: '$r');
        if (c.weight != null) expect(r.weightGram, c.weight, reason: '$r');
        if (c.level != null) expect(r.level, c.level, reason: '$r ${r.warnings}');
        if (c.pigCount != null) expect(r.pigCount, c.pigCount, reason: '$r');
      });
    }

    test('co it nhat 60 cau mau', () => expect(cases.length, greaterThanOrEqualTo(60)));

    test('khong co cau nao sai so tien ma van duoc danh xanh', () {
      for (final c in cases) {
        final r = p(c.text);
        if (r.level == ParseLevel.green) {
          expect(r.amount, c.amount, reason: c.text);
        }
      }
    });
  });

  group('Khach trung ten', () {
    test('"Lan" tro thanh khop hai khach -> vang, khong tu chon', () {
      final r = p('Lan lấy hai trăm nợ', c: [cLan, cLan2]);
      expect(r.customerId, isNull);
      expect(r.ambiguousCustomerIds, containsAll(['c-lan', 'c-lan2']));
      expect(r.level, ParseLevel.yellow);
      expect(r.amount, 200000);
    });

    test('noi ro "cô Lan" thi chon dung', () {
      expect(p('Cô Lan hai trăm', c: [cLan, cLan2]).customerId, 'c-lan');
    });

    test('noi ro "chị Lan" thi chon dung', () {
      expect(p('Chị Lan hai trăm', c: [cLan, cLan2]).customerId, 'c-lan2');
    });
  });

  group('Lenh xoa / sua', () {
    test('xoa cau vua roi', () {
      expect(p('Xóa câu vừa rồi').kind, UtteranceKind.deleteLast);
      expect(p('Xóa cái vừa rồi').kind, UtteranceKind.deleteLast);
      expect(p('bỏ câu vừa rồi').kind, UtteranceKind.deleteLast);
    });

    test('sua lai gom so tien va khach moi', () {
      final r = p('Sửa lại cô Lan ba trăm sáu');
      expect(r.kind, UtteranceKind.editLast);
      expect(r.amount, 360000);
      expect(r.customerId, 'c-lan');
    });

    test('sua chi so tien', () {
      final r = p('Sửa ba trăm sáu');
      expect(r.kind, UtteranceKind.editLast);
      expect(r.amount, 360000);
    });

    test('nham roi, so moi', () {
      final r = p('Nhầm rồi, ba trăm sáu');
      expect(r.kind, UtteranceKind.editLast);
      expect(r.amount, 360000);
    });
  });

  group('Thu nợ không rõ số tiền', () {
    test('"trả hết nợ" dùng số nợ hiện có của khách', () {
      final r = p('Anh Tú trả hết nợ');
      expect(r.type, TxnType.debtPayment);
      expect(r.amount, 1500000);
    });

    test('thu nợ không có khách -> vàng', () {
      final r = p('Trả nợ hai trăm');
      expect(r.type, TxnType.debtPayment);
      expect(r.customerId, isNull);
      expect(r.level, ParseLevel.yellow);
    });
  });

  group('Câu rỗng / lạ', () {
    test('câu rỗng -> không hiểu', () {
      expect(p('').kind, UtteranceKind.unknown);
      expect(p('   ').kind, UtteranceKind.unknown);
    });

    test('không có danh bạ, không có món vẫn đọc được tiền', () {
      final r = parser.parse('Cô Lan ba chỉ hai cân ba trăm tám');
      expect(r.amount, 380000);
      expect(r.weightGram, 2000);
    });
  });

  group('Doc lai bang giong', () {
    test('ban tra ngay', () {
      expect(describeForSpeech(p('Cô Lan, ba chỉ, hai cân, ba trăm tám')),
          'Cô Lan, ba trăm tám mươi nghìn đồng, đã trả');
    });

    test('ban no', () {
      expect(describeForSpeech(p('Chị Hà hai trăm nợ')),
          'Chị Hà, hai trăm nghìn đồng, nợ');
    });

    test('thu no', () {
      expect(describeForSpeech(p('Anh Tú trả nợ một triệu')),
          'Anh Tú trả nợ một triệu đồng');
    });

    test('khong hieu', () {
      expect(describeForSpeech(p('Cô Lan')), 'Chưa rõ, tối xem lại');
    });
  });

  group('numberToSpoken', () {
    final table = <int, String>{
      0: 'không',
      5: 'năm',
      10: 'mười',
      15: 'mười lăm',
      21: 'hai mươi mốt',
      25: 'hai mươi lăm',
      105: 'một trăm linh năm',
      380000: 'ba trăm tám mươi nghìn',
      1200000: 'một triệu hai trăm nghìn',
      105000: 'một trăm linh năm nghìn',
      1050000: 'một triệu không trăm năm mươi nghìn',
      15000000: 'mười lăm triệu',
      2000000000: 'hai tỷ',
    };
    table.forEach((n, s) => test('$n', () => expect(numberToSpoken(n), s)));

    test('trong luong', () {
      expect(weightToSpoken(1500), 'một ký rưỡi');
      expect(weightToSpoken(2000), 'hai ký');
      expect(weightToSpoken(500), 'năm trăm gam');
    });
  });

  group('parseMoneyText (o nhap tay)', () {
    final table = <String, int?>{
      '380': 380000,
      'ba trăm tám': 380000,
      '1,2 triệu': 1200000,
      '2 triệu rưỡi': 2500000,
      '1.200.000': 1200000,
      'abc': null,
      '': null,
    };
    table.forEach((s, v) => test('"$s"', () => expect(parseMoneyText(s), v)));
  });

  group('vn_text', () {
    test('bo dau', () {
      expect(removeAccents('Chị Hà góc chợ Đông'), 'chi ha goc cho dong');
    });
    test('do giong', () {
      expect(similarity('lan', 'lan'), 1);
      expect(similarity('lan', 'lam'), lessThan(0.7));
      expect(levenshtein('kitten', 'sitting'), 3);
    });
  });
}
