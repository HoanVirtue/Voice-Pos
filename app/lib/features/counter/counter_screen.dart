import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/auth/permission_provider.dart';
import '../../core/auth/permissions.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/vn_format.dart';
import '../../core/widgets/common_widgets.dart';
import '../../modules/voice/providers/voice_input_provider.dart';
import '../customers/data/customer_model.dart';
import '../ledger/providers/ledger_providers.dart';
import '../transactions/data/transaction_model.dart';
import '../transactions/data/txn_type.dart';
import '../transactions/parser/market_parser.dart';
import '../transactions/presentation/txn_draft.dart';
import '../transactions/presentation/txn_editor_sheet.dart';
import '../transactions/providers/parse_providers.dart';
import '../transactions/providers/transaction_providers.dart';

/// Man hinh quay: noi (hoac go) mot cau -> bo phan tich hieu -> the xac nhan sua duoc -> luu so.
/// Cau chac chan (xanh) co the tu ghi neu bat "Tu ghi cau chac chan".
class CounterScreen extends ConsumerStatefulWidget {
  const CounterScreen({super.key});

  @override
  ConsumerState<CounterScreen> createState() => _CounterScreenState();
}

class _Saved {
  final TransactionRecord record;
  final String summary;
  const _Saved(this.record, this.summary);
}

