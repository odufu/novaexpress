import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Represents a single option item in the [NovaSearchablePickerModal]
class NovaPickerOption<T> {
  final T value;
  final String title;
  final String? subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final IconData? icon;
  final Widget? leading;
  final String? trailingText;
  final Color? trailingTextColor;
  final List<String> searchTerms;

  const NovaPickerOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.badgeText,
    this.badgeColor,
    this.icon,
    this.leading,
    this.trailingText,
    this.trailingTextColor,
    this.searchTerms = const [],
  });

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    if (title.toLowerCase().contains(q)) return true;
    if (subtitle != null && subtitle!.toLowerCase().contains(q)) return true;
    if (badgeText != null && badgeText!.toLowerCase().contains(q)) return true;
    for (final term in searchTerms) {
      if (term.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

/// A modern, mobile-optimized, searchable bottom sheet selector modal
/// Replaces clumsy Flutter [DropdownButtonFormField] which overlays on headers and clips text.
class NovaSearchablePickerModal<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData? titleIcon;
  final Color? titleIconColor;
  final List<NovaPickerOption<T>> options;
  final T? selectedValue;
  final String searchHint;

  const NovaSearchablePickerModal({
    super.key,
    required this.title,
    this.subtitle,
    this.titleIcon,
    this.titleIconColor,
    required this.options,
    this.selectedValue,
    this.searchHint = 'Search by name, code or keyword...',
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData? titleIcon,
    Color? titleIconColor,
    required List<NovaPickerOption<T>> options,
    T? selectedValue,
    String searchHint = 'Search by name, code or keyword...',
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NovaSearchablePickerModal<T>(
        title: title,
        subtitle: subtitle,
        titleIcon: titleIcon,
        titleIconColor: titleIconColor,
        options: options,
        selectedValue: selectedValue,
        searchHint: searchHint,
      ),
    );
  }

  @override
  State<NovaSearchablePickerModal<T>> createState() =>
      _NovaSearchablePickerModalState<T>();
}

class _NovaSearchablePickerModalState<T>
    extends State<NovaSearchablePickerModal<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = widget.titleIconColor ?? const Color(0xFF0284C7);

    final filteredOptions = widget.options
        .where((opt) => opt.matches(_searchQuery))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Modal Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                if (widget.titleIcon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.titleIcon, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Live Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
          ),

          // Options List
          Flexible(
            child: filteredOptions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No matching items found',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try searching with a different keyword or SKU code',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shrinkWrap: true,
                    itemCount: filteredOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final opt = filteredOptions[index];
                      final isSelected = widget.selectedValue != null &&
                          opt.value == widget.selectedValue;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(opt.value),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.1)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? primaryColor
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Leading icon or widget
                                if (opt.leading != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: opt.leading!,
                                  )
                                else if (opt.icon != null)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: (opt.badgeColor ?? primaryColor).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(opt.icon, color: opt.badgeColor ?? primaryColor, size: 20),
                                  ),

                                // Title and Subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          if (opt.badgeText != null) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              margin: const EdgeInsets.only(right: 6),
                                              decoration: BoxDecoration(
                                                color: (opt.badgeColor ?? primaryColor).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                opt.badgeText!,
                                                style: GoogleFonts.inter(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: opt.badgeColor ?? primaryColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                          Expanded(
                                            child: Text(
                                              opt.title,
                                              style: GoogleFonts.inter(
                                                fontSize: 13.5,
                                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (opt.subtitle != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          opt.subtitle!,
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Trailing text badge or checkmark
                                if (opt.trailingText != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (opt.trailingTextColor ?? primaryColor).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      opt.trailingText!,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: opt.trailingTextColor ?? primaryColor,
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(width: 8),
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  color: isSelected
                                      ? primaryColor
                                      : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A sleek form-field replacement for [DropdownButtonFormField]
/// Renders a tappable field with leading icon, badge, full multi-line title, and chevron.
/// Tapping it smoothly opens [NovaSearchablePickerModal].
class NovaSearchableSelectField<T> extends StatelessWidget {
  final String label;
  final String placeholder;
  final T? value;
  final List<NovaPickerOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String pickerTitle;
  final String? pickerSubtitle;
  final IconData? prefixIcon;
  final Color? brandColor;
  final String? errorText;

  const NovaSearchableSelectField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.pickerTitle,
    this.pickerSubtitle,
    this.prefixIcon,
    this.brandColor,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = brandColor ?? const Color(0xFF0284C7);

    // Find active option
    NovaPickerOption<T>? selectedOpt;
    for (final opt in options) {
      if (opt.value == value) {
        selectedOpt = opt;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final selected = await NovaSearchablePickerModal.show<T>(
                context,
                title: pickerTitle,
                subtitle: pickerSubtitle,
                titleIcon: prefixIcon,
                titleIconColor: primaryColor,
                options: options,
                selectedValue: value,
              );
              if (selected != null) {
                onChanged(selected);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: errorText != null
                      ? const Color(0xFFEF4444)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  width: errorText != null ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  if (prefixIcon != null) ...[
                    Icon(
                      prefixIcon,
                      size: 20,
                      color: selectedOpt != null
                          ? primaryColor
                          : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: selectedOpt != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  if (selectedOpt.badgeText != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: (selectedOpt.badgeColor ?? primaryColor).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        selectedOpt.badgeText!,
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: selectedOpt.badgeColor ?? primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                  Expanded(
                                    child: Text(
                                      selectedOpt.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (selectedOpt.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  selectedOpt.subtitle!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          )
                        : Text(
                            placeholder,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFEF4444),
            ),
          ),
        ],
      ],
    );
  }
}
