import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../features/customers/data/customer_model.dart';
import '../../features/customers/data/customer_remote.dart';
import '../../features/customers/data/customer_repository.dart';
import '../constants/app_constants.dart';
import '../local_db/app_database.dart';
import 'entity_sync.dart';

enum SyncStatus { idle, syncing, offline, error }

class SyncResult {
  final int pushed;
  final int pulled;
  final bool completed;
  final String? error;

  const SyncResult({
    this.pushed = 0,
    this.pulled = 0,
    this.completed = true,
    this.error,
  });
}

/// Dong bo hai chieu giua local DB va server.
///
/// - Day: doc outbox theo `seq`, gui tung thao tac. Idempotent theo Id client
///   (BE tao-hoac-sua theo Id); `delete` gap 404 coi nhu da xong.
/// - Keo: `GET /Customers?updatedSince=<moc>&includeDeleted=true` theo trang, ap vao local. Ban ghi
///   dang co thao tac cho day thi KHONG bi ghi de (local thang cho toi khi day).
/// - Loi tam thoi (mat mang, 5xx, 401): dung lai, giu outbox, thu lai sau.
///   Loi 4xx khac: ghi `lastError`, tang `attempts`, bo qua (toi da
///   [AppConstants.outboxMaxAttempts] lan).
class SyncService {
  static const customersCursorKey = 'customers.updatedSince';

  /// Thu lai khi loi: 15s -> 30s -> 60s -> 2 phut -> 5 phut (toi da), reset khi thanh cong.
  static const defaultRetryDelays = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  final AppDatabase _db;
  final CustomerRemote _remote;

  /// Cac loai thuc the khac (mon, lo, giao dich, chot so) dong bo cung vong voi khach hang.
  final List<EntitySyncer> _syncers;
  final Connectivity? _connectivity;
  final Future<bool> Function()? _isOnlineOverride;

  /// Bang cho thu lai khi mot vong dong bo that bai (lui dan; phan tu cuoi lap lai).
  final List<Duration> _retryDelays;
  Timer? _retryTimer;
  int _retryIndex = 0;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Future<SyncResult>? _running;
  bool _rerun = false;
  bool _disposed = false;

  final _statusCtrl = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = SyncStatus.idle;

  SyncService({
    required AppDatabase db,
    required CustomerRemote remote,
    List<EntitySyncer> syncers = const [],
    Connectivity? connectivity,
    Future<bool> Function()? isOnline,
    List<Duration> retryDelays = defaultRetryDelays,
  })  : _retryDelays = retryDelays.isEmpty ? defaultRetryDelays : retryDelays,
        _db = db,
        _remote = remote,
        _syncers = syncers,
        _connectivity = connectivity,
        _isOnlineOverride = isOnline;

  SyncStatus get status => _status;
  Stream<SyncStatus> get statusStream => _statusCtrl.stream;

  /// Bat dau lang nghe mang va dong bo ngay mot lan.
  void start() {
    final c = _connectivity;
    if (c != null && _connSub == null) {
      _connSub = c.onConnectivityChanged.listen((results) {
        if (_hasNetwork(results)) {
          unawaited(syncNow());
        } else {
          _setStatus(SyncStatus.offline);
        }
      });
    }
    unawaited(syncNow());
  }

  static bool _hasNetwork(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);

  Future<bool> _isOnline() async {
    final override = _isOnlineOverride;
    if (override != null) return override();
    final c = _connectivity;
    if (c == null) return true;
    return _hasNetwork(await c.checkConnectivity());
  }

  /// Chay mot vong dong bo (day roi keo). Goi chong nhau thi dung chung ket qua;
  /// neu co thay doi moi trong luc dang chay thi chay them mot vong.
  Future<SyncResult> syncNow() {
    final running = _running;
    if (running != null) {
      _rerun = true;
      return running;
    }
    final future = _run().then((r) {
      _afterRun(r);
      return r;
    }).whenComplete(() {
      _running = null;
      if (_rerun && !_disposed) {
        _rerun = false;
        unawaited(syncNow());
      }
    });
    _running = future;
    return future;
  }

