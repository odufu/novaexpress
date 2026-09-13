import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppAudioEffect {
  incomingOrder,
  incomingMessage,
  messageSent,
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  AudioPlayer? _player;
  bool _soundEnabled = true;
  DateTime? _lastIncomingOrderSound;
  DateTime? _lastIncomingMsgSound;
  DateTime? _lastSentMsgSound;

  static const String _prefKeySoundEnabled = 'app_sound_effects_enabled';

  AudioService._internal() {
    _init();
  }

  bool get isSoundEnabled => _soundEnabled;

  bool _isTestEnvironment() {
    try {
      if (!kIsWeb &&
          (Platform.environment.containsKey('FLUTTER_TEST') ||
              Platform.environment.containsKey('TEST_PLATFORM'))) {
        return true;
      }
    } catch (_) {}
    try {
      final binding =
          WidgetsBinding.instance.runtimeType.toString().toLowerCase();
      if (binding.contains('test') || binding.contains('automated')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _init() async {
    if (_isTestEnvironment()) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(_prefKeySoundEnabled) ?? true;
    } catch (_) {
      _soundEnabled = true;
    }

    try {
      _player = AudioPlayer();
      await _player?.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('[AUDIO_SERVICE] Initialization notice: $e');
    }
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeySoundEnabled, enabled);
    } catch (_) {}
  }

  /// Play incoming order sound alert (doorbell.wav)
  Future<void> playIncomingOrder() async {
    if (!_soundEnabled || _isTestEnvironment()) return;

    final now = DateTime.now();
    if (_lastIncomingOrderSound != null &&
        now.difference(_lastIncomingOrderSound!).inMilliseconds < 1000) {
      // Debounce repetitive alerts in 1s window
      return;
    }
    _lastIncomingOrderSound = now;

    await _playSound('audio/doorbell.wav');
  }

  /// Play incoming message sound alert (popup.wav)
  Future<void> playIncomingMessage() async {
    if (!_soundEnabled || _isTestEnvironment()) return;

    final now = DateTime.now();
    if (_lastIncomingMsgSound != null &&
        now.difference(_lastIncomingMsgSound!).inMilliseconds < 300) {
      // Debounce rapid message batches in 300ms window
      return;
    }
    _lastIncomingMsgSound = now;

    await _playSound('audio/popup.wav');
  }

  /// Play message sent confirmation sound (startup.wav)
  Future<void> playMessageSent() async {
    if (!_soundEnabled || _isTestEnvironment()) return;

    final now = DateTime.now();
    if (_lastSentMsgSound != null &&
        now.difference(_lastSentMsgSound!).inMilliseconds < 300) {
      return;
    }
    _lastSentMsgSound = now;

    await _playSound('audio/startup.wav');
  }

  /// Preview a sound effect regardless of mute setting
  Future<void> playPreview(AppAudioEffect effect) async {
    if (_isTestEnvironment()) return;
    switch (effect) {
      case AppAudioEffect.incomingOrder:
        await _playSound('audio/doorbell.wav');
        break;
      case AppAudioEffect.incomingMessage:
        await _playSound('audio/popup.wav');
        break;
      case AppAudioEffect.messageSent:
        await _playSound('audio/startup.wav');
        break;
    }
  }

  Future<void> _playSound(String assetRelativePath) async {
    try {
      _player ??= AudioPlayer();
      // audioplayers prepends 'assets/' by default
      await _player?.stop();
      await _player?.play(AssetSource(assetRelativePath));
    } catch (e) {
      debugPrint('[AUDIO_SERVICE] Playback notice for $assetRelativePath: $e');
    }
  }

  void dispose() {
    try {
      _player?.dispose();
    } catch (_) {}
  }
}

class SoundEnabledNotifier extends StateNotifier<bool> {
  final AudioService _audioService;
  SoundEnabledNotifier(this._audioService) : super(_audioService.isSoundEnabled);

  Future<void> toggle() async {
    final next = !state;
    await _audioService.setSoundEnabled(next);
    state = next;
  }

  Future<void> setEnabled(bool enabled) async {
    await _audioService.setSoundEnabled(enabled);
    state = enabled;
  }
}

final soundEnabledProvider = StateNotifierProvider<SoundEnabledNotifier, bool>((ref) {
  return SoundEnabledNotifier(AudioService());
});

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});
