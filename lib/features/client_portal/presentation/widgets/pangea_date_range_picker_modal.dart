import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

enum DateRangePreset {
  today,
  yesterday,
  thisMonth,
  todayAndYesterday,
  last7Days,
  last14Days,
  last28Days,
  last30Days,
  thisWeek,
  lastWeek,
  lastMonth,
  custom,
}

class PangeaDateRangeResult {
  final DateTime startDate;
  final DateTime endDate;
  final DateRangePreset preset;
  final bool compareWithPreviousPeriod;

  const PangeaDateRangeResult({
    required this.startDate,
    required this.endDate,
    required this.preset,
    this.compareWithPreviousPeriod = false,
  });
}

class PangeaDateRangePickerModal extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final DateRangePreset initialPreset;
  final bool initialCompare;

  const PangeaDateRangePickerModal({
    super.key,
    required this.initialStartDate,
    required this.initialEndDate,
    this.initialPreset = DateRangePreset.custom,
    this.initialCompare = false,
  });

  static Future<PangeaDateRangeResult?> show(
    BuildContext context, {
    required DateTime initialStartDate,
    required DateTime initialEndDate,
    DateRangePreset initialPreset = DateRangePreset.custom,
    bool initialCompare = false,
  }) {
    return showDialog<PangeaDateRangeResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PangeaDateRangePickerModal(
        initialStartDate: initialStartDate,
        initialEndDate: initialEndDate,
        initialPreset: initialPreset,
        initialCompare: initialCompare,
      ),
    );
  }

  @override
  State<PangeaDateRangePickerModal> createState() => _PangeaDateRangePickerModalState();
}

class _PangeaDateRangePickerModalState extends State<PangeaDateRangePickerModal> {
  late DateTime _startDate;
  late DateTime _endDate;
  late DateRangePreset _selectedPreset;
  late bool _compare;

  // Month navigation: display month for left calendar
  late DateTime _leftMonth;

  // Lagos time offset is UTC+1 (West Africa Time)
  static final DateTime _lagosNow = DateTime.now().toUtc().add(const Duration(hours: 1));
  static DateTime get today => DateTime(_lagosNow.year, _lagosNow.month, _lagosNow.day);

  final DateFormat _displayFormat = DateFormat('d MMMM yyyy');

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(widget.initialStartDate.year, widget.initialStartDate.month, widget.initialStartDate.day);
    _endDate = DateTime(widget.initialEndDate.year, widget.initialEndDate.month, widget.initialEndDate.day);
    _selectedPreset = widget.initialPreset;
    _compare = widget.initialCompare;