class _CounterScreenState extends ConsumerState<CounterScreen> {
  StreamSubscription<LogicalKeyboardKey>? _buttonSub;
  final List<VoiceCapture> _captures = [];
  final List<_Saved> _saved = [];
  final _input = TextEditingController();
  String? _lastKey;
  bool _autoSave = false;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _keepScreenOn(true);
    // Nut bluetooth (xem BluetoothButtonService de biet gioi han tren iOS).
    _buttonSub = ref.read(bluetoothButtonProvider).presses.listen((key) {
      if (!mounted) return;
      setState(() => _lastKey = key.keyLabel.isNotEmpty ? key.keyLabel : key.debugName);
      _toggle();
    });
  }

  @override
  void dispose() {
    _buttonSub?.cancel();
    _input.dispose();
    _keepScreenOn(false);
    super.dispose();
  }

  Future<void> _keepScreenOn(bool on) async {
    try {
      if (on) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // Nen tang khong ho tro wakelock: bo qua.
    }
  }

  Future<void> _toggle() async {
    // Trong callback: dung read, khong dung watch (hasPerm).
    if (!ref.read(permissionsProvider).has(Perm.voiceUse)) return;
    final notifier = ref.read(voiceInputProvider.notifier);
    if (ref.read(voiceInputProvider).isActive) {
      final capture = await notifier.stop();
      if (!mounted) return;
      if (capture.text.trim().isNotEmpty) {
        setState(() => _captures.insert(0, capture));
        await _handleText(capture.text, audioPath: capture.audioPath);
      }
    } else {
      await _stopSpeaking();
      await notifier.start();
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await ref.read(ttsServiceProvider).stop();
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    try {
      await ref.read(ttsServiceProvider).speak(text);
    } catch (_) {
      // Khong doc duoc (nen tang khong co TTS): bo qua.
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message, style: AppTextStyles.body2)));
  }

  // ─── Xu ly mot cau ───────────────────────────────────────────────────────

  Future<void> _handleText(String text, {String? audioPath}) async {
    if (!ref.read(permissionsProvider).has(Perm.transactionsManage)) {
      _toast('Tài khoản chưa có quyền ghi sổ.');
      return;
    }
    if (_sheetOpen) return;
    final parsed = const MarketParser().parse(
      text,
      customers: ref.read(parserCustomersProvider),
      products: ref.read(parserProductsProvider),
    );
    switch (parsed.kind) {
      case UtteranceKind.unknown:
        _toast('Không nghe rõ, nói lại giúp nhé.');
        await _speak('Chưa rõ, tối xem lại');
      case UtteranceKind.deleteLast:
        await _deleteLast();
      case UtteranceKind.editLast:
        await _editLast(parsed);
      case UtteranceKind.transaction:
        await _newTransaction(parsed, audioPath: audioPath);
    }
  }

  Future<void> _newTransaction(ParsedUtterance parsed, {String? audioPath}) async {
    final draft = TxnDraft.fromParsed(parsed, audioPath: audioPath);
    if (_autoSave && parsed.level == ParseLevel.green && draft.amount > 0) {
      await _persist(draft, speak: describeForSpeech(parsed));
      return;
    }
    final result = await _showEditor(draft, saveLabel: 'Lưu vào sổ');
    final saved = result?.draft;
    if (saved == null || !mounted) return;
    await _persist(saved, speak: describeForSpeech(parsed));
  }

  Future<void> _deleteLast() async {
    final repo = ref.read(transactionRepositoryProvider);
    final last = await repo.getLast();
    if (last == null) {
      _toast('Chưa có giao dịch nào để xóa.');
      return;
    }
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Xóa giao dịch vừa rồi?',
      message: _summarize(last),
    );
    if (!ok) return;
    await repo.softDelete(last.id);
    _saved.removeWhere((s) => s.record.id == last.id);
    if (mounted) setState(() {});
    _toast('Đã xóa giao dịch vừa rồi.');
    await _speak('Đã xóa giao dịch vừa rồi');
  }

  Future<void> _editLast(ParsedUtterance parsed) async {
    final repo = ref.read(transactionRepositoryProvider);
    final last = await repo.getLast();
    if (last == null) {
      _toast('Chưa có giao dịch nào để sửa.');
      return;
    }
    final draft = TxnDraft.fromRecord(last);
    if (parsed.amount != null) {
      draft.amount = parsed.amount!;
      // Dang la "da tra het" thi sua tien se keo theo.
      if (last.paidAmount == last.amount || parsed.paidAmount != null) {
        draft.paidAmount = parsed.paidAmount ?? parsed.amount!;
      }
    }
    if (parsed.customerId != null) draft.customerId = parsed.customerId;
    if (parsed.weightGram != null) draft.weightGram = parsed.weightGram;
    final result = await _showEditor(draft, saveLabel: 'Lưu sửa', allowDelete: false);
    final d = result?.draft;
    if (d == null || !mounted) return;
    final updated = await repo.update(last.copyWith(
      type: d.type,
      customerId: d.customerId,
      productId: d.productId,
      batchId: d.batchId,
      weightGram: d.weightGram,
      amount: d.amount,
      paidAmount: d.paidAmount,
      note: d.note,
    ));
    _toast('Đã sửa: ${_summarize(updated)}');
  }

  Future<void> _persist(TxnDraft d, {String? speak}) async {
    final rec = await ref.read(transactionRepositoryProvider).create(
          type: d.type,
          occurredAt: d.occurredAt,
          customerId: d.customerId,
          productId: d.productId,
          batchId: d.batchId,
          weightGram: d.weightGram,
          amount: d.amount,
          paidAmount: d.paidAmount,
          rawText: d.rawText,
          confidence: d.confidence,
          note: d.note,
          audioPath: d.audioPath,
        );
    if (!mounted) return;
    final summary = _summarize(rec);
    setState(() {
      _saved.insert(0, _Saved(rec, summary));
      if (_saved.length > 5) _saved.removeLast();
    });
    _toast('Đã ghi: $summary');
    if (speak != null) await _speak(speak);
  }

  Future<TxnEditorResult?> _showEditor(
    TxnDraft draft, {
    required String saveLabel,
    bool allowDelete = false,
  }) async {
    _sheetOpen = true;
    try {
      return await showTxnEditorSheet(context, ref,
          draft: draft, saveLabel: saveLabel, allowDelete: allowDelete);
    } finally {
      _sheetOpen = false;
    }
  }

  String _customerName(String? id) {
    if (id == null) return 'Khách lẻ';
    final list = ref.read(allCustomersProvider).valueOrNull ?? const <Customer>[];
    return list.where((c) => c.id == id).map((c) => c.name).firstOrNull ?? 'Khách';
  }

  String _summarize(TransactionRecord r) {
    final parts = <String>[r.type.label];
    if (r.type == TxnType.sale || r.type == TxnType.debtPayment) parts.add(_customerName(r.customerId));
    if (r.weightGram != null) parts.add(formatWeight(r.weightGram!));
    parts.add(formatMoney(r.amount));
    if (r.type == TxnType.sale) parts.add(r.debt > 0 ? 'nợ ${formatMoney(r.debt)}' : 'đã trả');
    return parts.join(' · ');
  }

  Future<void> _undo(_Saved s) async {
    await ref.read(transactionRepositoryProvider).softDelete(s.record.id);
    if (!mounted) return;
    setState(() => _saved.removeWhere((e) => e.record.id == s.record.id));
    _toast('Đã hoàn tác.');
  }

  @override
  Widget build(BuildContext context) {
    // Giu cac provider ngu canh song de bo phan tich co du lieu khach/mon.
    ref.watch(parserCustomersProvider);
    ref.watch(parserProductsProvider);
    ref.watch(allCustomersProvider);

    final voice = ref.watch(voiceInputProvider);
    final canVoice = hasPerm(ref, Perm.voiceUse);
    final canWrite = hasPerm(ref, Perm.transactionsManage);
    final last = _captures.isEmpty ? null : _captures.first;

    final (statusText, statusColor) = switch (voice.status) {
      VoiceInputStatus.idle => ('Sẵn sàng', AppColors.textSecondary),
      VoiceInputStatus.connecting => ('Đang kết nối...', AppColors.warning),
      VoiceInputStatus.recording => ('Đang nghe...', AppColors.success),
      VoiceInputStatus.error => (voice.error ?? 'Lỗi', AppColors.danger),
    };

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navCounter)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            if (!canVoice)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Tài khoản chưa có quyền dùng giọng nói.',
                  style: AppTextStyles.body1,
                  textAlign: TextAlign.center,
                ),
              ),
            Text(
              statusText,
              key: const Key('counter_status'),
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(color: statusColor),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(child: _RecordButton(active: voice.isActive, onPressed: canVoice ? _toggle : null)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              voice.isActive ? 'Bấm lần nữa để kết thúc' : 'Bấm để bắt đầu nói',
              textAlign: TextAlign.center,
              style: AppTextStyles.body1.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              key: const Key('counter_text'),
              constraints: const BoxConstraints(minHeight: 96),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                voice.isActive
                    ? (voice.displayText.isEmpty ? '...' : voice.displayText)
                    : (last?.text ?? 'Chữ vừa nhận sẽ hiện ở đây'),
                style: AppTextStyles.h2.copyWith(
                  color: (voice.isActive || last != null) ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppReplayButton(
              enabled: last != null && !voice.isActive,
              onPressed: last == null ? null : () => _speak(last.text),
            ),
            const Divider(height: AppSpacing.xxxl),
            // Go tay thay cho noi (may khong co mic, hoac nghe sai muon sua nhanh).
            TextField(
              key: const Key('counter_input'),
              controller: _input,
              enabled: canWrite,
              style: AppTextStyles.body1,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitTyped(),
              decoration: InputDecoration(
                labelText: 'Hoặc gõ câu cần ghi',
                hintText: 'vd: Cô Lan hai cân ba chỉ ba trăm tám',
                suffixIcon: IconButton(
                  key: const Key('counter_parse'),
                  icon: const Icon(Icons.send, size: 28),
                  tooltip: 'Ghi câu này',
                  onPressed: canWrite ? _submitTyped : null,
                ),
              ),
            ),
            SwitchListTile(
              key: const Key('counter_autosave'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Tự ghi câu chắc chắn', style: AppTextStyles.body1),
              subtitle: const Text('Câu chưa chắc vẫn hiện thẻ để xem lại', style: AppTextStyles.caption),
              value: _autoSave,
              onChanged: (v) => setState(() => _autoSave = v),
            ),
            if (_saved.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Vừa ghi', style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
              for (final s in _saved)
                ListTile(
                  key: Key('counter_saved_${s.record.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.summary, style: AppTextStyles.body1),
                  trailing: IconButton(
                    tooltip: 'Hoàn tác',
                    icon: const Icon(Icons.undo, size: 28),
                    onPressed: () => _undo(s),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              _lastKey == null
                  ? 'Nút bluetooth: bấm nút trên remote/tai nghe để ghi'
                  : 'Phím vừa nhận từ nút bluetooth: $_lastKey',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  void _submitTyped() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    unawaited(_handleText(text));
  }
}

class _RecordButton extends StatelessWidget {
  final bool active;
  final VoidCallback? onPressed;

  const _RecordButton({required this.active, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: active ? 'Kết thúc ghi' : 'Bắt đầu ghi',
      child: GestureDetector(
        key: const Key('counter_record'),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: active ? 190 : 170,
          height: active ? 190 : 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onPressed == null
                ? AppColors.textMuted
                : (active ? AppColors.success : AppColors.primary),
            boxShadow: [
              BoxShadow(
                color: (active ? AppColors.success : AppColors.primary).withValues(alpha: 0.35),
                blurRadius: active ? 36 : 16,
                spreadRadius: active ? 10 : 0,
              ),
            ],
          ),
          child: Icon(
            active ? Icons.stop_rounded : Icons.mic,
            size: 96,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

class AppReplayButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onPressed;

  const AppReplayButton({super.key, required this.enabled, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('counter_replay'),
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.volume_up, size: 30),
      label: const Text('Đọc lại'),
    );
  }
}
