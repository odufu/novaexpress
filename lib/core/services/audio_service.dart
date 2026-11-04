import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppAudioEffect {
  incomingOrder,
  incomingMessage,
  messageSent,
  reminderChime,
}

class NotificationSoundItem {
  final String id;
  final String title;
  final String subtitle;
  final String assetPath;
  final IconData icon;

  const NotificationSoundItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.icon,
  });
}

class AudioSettingsState {
  final bool soundEnabled;
  final double volume;
  final String reminderSoundId;
  final String incomingOrderSoundId;
  final String incomingMessageSoundId;
  final String messageSentSoundId;

  const AudioSettingsState({
    this.soundEnabled = true,
    this.volume = 1.0,
    this.reminderSoundId = 'soft_melody',
    this.incomingOrderSoundId = 'doorbell',
    this.incomingMessageSoundId = 'gentle_pop',
    this.messageSentSoundId = 'echo_chime',
  });

  AudioSettingsState copyWith({
    bool? soundEnabled,
    double? volume,
    String? reminderSoundId,
    String? incomingOrderSoundId,
    String? incomingMessageSoundId,
    String? messageSentSoundId,
  }) {
    return AudioSettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      volume: volume ?? this.volume,
      reminderSoundId: reminderSoundId ?? this.reminderSoundId,
      incomingOrderSoundId: incomingOrderSoundId ?? this.incomingOrderSoundId,
      incomingMessageSoundId: incomingMessageSoundId ?? this.incomingMessageSoundId,
      messageSentSoundId: messageSentSoundId ?? this.messageSentSoundId,
    );
  }
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  static const List<NotificationSoundItem> availableSounds = [
    NotificationSoundItem(
      id: 'soft_melody',
      title: 'Soft Ringtone',
      subtitle: 'Gentle, modern acoustic melody',
      assetPath: 'audio/notifications/senthilkumarnew-soft-ring-tone-313009.mp3',
      icon: Icons.music_note_rounded,
    ),
    NotificationSoundItem(
      id: 'servant_bell',
      title: 'Servant Bell',
      subtitle: 'Crisp acoustic hotel counter bell',
      assetPath: 'audio/notifications/floraphonic-servant-bell-ring-2-211683.mp3',
      icon: Icons.notifications_active_rounded,
    ),
    NotificationSoundItem(
      id: 'digital_ring',
      title: 'Digital Phone Ring',
      subtitle: 'Standard electronic telephone ringtone',
      assetPath: 'audio/notifications/soundreality-phone-ring-ringtone-580723.mp3',
      icon: Icons.ring_volume_rounded,
    ),
    NotificationSoundItem(
      id: 'classic_telephone',
      title: 'Classic Telephone',
      subtitle: 'Traditional dual-bell rotary telephone',
      assetPath: 'audio/notifications/freesound_community-ring-ring-6126.mp3',
      icon: Icons.phone_in_talk_rounded,
    ),
    NotificationSoundItem(
      id: 'school_bell',
      title: 'School Bell',
      subtitle: 'Prominent reverberating bell alert',
      assetPath: 'audio/notifications/u_qmic4cwja4-school-ring-kids-out-551606.mp3',
      icon: Icons.campaign_rounded,
    ),
    NotificationSoundItem(
      id: 'doorbell',
      title: 'Nova Doorbell',
      subtitle: 'Harmonic two-tone chime',
      assetPath: 'audio/doorbell.wav',
      icon: Icons.doorbell_rounded,
    ),
    NotificationSoundItem(
      id: 'gentle_pop',
      title: 'Gentle Pop',
      subtitle: 'Subtle notification click for chats',
      assetPath: 'audio/popup.wav',
      icon: Icons.bubble_chart_rounded,
    ),
    NotificationSoundItem(
      id: 'echo_chime',
      title: 'Echo Chime',
      subtitle: 'Futuristic confirmation chime',
      assetPath: 'audio/startup.wav',
      icon: Icons.graphic_eq_rounded,
    ),
  ];

  static NotificationSoundItem getSoundById(String id) {
    return availableSounds.firstWhere(
      (s) => s.id == id,
      orElse: () => availableSounds.first,
    );
  }

  AudioPlayer? _player;
  bool _soundEnabled = true;
  double _volume = 1.0;
  String _reminderSoundId = 'soft_melody';
  String _incomingOrderSoundId = 'doorbell';
  String _incomingMessageSoundId = 'gentle_pop';
  String _messageSentSoundId = 'echo_chime';

  DateTime? _lastIncomingOrderSound;
  DateTime? _lastIncomingMsgSound;
  DateTime? _lastSentMsgSound;
  DateTime? _lastReminderSound;

  static const String _prefKeySoundEnabled = 'app_sound_effects_enabled';
  static const String _prefKeyVolume = 'app_sound_volume';
  static const String _prefKeyReminder = 'app_sound_reminder';
  static const String _prefKeyIncomingOrder = 'app_sound_incoming_order';
  static const String _prefKeyIncomingMsg = 'app_sound_incoming_msg';
  static const String _prefKeyMessageSent = 'app_sound_message_sent';

  AudioService._internal() {
    _init();
  }

  bool get isSoundEnabled => _soundEnabled;
  double get volume => _volume;
  String get reminderSoundId => _reminderSoundId;
  String get incomingOrderSoundId => _incomingOrderSoundId;
  String get incomingMessageSoundId => _incomingMessageSoundId;
  String get messageSentSoundId => _messageSentSoundId;

  AudioSettingsState get settingsState => AudioSettingsState(
        soundEnabled: _soundEnabled,
        volume: _volume,
        reminderSoundId: _reminderSoundId,
        incomingOrderSoundId: _incomingOrderSoundId,
        incomingMessageSoundId: _incomingMessageSoundId,
        messageSentSoundId: _messageSentSoundId,
      );

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
      _volume = prefs.getDouble(_prefKeyVolume) ?? 1.0;
      _reminderSoundId = prefs.getString(_prefKeyReminder) ?? 'soft_melody';
      _incomingOrderSoundId = prefs.getString(_prefKeyIncomingOrder) ?? 'doorbell';
      _incomingMessageSoundId = prefs.getString(_prefKeyIncomingMsg) ?? 'gentle_pop';
      _messageSentSoundId = prefs.getString(_prefKeyMessageSent) ?? 'echo_chime';
    } catch (_) {
      _soundEnabled = true;
      _volume = 1.0;
      _reminderSoundId = 'soft_melody';
      _incomingOrderSoundId = 'doorbell';
      _incomingMessageSoundId = 'gentle_pop';
      _messageSentSoundId = 'echo_chime';
    }

    try {
      _player = AudioPlayer();
      await _player?.setReleaseMode(ReleaseMode.stop);
      await _player?.setVolume(_volume);
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

  Future<void> setVolume(double val) async {
    _volume = val.clamp(0.0, 1.0);
    try {
      await _player?.setVolume(_volume);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefKeyVolume, _volume);
    } catch (_) {}
  }

  Future<void> setReminderSound(String soundId) async {
    _reminderSoundId = soundId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyReminder, soundId);
    } catch (_) {}
  }

  Future<void> setIncomingOrderSound(String soundId) async {
    _incomingOrderSoundId = soundId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyIncomingOrder, soundId);
    } catch (_) {}
  }

  Future<void> setIncomingMessageSound(String soundId) async {
    _incomingMessageSoundId = soundId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyIncomingMsg, soundId);
    } catch (_) {}
  }

  Future<void> setMessageSentSound(String soundId) async {
    _messageSentSoundId = soundId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyMessageSent, soundId);
    } catch (_) {}
  }

  /// Play incoming order sound alert
  Future<void> playIncomingOrder() async {
    if (!_soundEnabled || _isTestEnvironment()) return;

    final now = DateTime.now();
    if (_lastIncomingOrderSound != null &&
        now.difference(_lastIncomingOrderSound!).inMilliseconds < 1000) {
      return;
    }
    _lastIncomingOrderSound = now;

    final item = getSoundById(_incomingOrderSoundId);
    await _playSound(item.assetPath);
  }

  /// Play follow-up reminder chime / ringing reschedule alert
  Future<void> playFollowUpReminderChime() async {
    if (!_soundEnabled || _isTestEnvironment()) return;

    final now = DateTime.now();
    if (_lastReminderSound != null &&
        now.difference(_lastReminderSound!).inMilliseconds < 2000) {
      return;
    }
    _lastReminderSound = now;

    final item = getSoundById(_reminderSoundId);
    await _playSound(item.assetPath);
  }

  /// Play incoming message sound alert
  Future<void> playIncomingMessage() async {
    if (!_soundEnabled || _isTestEnvironment()) return;

    final now = DateTime.now();
    if (_lastIncomingMsgSound != null &&
        now.difference(_lastIncomingMsgSound!).inMilliseconds < 300) {
      return;
    }
    _lastIncomingMsgSound = now;

    final item = getSoundById(_incomingMessageSoundId);
    await _playSound(item.assetPath);
  }

  /// Play message sent confirmation sound
  Future<void> playMessageSent() async {
    if (!_soundEnabled || _isTestEnvironment()) return;

    final now = DateTime.now();
    if (_lastSentMsgSound != null &&
        now.difference(_lastSentMsgSound!).inMilliseconds < 300) {
      return;
    }
    _lastSentMsgSound = now;

    final item = getSoundById(_messageSentSoundId);
    await _playSound(item.assetPath);
  }

  /// Preview a sound effect regardless of mute setting
  Future<void> playPreview(AppAudioEffect effect) async {
    if (_isTestEnvironment()) return;
    switch (effect) {
      case AppAudioEffect.incomingOrder:
        await _playSound(getSoundById(_incomingOrderSoundId).assetPath, bypassMute: true);
        break;
      case AppAudioEffect.incomingMessage:
        await _playSound(getSoundById(_incomingMessageSoundId).assetPath, bypassMute: true);
        break;
      case AppAudioEffect.messageSent:
        await _playSound(getSoundById(_messageSentSoundId).assetPath, bypassMute: true);
        break;
      case AppAudioEffect.reminderChime:
        await _playSound(getSoundById(_reminderSoundId).assetPath, bypassMute: true);
        break;
    }
  }

  /// Preview any sound by soundId
  Future<void> previewSound(String soundId) async {
    if (_isTestEnvironment()) return;
    final item = getSoundById(soundId);
    await _playSound(item.assetPath, bypassMute: true);
  }

  Future<void> stopSound() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  Future<void> _playSound(String assetRelativePath, {bool bypassMute = false}) async {
    if ((!_soundEnabled && !bypassMute) || _isTestEnvironment()) return;
    try {
      _player ??= AudioPlayer();
      await _player?.stop();
      await _player?.setVolume(_volume);
      // audioplayers prepends 'assets/' by default
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

class AudioSettingsNotifier extends StateNotifier<AudioSettingsState> {
  final AudioService _audioService;
  AudioSettingsNotifier(this._audioService) : super(_audioService.settingsState);

  Future<void> setSoundEnabled(bool enabled) async {
    await _audioService.setSoundEnabled(enabled);
    state = state.copyWith(soundEnabled: enabled);
  }

  Future<void> toggleSoundEnabled() async {
    await setSoundEnabled(!state.soundEnabled);
  }

  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
    state = state.copyWith(volume: volume);
  }

  Future<void> setReminderSound(String soundId) async {
    await _audioService.setReminderSound(soundId);
    state = state.copyWith(reminderSoundId: soundId);
  }

  Future<void> setIncomingOrderSound(String soundId) async {
    await _audioService.setIncomingOrderSound(soundId);
    state = state.copyWith(incomingOrderSoundId: soundId);
  }

  Future<void> setIncomingMessageSound(String soundId) async {
    await _audioService.setIncomingMessageSound(soundId);
    state = state.copyWith(incomingMessageSoundId: soundId);
  }

  Future<void> setMessageSentSound(String soundId) async {
    await _audioService.setMessageSentSound(soundId);
    state = state.copyWith(messageSentSoundId: soundId);
  }

  Future<void> previewSound(String soundId) async {
    await _audioService.previewSound(soundId);
  }

  Future<void> stopSound() async {
    await _audioService.stopSound();
  }
}

final soundEnabledProvider = StateNotifierProvider<SoundEnabledNotifier, bool>((ref) {
  return SoundEnabledNotifier(AudioService());
});

final audioSettingsProvider =
    StateNotifierProvider<AudioSettingsNotifier, AudioSettingsState>((ref) {
  return AudioSettingsNotifier(AudioService());
});

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});
