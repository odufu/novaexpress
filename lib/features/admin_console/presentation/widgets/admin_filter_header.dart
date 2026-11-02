import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/nova_tooltip.dart';

/// Standardized filter and control header used at the top of every resource table.
class AdminFilterHeader extends StatelessWidget {
  final String searchHint;
  final String searchValue;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final String? actionButtonText;
  final IconData actionButtonIcon;
  final VoidCallback? onActionButtonPressed;
  final List<Widget> filterDropdowns;
  final int count;
  final String countLabel;

  const AdminFilterHeader({
    super.key,
    required this.searchHint,
    required this.searchValue,
    required this.onSearchChanged,
    required this.onClearSearch,
    this.actionButtonText,
    this.actionButtonIcon = Icons.add_rounded,
    this.onActionButtonPressed,
    this.filterDropdowns = const [],
    required this.count,
    required this.countLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchInput(isDark),
                if (filterDropdowns.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: filterDropdowns,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCountPill(isDark),
                    if (actionButtonText != null && onActionButtonPressed != null)
                      _buildActionButton(),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                // Search Input
                Expanded(
                  flex: 3,
                  child: _buildSearchInput(isDark),
                ),
                const SizedBox(width: 12),

                // Filters
                if (filterDropdowns.isNotEmpty) ...[
                  ...filterDropdowns.map((d) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: d,
                      )),
                ],

                // Count Pill
                _buildCountPill(isDark),
                const SizedBox(width: 12),

                // Action Button
                if (actionButtonText != null && onActionButtonPressed != null)
                  _buildActionButton(),
              ],
            ),
    );
  }

  Widget _buildSearchInput(bool isDark) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 0.8,
        ),
      ),
      child: TextField(
        controller: TextEditingController(text: searchValue)
          ..selection = TextSelection.collapsed(offset: searchValue.length),
        onChanged: onSearchChanged,
        style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          isDense: true,
          hintText: searchHint,
          hintStyle: GoogleFonts.inter(
            fontSize: 12.5,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          suffixIcon: searchValue.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: onClearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildCountPill(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count $countLabel',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return NovaTooltip(
      message: 'Create a new $countLabel entry in database',
      child: ElevatedButton.icon(
        onPressed: onActionButtonPressed,
        icon: Icon(actionButtonIcon, size: 16, color: Colors.white),
        label: Text(
          actionButtonText!,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
