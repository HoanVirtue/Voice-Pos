import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/permission_provider.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/money_input.dart';
import '../../../core/utils/vn_format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/money_field.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../reports/report_calculator.dart';
import '../../transactions/data/transaction_model.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../data/settlement_model.dart';
import '../providers/settlement_providers.dart';

/// Ngay dang chot so (`yyyy-MM-dd`, gio VN).
final settlementDateProvider = StateProvider.autoDispose<String>((ref) => VnTime.today());

/// Chot so ngay + doi chieu ket: nhap so tien dem thuc te, app so voi so tren so va bao chenh lech.
class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  final _opening = TextEditingController();
  final _counted = TextEditingController();
  final _note = TextEditingController();
  String? _initKey;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _opening.addListener(_markDirty);
    _counted.addListener(_markDirty);
    _note.addListener(_markDirty);
  }

  @override
  void dispose() {
    _opening.dispose();
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  bool _loading = false;

  void _markDirty() {
    if (!_loading) _dirty = true;
  }

  /// Nap o nhap tu lan chot da luu (hoac tien dau ngay goi y). Khong ghi de khi nguoi dung dang go.
  void _maybeInit(String date, List<DaySettlement> list) {
    final existing = list.where((s) => s.date == date).firstOrNull;
    // Du lieu khach/lan chot den tre (stream drift): nap lai khi goi y tien dau ngay doi, neu nguoi dung chua go.
    final suggested = openingCashFor(list, date);
    final key = '$date|${existing?.id}|${existing?.updatedAt.millisecondsSinceEpoch ?? suggested}';
    if (key == _initKey) return;
    final dateChanged = _initKey == null || _initKey!.split('|').first != date;
    if (_dirty && !dateChanged) return;
    _initKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loading = true;
      _opening.text = moneyToInputText(existing?.openingCash ?? suggested);
      _counted.text = existing == null ? '' : moneyToInputText(existing.countedCash);
      _note.text = existing?.note ?? '';
      _loading = false;
      _dirty = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canView = hasPerm(ref, Perm.transactionsView);
    final canManage = hasPerm(ref, Perm.transactionsManage);
    final date = ref.watch(settlementDateProvider);
    final list = ref.watch(settlementsProvider).valueOrNull ?? const <DaySettlement>[];
    final txns = ref.watch(dayTransactionsProvider(date)).valueOrNull ?? const [];
    if (canView) _maybeInit(date, list);
    final existing = list.where((s) => s.date == date).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Chốt sổ')),
      body: !canView
          ? const NoPermissionView()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _DateRow(date: date),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const Key('settle_opening'),
                  child: MoneyField(controller: _opening, label: 'Tiền đầu ngày'),
                ),
                const SizedBox(height: AppSpacing.md),
                AnimatedBuilder(
                  animation: Listenable.merge([_opening, _counted]),
                  builder: (context, _) {
                    final opening = parseMoneyInput(_opening.text) ?? 0;
                    final r = computeDaily(txns, date, openingCash: opening);
                    final counted = parseMoneyInput(_counted.text);
                    return _Summary(report: r, counted: counted);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                KeyedSubtree(
                  key: const Key('settle_counted'),
                  child: MoneyField(controller: _counted, label: 'Két đếm thực tế', required: true),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('settle_note'),
                  controller: _note,
                  style: AppTextStyles.body1,
                  decoration: const InputDecoration(labelText: 'Ghi chú (nếu lệch)'),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  key: const Key('settle_save'),
                  onPressed: (canManage && !_saving) ? () => _save(date, txns) : null,
                  child: Text(existing == null ? 'Chốt sổ' : 'Chốt lại'),
                ),
                if (!canManage)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.sm),
                    child: Text('Tài khoản chưa có quyền chốt sổ.', style: AppTextStyles.caption),
                  ),
                const SizedBox(height: AppSpacing.xxl),
                if (list.isNotEmpty) ...[
                  Text('Các lần chốt gần đây', style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
                  for (final s in list.take(10))
                    ListTile(
                      key: Key('settle_hist_${s.date}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(VnTime.dmy(s.date)),
                      subtitle: Text('Két ${formatMoney(s.countedCash)} · sổ ${formatMoney(s.expectedCash)}',
                          style: AppTextStyles.caption),
                      trailing: Text(
                        _diffText(s.difference),
                        style: AppTextStyles.body1SemiBold.copyWith(color: _diffColor(s.difference)),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Future<void> _save(String date, List<TransactionRecord> txns) async {
    final counted = parseMoneyInput(_counted.text);
    if (counted == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nhập số tiền két đếm được.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final opening = parseMoneyInput(_opening.text) ?? 0;
      final report = computeDaily(txns, date, openingCash: opening);
      final saved = await ref.read(settlementRepositoryProvider).save(
            date: date,
            openingCash: opening,
            countedCash: counted,
            expectedCash: report.cashInHand,
            note: _note.text,
          );
      _dirty = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã chốt sổ ${VnTime.dmy(date)}: ${_diffText(saved.difference)}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _diffText(int diff) {
  if (diff == 0) return 'Khớp';
  return diff > 0 ? 'Thừa ${formatMoney(diff)}' : 'Thiếu ${formatMoney(-diff)}';
}

Color _diffColor(int diff) =>
    diff == 0 ? AppColors.success : (diff > 0 ? AppColors.warning : AppColors.danger);

class _DateRow extends ConsumerWidget {
  final String date;

  const _DateRow({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToday = date == VnTime.today();
    void shift(int d) => ref.read(settlementDateProvider.notifier).state = VnTime.addDays(date, d);
    return Row(
      children: [
        IconButton(
          key: const Key('settle_prev'),
          tooltip: 'Ngày trước',
          icon: const Icon(Icons.chevron_left, size: 36),
          onPressed: () => shift(-1),
        ),
        Expanded(
          child: Text(
            isToday ? 'Hôm nay · ${VnTime.dmy(date)}' : VnTime.dmy(date),
            key: const Key('settle_date'),
            textAlign: TextAlign.center,
            style: AppTextStyles.h3,
          ),
        ),
        IconButton(
          key: const Key('settle_next'),
          tooltip: 'Ngày sau',
          icon: const Icon(Icons.chevron_right, size: 36),
          onPressed: isToday ? null : () => shift(1),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final DailyReport report;
  final int? counted;

  const _Summary({required this.report, required this.counted});

  @override
  Widget build(BuildContext context) {
    final expected = report.cashInHand;
    final diff = counted == null ? null : counted! - expected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            StatTile(label: 'Thu tiền mặt (bán + thu nợ)', value: formatMoney(report.cashIn)),
            StatTile(label: 'Chi (mua lợn + chi khác)', value: formatMoney(report.buyPigCost + report.expenseCost)),
            StatTile(label: 'Mang đi chợ', value: formatMoney(report.cashOut)),
            const Divider(),
            StatTile(
              label: 'Két theo sổ',
              value: formatMoney(expected),
              valueKey: const Key('settle_expected'),
            ),
            StatTile(
              label: 'Chênh lệch',
              value: diff == null ? '—' : _diffText(diff),
              valueKey: const Key('settle_diff'),
              color: diff == null ? AppColors.textMuted : _diffColor(diff),
            ),
          ],
        ),
      ),
    );
  }
}
