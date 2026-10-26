// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'voice_recorder.dart';

VoiceNoteRecorder createVoiceNoteRecorder() => WebVoiceNoteRecorder();

class WebVoiceNoteRecorder implements VoiceNoteRecorder {
  html.MediaRecorder? _recorder;
  html.MediaStream? _stream;
  final List<html.Blob> _chunks = [];
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  Timer? _timer;
  Duration _currentDuration = Duration.zero;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Duration get currentDuration => _currentDuration;

  @override
  Future<bool> start() async {
    try {
      await cancel();
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        debugPrint('[WebVoiceNoteRecorder] mediaDevices not supported in this browser');
        return false;
      }

      _stream = await mediaDevices.getUserMedia({'audio': true});
      _chunks.clear();

      String chosenMimeType = '';
      if (html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
        chosenMimeType = 'audio/webm;codecs=opus';
      } else if (html.MediaRecorder.isTypeSupported('audio/webm')) {
        chosenMimeType = 'audio/webm';
      } else if (html.MediaRecorder.isTypeSupported('audio/mp4')) {
        chosenMimeType = 'audio/mp4';
      }

      if (chosenMimeType.isNotEmpty) {
        _recorder = html.MediaRecorder(_stream!, {'mimeType': chosenMimeType});
      } else {
        _recorder = html.MediaRecorder(_stream!);
      }

      _recorder!.addEventListener('dataavailable', (html.Event event) {
        if (event is html.BlobEvent && event.data != null && event.data!.size > 0) {
          _chunks.add(event.data!);
        }
      });

      _recorder!.start(200);
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
    } catch (e) {
      debugPrint('[WebVoiceNoteRecorder] Error starting recording: $e');
      _cleanup();
      return false;
    }
  }

  @override
  Future<VoiceRecordingResult?> stop() async {
    if (!_isRecording || _recorder == null) {
      _cleanup();
      return null;
    }

    try {
      final completer = Completer<VoiceRecordingResult?>();

      _recorder!.addEventListener('stop', (html.Event event) async {
        try {
          String mime = _recorder?.mimeType ?? 'audio/webm';
          if (mime.isEmpty) mime = 'audio/webm';
          final blob = html.Blob(_chunks, mime);

          final reader = html.FileReader();
          reader.readAsArrayBuffer(blob);
          await reader.onLoadEnd.first;

          final bytes = Uint8List.fromList(reader.result as List<int>);
          final ext = mime.contains('mp4') ? 'm4a' : 'webm';

          completer.complete(VoiceRecordingResult(
            bytes: bytes,
            duration: _currentDuration,
            mimeType: mime,
            fileExtension: ext,
          ));
        } catch (e) {
          debugPrint('[WebVoiceNoteRecorder] Error stopping recording: $e');
          completer.complete(null);
        } finally {
          _cleanup();
        }
      });

      _recorder!.stop();
      _isRecording = false;
      _timer?.cancel();

      return await completer.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          _cleanup();
          return null;
        },
      );
    } catch (e) {
      debugPrint('[WebVoiceNoteRecorder] stop exception: $e');
      _cleanup();
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      if (_recorder != null && _isRecording) {
        _recorder!.stop();
      }
    } catch (_) {}
    _cleanup();
  }

  void _cleanup() {
    _isRecording = false;
    _timer?.cancel();
    _timer = null;
    try {
      _stream?.getTracks().forEach((track) => track.stop());
    } catch (_) {}
    _stream = null;
    _recorder = null;
    _chunks.clear();
  }

  @override
  void dispose() {
    cancel();
    _durationController.close();
  }
}
