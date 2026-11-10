import 'package:dio/dio.dart';

import '../../features/batches/data/batch_model.dart';
import '../../features/batches/data/batch_repository.dart';
import '../../features/products/data/product_model.dart';
import '../../features/products/data/product_repository.dart';
import '../../features/settlements/data/settlement_model.dart';
import '../../features/settlements/data/settlement_repository.dart';
import '../../features/transactions/data/transaction_model.dart';
import '../../features/transactions/data/transaction_repository.dart';
import '../constants/app_constants.dart';
import 'entity_sync.dart';

EntitySyncer<Product> productSyncer(EntityRemote<Product> remote) => EntitySyncer<Product>(
      entityType: productEntityType,
      cursorKey: 'products.updatedSince',
      remote: remote,
      fromJson: Product.fromJson,
      localUpdatedAt: (db, id) async =>
          (await (db.select(db.products)..where((t) => t.id.equals(id))).getSingleOrNull())?.updatedAt,
      applyLocal: (db, e) => db.into(db.products).insertOnConflictUpdate(e.toCompanion()),
    );

EntitySyncer<PigBatch> batchSyncer(EntityRemote<PigBatch> remote) => EntitySyncer<PigBatch>(
      entityType: batchEntityType,
      cursorKey: 'batches.updatedSince',
      remote: remote,
      fromJson: PigBatch.fromJson,
      localUpdatedAt: (db, id) async =>
          (await (db.select(db.batches)..where((t) => t.id.equals(id))).getSingleOrNull())?.updatedAt,
      applyLocal: (db, e) => db.into(db.batches).insertOnConflictUpdate(e.toCompanion()),
    );

EntitySyncer<TransactionRecord> transactionSyncer(EntityRemote<TransactionRecord> remote) =>
    EntitySyncer<TransactionRecord>(
      entityType: transactionEntityType,
      cursorKey: 'transactions.updatedSince',
      remote: remote,
      fromJson: TransactionRecord.fromJson,
      localUpdatedAt: (db, id) async =>
          (await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull())?.updatedAt,
      // Giu duong dan file ghi am cua may nay (server khong luu).
      applyLocal: (db, e) async {
        final old = await (db.select(db.transactions)..where((t) => t.id.equals(e.id))).getSingleOrNull();
        final merged = TransactionRecord(
          id: e.id,
          occurredAt: e.occurredAt,
          type: e.type,
          customerId: e.customerId,
          productId: e.productId,
          batchId: e.batchId,
          weightGram: e.weightGram,
          amount: e.amount,
          paidAmount: e.paidAmount,
          rawText: e.rawText,
          confidence: e.confidence,
          note: e.note,
          audioPath: old?.audioPath,
          isDeleted: e.isDeleted,
          updatedAt: e.updatedAt,
        );
        await db.into(db.transactions).insertOnConflictUpdate(merged.toCompanion());
      },
    );

EntitySyncer<DaySettlement> settlementSyncer(EntityRemote<DaySettlement> remote) =>
    EntitySyncer<DaySettlement>(
      entityType: settlementEntityType,
      cursorKey: 'settlements.updatedSince',
      remote: remote,
      fromJson: DaySettlement.fromJson,
      localUpdatedAt: (db, id) async => (await (db.select(db.daySettlements)
                ..where((t) => t.id.equals(id)))
              .getSingleOrNull())
          ?.updatedAt,
      applyLocal: (db, e) => db.into(db.daySettlements).insertOnConflictUpdate(e.toCompanion()),
    );

/// Bo syncer that goi API qua [dio].
List<EntitySyncer> buildSyncers(Dio dio) => [
      productSyncer(RestEntityRemote<Product>(
          dio: dio, endpoint: AppConstants.productsEndpoint, fromJson: Product.fromJson)),
      batchSyncer(RestEntityRemote<PigBatch>(
          dio: dio, endpoint: AppConstants.batchesEndpoint, fromJson: PigBatch.fromJson)),
      transactionSyncer(RestEntityRemote<TransactionRecord>(
          dio: dio, endpoint: AppConstants.transactionsEndpoint, fromJson: TransactionRecord.fromJson)),
      settlementSyncer(RestEntityRemote<DaySettlement>(
          dio: dio, endpoint: AppConstants.settlementsEndpoint, fromJson: DaySettlement.fromJson)),
    ];