    // Center display month on start date
    _leftMonth = DateTime(_startDate.year, _startDate.month, 1);
  }

  DateTime get _rightMonth {
    final nextMonth = _leftMonth.month == 12 ? 1 : _leftMonth.month + 1;
    final nextYear = _leftMonth.month == 12 ? _leftMonth.year + 1 : _leftMonth.year;
    return DateTime(nextYear, nextMonth, 1);
  }

  void _prevMonth() {
    setState(() {
      final prevMonth = _leftMonth.month == 1 ? 12 : _leftMonth.month - 1;
      final prevYear = _leftMonth.month == 1 ? _leftMonth.year - 1 : _leftMonth.year;
      _leftMonth = DateTime(prevYear, prevMonth, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      final nextMonth = _leftMonth.month == 12 ? 1 : _leftMonth.month + 1;
      final nextYear = _leftMonth.month == 12 ? _leftMonth.year + 1 : _leftMonth.year;
      _leftMonth = DateTime(nextYear, nextMonth, 1);
    });
  }

  void _applyPreset(DateRangePreset preset) {
    final now = today;
    DateTime start;
    DateTime end = now;

    switch (preset) {
      case DateRangePreset.today:
        start = now;
        end = now;
        break;
      case DateRangePreset.yesterday:
        start = now.subtract(const Duration(days: 1));
        end = start;
        break;
      case DateRangePreset.todayAndYesterday:
        start = now.subtract(const Duration(days: 1));
        end = now;
        break;
      case DateRangePreset.last7Days:
        start = now.subtract(const Duration(days: 6));
        end = now;
        break;
      case DateRangePreset.last14Days:
        start = now.subtract(const Duration(days: 13));
        end = now;
        break;
      case DateRangePreset.last28Days:
        start = now.subtract(const Duration(days: 27));
        end = now;
        break;
      case DateRangePreset.last30Days:
        start = now.subtract(const Duration(days: 29));
        end = now;
        break;
      case DateRangePreset.thisWeek:
        // Week starting Sunday
        start = now.subtract(Duration(days: now.weekday % 7));
        end = now;
        break;
      case DateRangePreset.lastWeek:
        final thisWeekStart = now.subtract(Duration(days: now.weekday % 7));
        start = thisWeekStart.subtract(const Duration(days: 7));
        end = thisWeekStart.subtract(const Duration(days: 1));
        break;
      case DateRangePreset.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case DateRangePreset.lastMonth:
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        start = DateTime(prevYear, prevMonth, 1);
        final lastDay = DateTime(now.year, now.month, 0).day;
        end = DateTime(prevYear, prevMonth, lastDay);
        break;
      case DateRangePreset.custom:
        return;
    }

    setState(() {
      _selectedPreset = preset;
      _startDate = start;
      _endDate = end;
      _leftMonth = DateTime(start.year, start.month, 1);
    });
  }

  void _onDaySelected(DateTime date) {
    setState(() {
      _selectedPreset = DateRangePreset.custom;
      if (_startDate == _endDate && _startDate == date) {
        // Already selected single date
        return;
      }

      // If both dates are already different or clicking before current start, start fresh range
      if (_startDate != _endDate || date.isBefore(_startDate)) {
        _startDate = date;
        _endDate = date;
      } else {
        // Form the range
        _endDate = date;
      }
    });
  }

  String _getPresetLabel(DateRangePreset preset) {
    switch (preset) {
      case DateRangePreset.today:
        return 'Today';
      case DateRangePreset.yesterday:
        return 'Yesterday';
      case DateRangePreset.thisMonth:
        return 'This month';
      case DateRangePreset.todayAndYesterday:
        return 'Today and yesterday';
      case DateRangePreset.last7Days:
        return 'Last 7 days';
      case DateRangePreset.last14Days:
        return 'Last 14 days';
      case DateRangePreset.last28Days:
        return 'Last 28 days';
      case DateRangePreset.last30Days:
        return 'Last 30 days';
      case DateRangePreset.thisWeek:
        return 'This week';
      case DateRangePreset.lastWeek:
        return 'Last week';
      case DateRangePreset.lastMonth:
        return 'Last month';
      case DateRangePreset.custom:
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryBlue = Color(0xFF0077CC);
    final rangeHighlightColor = isDark
        ? const Color(0xFF0369A1).withValues(alpha: 0.35)
        : const Color(0xFFBAE6FD).withValues(alpha: 0.7);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 780,
          maxHeight: 560,
        ),
        child: Column(
          children: [
            // Main Body: Left Sidebar + Right Calendars
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Presets Sidebar
                  _buildSidebar(isDark, primaryBlue),

                  // Subtle vertical divider
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),

                  // Right Dual Month Calendars & Range Inputs
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dual Calendar View Side-by-Side
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Month Calendar
                                Expanded(
                                  child: _buildMonthCalendar(
                                    monthDate: _leftMonth,
                                    isLeft: true,
                                    isDark: isDark,
                                    primaryBlue: primaryBlue,
                                    rangeHighlightColor: rangeHighlightColor,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // Right Month Calendar
                                Expanded(
                                  child: _buildMonthCalendar(
                                    monthDate: _rightMonth,
                                    isLeft: false,
                                    isDark: isDark,
                                    primaryBlue: primaryBlue,
                                    rangeHighlightColor: rangeHighlightColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Compare checkbox
                          Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _compare,
                                  activeColor: primaryBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  side: BorderSide(
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                                    width: 1.5,
                                  ),
                                  onChanged: (val) => setState(() => _compare = val ?? false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Compare',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Dropdown + Formatted Date Boxes Row
                          _buildRangeInputBar(isDark, primaryBlue),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Footer Divider
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),

            // Modal Footer: Lagos Time + Cancel / Update Buttons
            _buildFooter(isDark, primaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isDark, Color primaryBlue) {
    return SizedBox(
      width: 200,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        children: [
          // Section 1: Recently used
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 6),
            child: Text(
              'Recently used',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
              ),
            ),
          ),
          _buildRadioPresetItem(DateRangePreset.today, 'Today', isDark, primaryBlue),
          _buildRadioPresetItem(DateRangePreset.yesterday, 'Yesterday', isDark, primaryBlue),
          _buildRadioPresetItem(DateRangePreset.thisMonth, 'This month', isDark, primaryBlue),

          const SizedBox(height: 6),
          Divider(
            height: 14,
            thickness: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 4),

          // Section 2: Extended Presets List
          _buildRadioPresetItem(DateRangePreset.today, 'Today', isDark, primaryBlue),
          _buildRadioPresetItem(DateRangePreset.yesterday, 'Yesterday', isDark, primaryBlue),
          _buildRadioPresetItem(DateRangePreset.todayAndYesterday, 'Today and yesterday', isDark, primaryBlue),
          _buildRadioPresetItem(DateRangePreset.last7Days, 'Last 7 days', isDark, primaryBlue),
          _buildRadioPresetItem(DateRangePreset.last14Days, 'Last 14 days', isDark, primaryBlue),
          _buildRadioPresetItem(DateRangePreset.last28Days, 'Last 28 days', isDark, primaryBlue),
          _buildRadioPresetItem(DateRangePreset.last30Days, 'Last 30 days', isDark, primaryBlue),
          _buildRadioPresetItem(DateRangePreset.thisWeek, 'This week', isDark, primaryBlue),
          _buildRadioPresetItem(DateRangePreset.lastWeek, 'Last week', isDark, primaryBlue),
          _buildRadioPresetItem(DateRangePreset.thisMonth, 'This month', isDark, primaryBlue),
          _buildRadioPresetItem(DateRangePreset.lastMonth, 'Last month', isDark, primaryBlue),
        ],
      ),
    );
  }

  Widget _buildRadioPresetItem(DateRangePreset preset, String label, bool isDark, Color primaryBlue) {
    final isSelected = _selectedPreset == preset;

    return InkWell(
      onTap: () => _applyPreset(preset),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? primaryBlue : (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryBlue,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthCalendar({
    required DateTime monthDate,
    required bool isLeft,
    required bool isDark,
    required Color primaryBlue,
    required Color rangeHighlightColor,
  }) {
    final monthName = DateFormat('MMM').format(monthDate);
    final yearStr = monthDate.year.toString();
    final firstWeekday = DateTime(monthDate.year, monthDate.month, 1).weekday % 7; // Sunday = 0
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;

    return Column(
      children: [
        // Month Navigation Header
        Row(
          children: [
            if (isLeft)
              IconButton(
                onPressed: _prevMonth,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
              )
            else
              const SizedBox(width: 28),
            const Spacer(),
            InkWell(
              onTap: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    monthName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, size: 18),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    yearStr,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, size: 18),
                ],
              ),
            ),
            const Spacer(),
            if (!isLeft)
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
              )
            else
              const SizedBox(width: 28),
          ],
        ),

        const SizedBox(height: 8),

        // Weekday Headers: Sun Mon Tue Wed Thu Fri Sat
        Row(
          children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 6),

        // Grid of Days
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellHeight = constraints.maxHeight / 6;

              return Column(
                children: List.generate(6, (row) {
                  return SizedBox(
                    height: cellHeight,
                    child: Row(
                      children: List.generate(7, (col) {
                        final cellIndex = row * 7 + col;
                        final dayNumber = cellIndex - firstWeekday + 1;

                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return const Expanded(child: SizedBox());
                        }

                        final currentDay = DateTime(monthDate.year, monthDate.month, dayNumber);
                        final isStart = currentDay.isAtSameMomentAs(_startDate);
                        final isEnd = currentDay.isAtSameMomentAs(_endDate);
                        final isInRange = currentDay.isAfter(_startDate) && currentDay.isBefore(_endDate);

                        return Expanded(
                          child: InkWell(
                            onTap: () => _onDaySelected(currentDay),
                            borderRadius: BorderRadius.circular(isStart || isEnd ? 100 : 0),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Range background band
                                if (isInRange)
                                  Positioned.fill(
                                    child: Container(
                                      color: rangeHighlightColor,
                                    ),
                                  )
                                else if (isStart && !_startDate.isAtSameMomentAs(_endDate))
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    bottom: 0,
                                    left: constraints.maxWidth / 14,
                                    child: Container(
                                      color: rangeHighlightColor,
                                    ),
                                  )
                                else if (isEnd && !_startDate.isAtSameMomentAs(_endDate))
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    right: constraints.maxWidth / 14,
                                    child: Container(
                                      color: rangeHighlightColor,
                                    ),
                                  ),

                                // Day Circle
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (isStart || isEnd) ? primaryBlue : Colors.transparent,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    dayNumber.toString(),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: (isStart || isEnd) ? FontWeight.w700 : FontWeight.w500,
                                      color: (isStart || isEnd)
                                          ? Colors.white
                                          : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRangeInputBar(bool isDark, Color primaryBlue) {
    return Row(
      children: [
        // Dropdown for Preset
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DateRangePreset>(
              value: _selectedPreset,
              icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              items: DateRangePreset.values.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(_getPresetLabel(p)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) _applyPreset(val);
              },
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Start Date Input Display
        Expanded(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              _displayFormat.format(_startDate),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '-',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),

        // End Date Input Display
        Expanded(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              _displayFormat.format(_endDate),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDark, Color primaryBlue) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text(
            'Dates are shown in Lagos Time',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              side: BorderSide(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(
                PangeaDateRangeResult(
                  startDate: _startDate,
                  endDate: _endDate,
                  preset: _selectedPreset,
                  compareWithPreviousPeriod: _compare,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              'Update',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