  /// Vong that bai (khong toi duoc server, 5xx, 401...) thi hen gio thu lai co lui dan;
  /// thanh cong thi reset. Khong hen khi da dispose (dang xuat).
  void _afterRun(SyncResult r) {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_disposed) return;
    if (r.completed) {
      _retryIndex = 0;
      return;
    }
    final delay = _retryDelays[_retryIndex.clamp(0, _retryDelays.length - 1)];
    if (_retryIndex < _retryDelays.length - 1) _retryIndex++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!_disposed) unawaited(syncNow());
    });
  }

  Future<SyncResult> _run() async {
    if (_disposed) return const SyncResult(completed: false);
    if (!await _isOnline()) {
      _setStatus(SyncStatus.offline);
      return const SyncResult(completed: false, error: 'offline');
    }
    _setStatus(SyncStatus.syncing);
    try {
      final push = await pushOutbox();
      if (!push.completed) {
        _setStatus(SyncStatus.error);
        return SyncResult(
          pushed: push.pushed,
          completed: false,
          error: push.error,
        );
      }
      var pulled = await pullCustomers();
      for (final syncer in _syncers) {
        pulled += await syncer.pull(_db);
      }
      _setStatus(SyncStatus.idle);
      return SyncResult(pushed: push.pushed, pulled: pulled);
    } on DioException catch (e) {
      _setStatus(_isNetworkError(e) ? SyncStatus.offline : SyncStatus.error);
      return SyncResult(completed: false, error: e.message ?? e.type.name);
    } catch (e) {
      _setStatus(SyncStatus.error);
      return SyncResult(completed: false, error: e.toString());
    }
  }

  // ─── Push ──────────────────────────────────────────────────────────────────

  /// Day outbox theo thu tu. `completed=false` khi gap loi tam thoi giua chung.
  @visibleForTesting
  Future<SyncResult> pushOutbox() async {
    final rows = await (_db.select(_db.outboxEntries)
          ..where((t) => t.attempts.isSmallerThanValue(AppConstants.outboxMaxAttempts))
          ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
        .get();

    var pushed = 0;
    for (final row in rows) {
      try {
        await _send(row);
        await (_db.delete(_db.outboxEntries)..where((t) => t.seq.equals(row.seq))).go();
        pushed++;
      } on DioException catch (e) {
        if (_isTransient(e)) {
          return SyncResult(
            pushed: pushed,
            completed: false,
            error: e.message ?? e.type.name,
          );
        }
        await (_db.update(_db.outboxEntries)..where((t) => t.seq.equals(row.seq))).write(
          OutboxEntriesCompanion(
            attempts: Value(row.attempts + 1),
            lastError: Value('HTTP ${e.response?.statusCode}: ${e.message ?? ''}'),
          ),
        );
      }
    }
    return SyncResult(pushed: pushed);
  }

  Future<void> _send(OutboxRow row) async {
    if (row.entityType != customerEntityType) {
      for (final syncer in _syncers) {
        if (syncer.entityType == row.entityType) {
          await syncer.push(row);
          return;
        }
      }
      return;
    }
    final customer =
        Customer.fromJson(jsonDecode(row.payload) as Map<String, dynamic>);
    switch (row.operation) {
      case OutboxOp.delete:
        try {
          await _remote.delete(customer.id);
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
        }
      // POST/PUT deu idempotent theo Id o BE: gui lai bao nhieu lan cung ra mot ban ghi.
      case OutboxOp.create:
        await _remote.create(customer);
      case OutboxOp.update:
        await _remote.update(customer);
    }
  }

  // ─── Pull ──────────────────────────────────────────────────────────────────

  /// Keo ban ghi moi/doi ke tu moc da luu. Tra so ban ghi da ap vao local.
  @visibleForTesting
  Future<int> pullCustomers() async {
    final cursorText = await _db.getMeta(customersCursorKey);
    final since = cursorText == null ? null : DateTime.tryParse(cursorText);

    var page = 1;
    var applied = 0;
    DateTime? maxUpdated = since;
    while (true) {
      final result = await _remote.list(
        updatedSince: since,
        page: page,
        pageSize: AppConstants.syncPageSize,
      );
      for (final remote in result.items) {
        if (await _applyRemote(remote)) applied++;
        final u = remote.updatedAt.toUtc();
        if (maxUpdated == null || u.isAfter(maxUpdated)) maxUpdated = u;
      }
      if (!result.hasMore || result.items.isEmpty) break;
      page++;
    }

    if (maxUpdated != null) {
      await _db.setMeta(customersCursorKey, maxUpdated.toIso8601String());
    }
    return applied;
  }

  /// Ap mot ban ghi tu server. Tra true neu da ghi vao local.
  Future<bool> _applyRemote(Customer remote) async {
    final pending = await (_db.select(_db.outboxEntries)
          ..where((t) =>
              t.entityType.equals(customerEntityType) &
              t.entityId.equals(remote.id))
          ..limit(1))
        .get();
    if (pending.isNotEmpty) return false; // local dang cho day: local thang.

    final local = await (_db.select(_db.customers)
          ..where((t) => t.id.equals(remote.id)))
        .getSingleOrNull();
    if (local != null && local.updatedAt.isAfter(remote.updatedAt)) return false;

    await _db.into(_db.customers).insertOnConflictUpdate(
          CustomersCompanion.insert(
            id: remote.id,
            name: remote.name,
            phone: Value(remote.phone),
            alias: Value(remote.alias),
            note: Value(remote.note),
            isDeleted: Value(remote.isDeleted),
            updatedAt: remote.updatedAt,
          ),
        );
    return true;
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static bool _isNetworkError(DioException e) =>
      e.response == null &&
      (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout);

  /// Loi tam thoi: khong co phan hoi, 5xx, 401 (chua dang nhap/het phien), 408, 429.
  static bool _isTransient(DioException e) {
    final s = e.response?.statusCode;
    return s == null || s >= 500 || s == 401 || s == 408 || s == 429;
  }

  void _setStatus(SyncStatus s) {
    if (_disposed || s == _status) return;
    _status = s;
    _statusCtrl.add(s);
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _connSub?.cancel();
    _connSub = null;
    _statusCtrl.close();
  }
}
