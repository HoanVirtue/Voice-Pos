import 'dart:async';

import 'package:banhang_app/modules/voice/providers/voice_input_provider.dart';
import 'package:banhang_app/modules/voice/services/stt_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStt implements SttService {
  final ctrl = StreamController<SttMessage>.broadcast();
  bool permission = true;
  bool disposed = false;
  String? startedWithPath;
  int startCalls = 0;

  @override
  Stream<SttMessage> get messages => ctrl.stream;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> connect() async {}

  @override
  Future<void> start({String? recordToPath}) async {
    startCalls++;
    startedWithPath = recordToPath;
    ctrl.add(const SttReady());
  }

  @override
  Future<String?> stop() async => startedWithPath;

  @override
  void dispose() {
    disposed = true;
    ctrl.close();
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeStt stt;
  late VoiceInputNotifier notifier;

  setUp(() {
    stt = FakeStt();
    notifier = VoiceInputNotifier(stt, newRecordingPath: () async => '/tmp/a.wav');
  });

  tearDown(() => notifier.dispose());

  test('start -> recording; partial roi final duoc chot thanh van ban', () async {
    await notifier.start();
    await _flush();
    expect(notifier.state.status, VoiceInputStatus.recording);

    stt.ctrl.add(const SttPartial('cô lan lấy'));
    await _flush();
    expect(notifier.state.displayText, 'cô lan lấy');

    stt.ctrl.add(const SttFinal('cô Lan lấy hai cân'));
    await _flush();
    expect(notifier.state.committedText, 'cô Lan lấy hai cân');
    expect(notifier.state.livePartial, isEmpty);

    stt.ctrl.add(const SttFinal('ba trăm tám'));
    stt.ctrl.add(const SttPartial('đưa tiền'));
    await _flush();
    expect(notifier.state.displayText, 'cô Lan lấy hai cân ba trăm tám đưa tiền');
  });

  test('stop tra chu day du + duong dan file ghi am, ve idle', () async {
    await notifier.start();
    await _flush();
    stt.ctrl.add(const SttFinal('khách lẻ năm chục'));
    await _flush();

    final capture = await notifier.stop();

    expect(capture.text, 'khách lẻ năm chục');
    expect(capture.audioPath, '/tmp/a.wav');
    expect(notifier.state.status, VoiceInputStatus.idle);
  });

  test('khong co quyen mic -> trang thai loi, khong start', () async {
    stt.permission = false;
    await notifier.start();
    expect(notifier.state.status, VoiceInputStatus.error);
    expect(notifier.state.error, contains('microphone'));
    expect(stt.startCalls, 0);
  });

  test('loi STT -> error; start lai khong chot trung cau (khong chong listener)', () async {
    await notifier.start();
    await _flush();
    stt.ctrl.add(const SttError('mất kết nối'));
    await _flush();
    expect(notifier.state.status, VoiceInputStatus.error);

    notifier.clearError();
    await notifier.start();
    await _flush();
    stt.ctrl.add(const SttFinal('một câu'));
    await _flush();

    expect(notifier.state.committedText, 'một câu'); // khong phai 'một câu một câu'
  });

  test('bam doi (start hai lan lien tiep) chi start mot lan', () async {
    await Future.wait([notifier.start(), notifier.start()]);
    expect(stt.startCalls, 1);
  });

  test('dispose notifier dong dich vu STT', () {
    final own = FakeStt();
    VoiceInputNotifier(own).dispose();
    expect(own.disposed, isTrue);
  });
}
