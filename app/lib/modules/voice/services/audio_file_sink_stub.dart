/// Bo ghi file am thanh (ban cho nen tang khong co dart:io, vd web).
abstract class AudioFileSink {
  String get path;
  void add(List<int> pcm16);
  Future<void> close();
}

/// Web: khong ghi file, tra null.
AudioFileSink? createAudioFileSink(String path, {required int sampleRate}) => null;

/// Web: khong co thu muc ghi am.
Future<String?> newRecordingPath() async => null;
