import 'dart:async';
import 'dart:typed_data';
import 'voice_recorder.dart';

VoiceNoteRecorder createVoiceNoteRecorder() => IOVoiceNoteRecorder();

class IOVoiceNoteRecorder implements VoiceNoteRecorder {
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  Duration _currentDuration = Duration.zero;
  bool _isRecording = false;
  Timer? _timer;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Duration get currentDuration => _currentDuration;

  @override
  Future<bool> start() async {
    _isRecording = true;
    _currentDuration = Duration.zero;
    _durationController.add(_currentDuration);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isRecording) {
        t.cancel();
        return;
      }
      _currentDuration += const Duration(seconds: 1);
      _durationController.add(_currentDuration);
    });
    return true;
  }

  @override
  Future<VoiceRecordingResult?> stop() async {
    _isRecording = false;
    _timer?.cancel();
    return VoiceRecordingResult(
      bytes: Uint8List(0),
      duration: _currentDuration,
      mimeType: 'audio/webm',
      fileExtension: 'webm',
    );
  }

  @override
  Future<void> cancel() async {
    _isRecording = false;
    _timer?.cancel();
  }

  @override
  void dispose() {
    cancel();
    _durationController.close();
  }
}
