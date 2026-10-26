import 'dart:async';
import 'dart:typed_data';

import 'voice_recorder_io.dart'
    if (dart.library.html) 'voice_recorder_web.dart';

class VoiceRecordingResult {
  final Uint8List bytes;
  final Duration duration;
  final String mimeType;
  final String fileExtension;

  const VoiceRecordingResult({
    required this.bytes,
    required this.duration,
    required this.mimeType,
    required this.fileExtension,
  });
}

abstract class VoiceNoteRecorder {
  factory VoiceNoteRecorder() => createVoiceNoteRecorder();

  bool get isRecording;
  Stream<Duration> get durationStream;
  Duration get currentDuration;

  Future<bool> start();
  Future<VoiceRecordingResult?> stop();
  Future<void> cancel();
  void dispose();
}
