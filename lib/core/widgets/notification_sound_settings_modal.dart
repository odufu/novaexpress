import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';

class NotificationSoundSettingsModal extends ConsumerStatefulWidget {
  final bool isDialog;
  const NotificationSoundSettingsModal({super.key, this.isDialog = false});

  static Future<void> show(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
            child: const NotificationSoundSettingsModal(isDialog: true),
          ),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: const NotificationSoundSettingsModal(),
        ),
      );
    }
  }

  @override
  ConsumerState<NotificationSoundSettingsModal> createState() =>
      _NotificationSoundSettingsModalState();
}

class _NotificationSoundSettingsModalState
    extends ConsumerState<NotificationSoundSettingsModal> {
  String? _currentlyPlayingSoundId;

  @override
  void dispose() {
    AudioService().stopSound();
    super.dispose();
  }

  void _preview(String soundId) async {
    if (_currentlyPlayingSoundId == soundId) {
      await AudioService().stopSound();
      setState(() => _currentlyPlayingSoundId = null);
    } else {
      setState(() => _currentlyPlayingSoundId = soundId);
      await ref.read(audioSettingsProvider.notifier).previewSound(soundId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final audioSettings = ref.watch(audioSettingsProvider);
    final audioNotifier = ref.read(audioSettingsProvider.notifier);

    final bgCard = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final borderRadius = widget.isDialog
        ? BorderRadius.circular(24)
        : const BorderRadius.vertical(top: Radius.circular(24));

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: borderRadius,
        ),
        child: Column(
          children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: AppColors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification Sounds & Chimes',
                        style: GoogleFonts.inter(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Customize alert sounds for reminders, orders & chat',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Sound Settings Form
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              children: [
                // 1. MASTER SOUND TOGGLE & VOLUME CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            audioSettings.soundEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: audioSettings.soundEnabled
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF94A3B8),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sound Notifications',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  audioSettings.soundEnabled
                                      ? 'Active for ringing reminders and live events'
                                      : 'Muted (visual alerts only)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: subtextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: audioSettings.soundEnabled,
                            activeThumbColor: AppColors.orange,
                            onChanged: (val) => audioNotifier.setSoundEnabled(val),
                          ),
                        ],
                      ),
                      if (audioSettings.soundEnabled) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.volume_down_rounded, size: 18, color: Color(0xFF94A3B8)),
                            Expanded(
                              child: Slider(
                                value: audioSettings.volume,
                                min: 0.1,
                                max: 1.0,
                                activeColor: AppColors.orange,
                                inactiveColor: borderColor,
                                onChanged: (val) => audioNotifier.setVolume(val),
                              ),
                            ),
                            Text(
                              '${(audioSettings.volume * 100).round()}%',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. CATEGORY PICKERS
                _buildSoundCategoryTile(
                  context: context,
                  isDark: isDark,
                  icon: Icons.alarm_rounded,
                  accentColor: const Color(0xFFEA580C),
                  title: 'Follow-Up Reminders & Ringing Callbacks',
                  description: 'Ringing chime for scheduled callback follow-ups (Riders, DC Ops, Closers)',
                  currentSoundId: audioSettings.reminderSoundId,
                  onSelect: (id) => audioNotifier.setReminderSound(id),
                ),
                const SizedBox(height: 14),

                _buildSoundCategoryTile(
                  context: context,
                  isDark: isDark,
                  icon: Icons.local_shipping_rounded,
                  accentColor: const Color(0xFF2563EB),
                  title: 'New Incoming Orders',
                  description: 'Alert chime when new orders arrive or are assigned to station/rider',
                  currentSoundId: audioSettings.incomingOrderSoundId,
                  onSelect: (id) => audioNotifier.setIncomingOrderSound(id),
                ),
                const SizedBox(height: 14),

                _buildSoundCategoryTile(
                  context: context,
                  isDark: isDark,
                  icon: Icons.chat_bubble_rounded,
                  accentColor: const Color(0xFF16A34A),
                  title: 'Incoming Chat Messages',
                  description: 'Alert when a new message, note, or voice recording arrives in pipeline chat',
                  currentSoundId: audioSettings.incomingMessageSoundId,
                  onSelect: (id) => audioNotifier.setIncomingMessageSound(id),
                ),
                const SizedBox(height: 14),

                _buildSoundCategoryTile(
                  context: context,
                  isDark: isDark,
                  icon: Icons.send_rounded,
                  accentColor: const Color(0xFF7C3AED),
                  title: 'Message Sent Confirmation',
                  description: 'Subtle sound when your chat message or attachment successfully dispatches',
                  currentSoundId: audioSettings.messageSentSoundId,
                  onSelect: (id) => audioNotifier.setMessageSentSound(id),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),

          // Bottom Action Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Preferences save automatically',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: subtextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSoundCategoryTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String description,
    required String currentSoundId,
    required ValueChanged<String> onSelect,
  }) {
    final theme = Theme.of(context);
    final selectedSound = AudioService.getSoundById(currentSoundId);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D36) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    selectedSound.title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedSound.subtitle,
                    style: GoogleFonts.inter(fontSize: 11.5, color: subtextColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.inter(fontSize: 11.5, color: subtextColor),
                  ),
                  const SizedBox(height: 8),
                  ...AudioService.availableSounds.map((sound) {
                    final isSelected = sound.id == currentSoundId;
                    final isPlaying = _currentlyPlayingSoundId == sound.id;

                    return InkWell(
                      onTap: () => onSelect(sound.id),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? accentColor.withValues(alpha: 0.5) : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: isSelected ? accentColor : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 10),
                            Icon(sound.icon, size: 18, color: isSelected ? accentColor : subtextColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sound.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? accentColor : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    sound.subtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: subtextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                                color: isPlaying ? const Color(0xFFEF4444) : accentColor,
                                size: 24,
                              ),
                              tooltip: isPlaying ? 'Stop Preview' : 'Audition Sound',
                              onPressed: () => _preview(sound.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

