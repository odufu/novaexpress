import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novexps/core/services/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Notification Sound Settings & AudioService Test Suite', () {
    test('AudioService loads all 8 sound options with valid asset paths', () {
      const sounds = AudioService.availableSounds;
      expect(sounds.length, 8);

      final soundIds = sounds.map((s) => s.id).toSet();
      expect(soundIds.contains('soft_melody'), isTrue);
      expect(soundIds.contains('servant_bell'), isTrue);
      expect(soundIds.contains('digital_ring'), isTrue);
      expect(soundIds.contains('classic_telephone'), isTrue);
      expect(soundIds.contains('school_bell'), isTrue);
      expect(soundIds.contains('doorbell'), isTrue);
      expect(soundIds.contains('gentle_pop'), isTrue);
      expect(soundIds.contains('echo_chime'), isTrue);

      for (final s in sounds) {
        expect(s.title.isNotEmpty, isTrue);
        expect(s.subtitle.isNotEmpty, isTrue);
        expect(s.assetPath.isNotEmpty, isTrue);
        expect(s.assetPath.startsWith('audio/'), isTrue);
      }
    });

    test('AudioService getSoundById resolves sound or defaults to first', () {
      final bell = AudioService.getSoundById('servant_bell');
      expect(bell.title, 'Servant Bell');
      expect(bell.assetPath, 'audio/notifications/floraphonic-servant-bell-ring-2-211683.mp3');

      final unknown = AudioService.getSoundById('non_existent_id');
      expect(unknown.id, AudioService.availableSounds.first.id);
    });

    test('AudioSettingsNotifier updates and persists custom preferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(audioSettingsProvider.notifier);
      final initialState = container.read(audioSettingsProvider);

      expect(initialState.soundEnabled, isTrue);
      expect(initialState.reminderSoundId, 'soft_melody');
      expect(initialState.incomingOrderSoundId, 'doorbell');
      expect(initialState.incomingMessageSoundId, 'gentle_pop');
      expect(initialState.messageSentSoundId, 'echo_chime');

      // 1. Change reminder sound to school_bell
      await notifier.setReminderSound('school_bell');
      expect(container.read(audioSettingsProvider).reminderSoundId, 'school_bell');

      // 2. Change incoming order sound to servant_bell
      await notifier.setIncomingOrderSound('servant_bell');
      expect(container.read(audioSettingsProvider).incomingOrderSoundId, 'servant_bell');

      // 3. Change incoming message sound to digital_ring
      await notifier.setIncomingMessageSound('digital_ring');
      expect(container.read(audioSettingsProvider).incomingMessageSoundId, 'digital_ring');

      // 4. Change volume and mute state
      await notifier.setVolume(0.75);
      expect(container.read(audioSettingsProvider).volume, 0.75);

      await notifier.setSoundEnabled(false);
      expect(container.read(audioSettingsProvider).soundEnabled, isFalse);

      // Verify SharedPreferences persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_sound_reminder'), 'school_bell');
      expect(prefs.getString('app_sound_incoming_order'), 'servant_bell');
      expect(prefs.getString('app_sound_incoming_msg'), 'digital_ring');
      expect(prefs.getDouble('app_sound_volume'), 0.75);
      expect(prefs.getBool('app_sound_effects_enabled'), isFalse);
    });
  });
}

