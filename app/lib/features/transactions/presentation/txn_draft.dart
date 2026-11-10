import '../data/transaction_model.dart';
import '../data/txn_type.dart';
import '../parser/market_parser.dart';

/// Ban nhap giao dich dang duoc xem/sua tren the xac nhan (chua luu).
class TxnDraft {
  TxnType type;
  String? customerId;

  /// Ten khach nghe duoc nhung chua co trong danh ba.
  String? unmatchedCustomerName;
  List<String> ambiguousCustomerIds;
  String? productId;
  String? batchId;
  int? weightGram;
  int amount;
  int paidAmount;
  String? note;
  String? rawText;
  double? confidence;
  ParseLevel level;
  String? audioPath;
  DateTime? occurredAt;
  List<String> warnings;

  TxnDraft({
    this.type = TxnType.sale,
    this.customerId,
    this.unmatchedCustomerName,
    this.ambiguousCustomerIds = const [],
    this.productId,
    this.batchId,
    this.weightGram,
    this.amount = 0,
    int? paidAmount,
    this.note,
    this.rawText,
    this.confidence,
    this.level = ParseLevel.green,
    this.audioPath,
    this.occurredAt,
    this.warnings = const [],
  }) : paidAmount = paidAmount ?? amount;

  factory TxnDraft.fromParsed(ParsedUtterance p, {String? audioPath}) {
    final type = p.type ?? TxnType.sale;
    final amount = p.amount ?? 0;
    return TxnDraft(
      type: type,
      customerId: p.customerId,
      unmatchedCustomerName: p.customerId == null && !p.walkIn ? p.customerName : null,
      ambiguousCustomerIds: p.ambiguousCustomerIds,
      productId: (p.productId == null || p.productId!.isEmpty) ? null : p.productId,
      weightGram: p.weightGram,
      amount: amount,
      paidAmount: p.paidAmount ?? amount,
      note: p.pigCount == null ? null : '${p.pigCount} con',
      rawText: p.rawText,
      confidence: p.confidence,
      level: p.level,
      audioPath: audioPath,
      warnings: p.warnings,
    );
  }

  factory TxnDraft.fromRecord(TransactionRecord r) => TxnDraft(
        type: r.type,
        customerId: r.customerId,
        productId: r.productId,
        batchId: r.batchId,
        weightGram: r.weightGram,
        amount: r.amount,
        paidAmount: r.paidAmount,
        note: r.note,
        rawText: r.rawText,
        confidence: r.confidence,
        level: r.confidence == null
            ? ParseLevel.green
            : (r.confidence! >= 0.8 ? ParseLevel.green : ParseLevel.yellow),
        audioPath: r.audioPath,
        occurredAt: r.occurredAt,
      );
}
