import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class RescheduleCallbackState {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final String datePreset;
  final String timePreset;

  RescheduleCallbackState({
    required this.selectedDate,
    required this.selectedTime,
    this.datePreset = 'tomorrow',
    this.timePreset = 'afternoon',
  });

  RescheduleCallbackState copyWith({
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    String? datePreset,
    String? timePreset,
  }) {
    return RescheduleCallbackState(
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      datePreset: datePreset ?? this.datePreset,
      timePreset: timePreset ?? this.timePreset,
    );
  }
}

class RescheduleCallbackNotifier extends StateNotifier<RescheduleCallbackState> {
  RescheduleCallbackNotifier()
      : super(RescheduleCallbackState(
          selectedDate: DateTime.now().add(const Duration(days: 1)),
          selectedTime: const TimeOfDay(hour: 14, minute: 0),
        ));

  void setDatePreset(String preset, DateTime date) {
    state = state.copyWith(datePreset: preset, selectedDate: date);
  }

  void setTimePreset(String preset, TimeOfDay time) {
    state = state.copyWith(timePreset: preset, selectedTime: time);
  }
}

final rescheduleCallbackProvider =
    StateNotifierProvider.autoDispose<RescheduleCallbackNotifier, RescheduleCallbackState>((ref) {
  return RescheduleCallbackNotifier();
});

class RescheduleCallbackModal extends ConsumerStatefulWidget {
  final String orderId;
  final String customerName;
  final Function(DateTime scheduledTime, String note) onRescheduleConfirmed;

  const RescheduleCallbackModal({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.onRescheduleConfirmed,
  });

  static Future<void> show({
    required BuildContext context,
    required String orderId,
    required String customerName,
    required Function(DateTime scheduledTime, String note) onRescheduleConfirmed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RescheduleCallbackModal(
        orderId: orderId,
        customerName: customerName,
        onRescheduleConfirmed: onRescheduleConfirmed,
      ),
    );
  }

  @override
  ConsumerState<RescheduleCallbackModal> createState() => _RescheduleCallbackModalState();
}

class _RescheduleCallbackModalState extends ConsumerState<RescheduleCallbackModal> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _pickCustomDate(DateTime currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (picked != null) {
      ref.read(rescheduleCallbackProvider.notifier).setDatePreset('custom', picked);
    }
  }

  void _pickCustomTime(TimeOfDay currentTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    if (picked != null) {
      ref.read(rescheduleCallbackProvider.notifier).setTimePreset('custom', picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final callbackState = ref.watch(rescheduleCallbackProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_calendar_rounded,
                  color: Color(0xFFEA580C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reschedule / Call Back',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Set appointment callback for ${widget.customerName}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Select Date Section
          Text(
            'SELECT RESCHEDULE DATE',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDatePresetChip(
                  label: 'Tomorrow',
                  isSelected: callbackState.datePreset == 'tomorrow',
                  onTap: () {
                    ref.read(rescheduleCallbackProvider.notifier).setDatePreset(
                          'tomorrow',
                          DateTime.now().add(const Duration(days: 1)),
                        );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDatePresetChip(
                  label: 'In 2 Days',
                  isSelected: callbackState.datePreset == 'next_2_days',
                  onTap: () {
                    ref.read(rescheduleCallbackProvider.notifier).setDatePreset(
                          'next_2_days',
                          DateTime.now().add(const Duration(days: 2)),
                        );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDatePresetChip(
                  label: 'Custom Date',
                  isSelected: callbackState.datePreset == 'custom',
                  onTap: () => _pickCustomDate(callbackState.selectedDate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Select Time Slot
          Text(
            'PREFERRED TIME SLOT',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTimePresetChip(
                  label: 'Morning (10 AM)',
                  isSelected: callbackState.timePreset == 'morning',
                  onTap: () {
                    ref.read(rescheduleCallbackProvider.notifier).setTimePreset(
                          'morning',
                          const TimeOfDay(hour: 10, minute: 0),
                        );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimePresetChip(
                  label: 'Afternoon (2 PM)',
                  isSelected: callbackState.timePreset == 'afternoon',
                  onTap: () {
                    ref.read(rescheduleCallbackProvider.notifier).setTimePreset(
                          'afternoon',
                          const TimeOfDay(hour: 14, minute: 0),
                        );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimePresetChip(
                  label: 'Evening (5 PM)',
                  isSelected: callbackState.timePreset == 'evening',
                  onTap: () {
                    ref.read(rescheduleCallbackProvider.notifier).setTimePreset(
                          'evening',
                          const TimeOfDay(hour: 17, minute: 0),
                        );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimePresetChip(
                  label: callbackState.timePreset == 'custom'
                      ? callbackState.selectedTime.format(context)
                      : 'Pick Time',
                  isSelected: callbackState.timePreset == 'custom',
                  onTap: () => _pickCustomTime(callbackState.selectedTime),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Notes
          Text(
            'CALLBACK NOTES',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. Customer requested delivery after office close.',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 18),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final scheduledDateTime = DateTime(
                  callbackState.selectedDate.year,
                  callbackState.selectedDate.month,
                  callbackState.selectedDate.day,
                  callbackState.selectedTime.hour,
                  callbackState.selectedTime.minute,
                );
                final note = _notesController.text.trim().isNotEmpty
                    ? _notesController.text.trim()
                    : 'Customer requested reschedule for ${callbackState.selectedDate.day}/${callbackState.selectedDate.month} at ${callbackState.selectedTime.format(context)}';

                Navigator.pop(context);
                widget.onRescheduleConfirmed(scheduledDateTime, note);
              },
              icon: const Icon(Icons.alarm_add_rounded, size: 18),
              label: Text(
                'Confirm Reschedule (${callbackState.selectedDate.day}/${callbackState.selectedDate.month} • ${callbackState.selectedTime.format(context)})',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
