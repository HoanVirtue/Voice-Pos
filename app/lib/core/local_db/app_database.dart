import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Khach hang (ban sao local). `id` la Guid do client sinh.
/// Xoa mem: `isDeleted = true`, dong van giu lai de dong bo len server.
@DataClassName('CustomerRow')
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get alias => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}


/// Mon hang (ba chi, nac vai...). Gia/kg tinh bang dong.
@DataClassName('ProductRow')
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get alias => text().nullable()();
  IntColumn get pricePerKg => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Lo hang (con lon). `date` la ngay VN dang `yyyy-MM-dd`.
@DataClassName('BatchRow')
class Batches extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()();
  IntColumn get pigCount => integer().withDefault(const Constant(0))();
  IntColumn get liveWeightGram => integer().nullable()();
  IntColumn get carcassWeightGram => integer().nullable()();
  IntColumn get buyCost => integer().withDefault(const Constant(0))();
  IntColumn get otherCost => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Giao dich: ban / thu no / mua lon / chi khac / mang tien di. Moi cau noi mot dong.
@DataClassName('TransactionRow')
class Transactions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get occurredAt => dateTime()();

  /// `Sale` | `DebtPayment` | `BuyPig` | `Expense` | `CashOut`
  TextColumn get type => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get productId => text().nullable()();
  TextColumn get batchId => text().nullable()();
  IntColumn get weightGram => integer().nullable()();
  IntColumn get amount => integer().withDefault(const Constant(0))();
  IntColumn get paidAmount => integer().withDefault(const Constant(0))();
  TextColumn get rawText => text().nullable()();
  RealColumn get confidence => real().nullable()();
  TextColumn get note => text().nullable()();

  /// Duong dan file ghi am goc tren may (khong dong bo).
  TextColumn get audioPath => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Chot so ngay. Moi ngay (`date`) mot ban ghi chua xoa.
@DataClassName('DaySettlementRow')
class DaySettlements extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()();
  IntColumn get openingCash => integer().withDefault(const Constant(0))();
  IntColumn get countedCash => integer().withDefault(const Constant(0))();
  IntColumn get expectedCash => integer().withDefault(const Constant(0))();
  IntColumn get difference => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Hang doi thao tac chua day len server. Day theo thu tu `seq`.
@DataClassName('OutboxRow')
class OutboxEntries extends Table {
  IntColumn get seq => integer().autoIncrement()();

  /// Loai thuc the: `customer` | `product` | `batch` | `transaction` | `settlement`.
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// `create` | `update` | `delete`
  TextColumn get operation => text()();

  /// JSON anh chup thuc the tai thoi diem ghi.
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

/// Cap khoa-gia tri nho (moc keo `updatedSince`...).
@DataClassName('SyncMetaRow')
class SyncMeta extends Table {
  TextColumn get metaKey => text()();
  TextColumn get metaValue => text()();

  @override
  Set<Column> get primaryKey => {metaKey};
}

@DriftDatabase(tables: [
  Customers,
  Products,
  Batches,
  Transactions,
  DaySettlements,
  OutboxEntries,
  SyncMeta,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'banhang',
              // Web: cần sqlite3.wasm + drift_worker.js đặt trong app/web/ (khớp phiên bản drift/sqlite3 trong pubspec.lock).
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(products);
            await m.createTable(batches);
            await m.createTable(transactions);
            await m.createTable(daySettlements);
          }
        },
      );

  Future<String?> getMeta(String key) async {
    final row = await (select(syncMeta)..where((t) => t.metaKey.equals(key)))
        .getSingleOrNull();
    return row?.metaValue;
  }

  Future<void> setMeta(String key, String value) {
    return into(syncMeta).insertOnConflictUpdate(
      SyncMetaCompanion.insert(metaKey: key, metaValue: value),
    );
  }
}
