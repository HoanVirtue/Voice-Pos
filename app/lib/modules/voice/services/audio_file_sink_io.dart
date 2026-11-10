import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Bo ghi file am thanh: nhan PCM16 mono, ghi WAV (sua header khi dong).
///
/// Dung WAV thay vi m4a vi goi `record` chi cho phep PCM khi streaming; ma hoa
/// m4a (neu can) lam o buoc tai len/luu tru sau.
abstract class AudioFileSink {
  String get path;
  void add(List<int> pcm16);
  Future<void> close();
}

AudioFileSink? createAudioFileSink(String path, {required int sampleRate}) {
  try {
    return _WavFileSink(path, sampleRate);
  } catch (_) {
    return null;
  }
}

/// Duong dan file ghi am moi: `<documents>/recordings/<timestamp>.wav`.
Future<String?> newRecordingPath() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final recDir = Directory('${dir.path}${Platform.pathSeparator}recordings');
    await recDir.create(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    return '${recDir.path}${Platform.pathSeparator}$stamp.wav';
  } catch (_) {
    return null;
  }
}

class _WavFileSink implements AudioFileSink {
  @override
  final String path;
  final int sampleRate;
  final RandomAccessFile _file;
  int _dataBytes = 0;
  bool _closed = false;

  _WavFileSink(this.path, this.sampleRate)
      : _file = File(path).openSync(mode: FileMode.write) {
    _file.writeFromSync(_header(0));
  }

  @override
  void add(List<int> pcm16) {
    if (_closed) return;
    _file.writeFromSync(pcm16);
    _dataBytes += pcm16.length;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _file.setPositionSync(0);
    _file.writeFromSync(_header(_dataBytes));
    await _file.close();
  }

  Uint8List _header(int dataLen) {
    final b = ByteData(44);
    void str(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        b.setUint8(off + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little); // kich thuoc khoi fmt
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, 1, Endian.little); // mono
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    b.setUint16(32, 2, Endian.little); // block align
    b.setUint16(34, 16, Endian.little); // bits/sample
    str(36, 'data');
    b.setUint32(40, dataLen, Endian.little);
    return b.buffer.asUint8List();
  }
}
