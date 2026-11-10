import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../features/customers/data/customer_repository.dart' show OutboxOp;
import '../constants/app_constants.dart';
import '../local_db/app_database.dart';
import '../network/api_response.dart';

/// Thuc the dong bo duoc (Id Guid do client sinh, xoa mem, `updatedAt` UTC).
abstract class SyncEntity {
  String get id;
  DateTime get updatedAt;
  bool get isDeleted;

  /// Anh chup day du (luu trong outbox).
  Map<String, dynamic> toJson();

  /// Body gui len `POST/PUT`.
  Map<String, dynamic> toUpsertBody();
}

/// Mot trang ket qua `GET`: `result = { items, pageIndex, totalPages, ... }`.
class EntityPage<T> {
  final List<T> items;
  final bool hasMore;

  const EntityPage({required this.items, required this.hasMore});

  factory EntityPage.fromResult(dynamic result, T Function(Map<String, dynamic>) fromJson) {
    if (result is! Map<String, dynamic>) return const EntityPage(items: [], hasMore: false);
    final raw = (result['items'] as List?) ?? const [];
    final items = raw.whereType<Map<String, dynamic>>().map(fromJson).toList();
    final pageIndex = (result['pageIndex'] as num?)?.toInt() ?? 1;
    final totalPages = (result['totalPages'] as num?)?.toInt() ?? 0;
    return EntityPage(items: items, hasMore: pageIndex < totalPages);
  }
}

/// Cong giao tiep voi API cua mot thuc the. Tach thanh interface de test.
abstract class EntityRemote<T extends SyncEntity> {
  Future<EntityPage<T>> list({DateTime? updatedSince, required int page, required int pageSize});
  Future<void> create(T entity);
  Future<void> update(T entity);
  Future<void> delete(String id);
}

/// Remote REST chung: `GET/POST <endpoint>`, `PUT/DELETE <endpoint>/{id}`.
class RestEntityRemote<T extends SyncEntity> implements EntityRemote<T> {
  final Dio _dio;
  final String endpoint;
  final T Function(Map<String, dynamic>) fromJson;

  RestEntityRemote({required Dio dio, required this.endpoint, required this.fromJson}) : _dio = dio;

  @override
  Future<EntityPage<T>> list({
    DateTime? updatedSince,
    required int page,
    required int pageSize,
  }) async {
    final response = await _dio.get(
      endpoint,
      queryParameters: {
        'pageIndex': page,
        'pageSize': pageSize,
        if (updatedSince != null) 'updatedSince': updatedSince.toUtc().toIso8601String(),
        'includeDeleted': true,
      },
    );
    final body = response.data;
    if (body is Map<String, dynamic>) {
      final parsed = ApiResponse<EntityPage<T>>.fromJson(
        body,
        (r) => EntityPage.fromResult(r, fromJson),
      );
      if (!parsed.success) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: parsed.message,
        );
      }
      return parsed.data ?? EntityPage<T>(items: const [], hasMore: false);
    }
    return EntityPage.fromResult(body, fromJson);
  }

  @override
  Future<void> create(T entity) async {
    await _dio.post(endpoint, data: entity.toUpsertBody());
  }

  @override
  Future<void> update(T entity) async {
    await _dio.put('$endpoint/${entity.id}', data: entity.toUpsertBody());
  }

  @override
  Future<void> delete(String id) async {
    await _dio.delete('$endpoint/$id');
  }
}

/// Day/keo mot loai thuc the. `SyncService` giu danh sach cac syncer.
class EntitySyncer<T extends SyncEntity> {
  final String entityType;
  final String cursorKey;
  final EntityRemote<T> remote;
  final T Function(Map<String, dynamic>) fromJson;

  /// Thoi diem sua gan nhat cua ban ghi local (null neu chua co).
  final Future<DateTime?> Function(AppDatabase db, String id) localUpdatedAt;

  /// Ghi (insert-or-update) mot ban ghi tu server vao local.
  final Future<void> Function(AppDatabase db, T entity) applyLocal;

  const EntitySyncer({
    required this.entityType,
    required this.cursorKey,
    required this.remote,
    required this.fromJson,
    required this.localUpdatedAt,
    required this.applyLocal,
  });

  /// Gui mot thao tac outbox. POST/PUT idempotent theo Id; `delete` gap 404 coi nhu xong.
  Future<void> push(OutboxRow row) async {
    final entity = fromJson(jsonDecode(row.payload) as Map<String, dynamic>);
    switch (row.operation) {
      case OutboxOp.delete:
        try {
          await remote.delete(entity.id);
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
        }
      case OutboxOp.create:
        await remote.create(entity);
      case OutboxOp.update:
        await remote.update(entity);
    }
  }

  /// Keo thay doi tu moc da luu. Ban ghi dang cho day len thi khong bi ghi de. Tra so ban ghi da ap.
  Future<int> pull(AppDatabase db) async {
    final cursorText = await db.getMeta(cursorKey);
    final since = cursorText == null ? null : DateTime.tryParse(cursorText);

    var page = 1;
    var applied = 0;
    DateTime? maxUpdated = since;
    while (true) {
      final result = await remote.list(
        updatedSince: since,
        page: page,
        pageSize: AppConstants.syncPageSize,
      );
      for (final item in result.items) {
        if (await _apply(db, item)) applied++;
        final u = item.updatedAt.toUtc();
        if (maxUpdated == null || u.isAfter(maxUpdated)) maxUpdated = u;
      }
      if (!result.hasMore || result.items.isEmpty) break;
      page++;
    }
    if (maxUpdated != null) {
      await db.setMeta(cursorKey, maxUpdated.toIso8601String());
    }
    return applied;
  }

  Future<bool> _apply(AppDatabase db, T item) async {
    final pending = await (db.select(db.outboxEntries)
          ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(item.id))
          ..limit(1))
        .get();
    if (pending.isNotEmpty) return false; // local dang cho day: local thang.

    final local = await localUpdatedAt(db, item.id);
    if (local != null && local.isAfter(item.updatedAt)) return false;

    await applyLocal(db, item);
    return true;
  }
}

/// Ghi local + them dong outbox trong MOT transaction.
Future<void> writeWithOutbox(
  AppDatabase db, {
  required String entityType,
  required SyncEntity entity,
  required String operation,
  required DateTime now,
  required Future<void> Function() writeLocal,
}) {
  return db.transaction(() async {
    await writeLocal();
    await db.into(db.outboxEntries).insert(
          OutboxEntriesCompanion.insert(
            entityType: entityType,
            entityId: entity.id,
            operation: operation,
            payload: jsonEncode(entity.toJson()),
            createdAt: now,
          ),
        );
  });
}

int jsonInt(dynamic v, [int fallback = 0]) => v is num ? v.round() : (int.tryParse('$v') ?? fallback);

int? jsonIntOrNull(dynamic v) => v == null ? null : jsonInt(v);

String? jsonStrOrNull(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

DateTime jsonUtc(dynamic v) =>
    DateTime.tryParse(v?.toString() ?? '')?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
