import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// State 6: No Search Results State
/// Prevents dead-ends when queries or filters yield zero records.
/// Suggests alternative terms and provides one-tap filter reset.
class NovaNoSearchResultsState extends StatelessWidget {
  final String? searchQuery;
  final String? filterContext;
  final VoidCallback? onClearSearch;
  final VoidCallback? onClearFilters;
  final List<String> activeFilters;
  final List<String>? suggestions;
  final ValueChanged<String>? onSuggestionSelected;

  const NovaNoSearchResultsState({
    super.key,
    this.searchQuery,
    this.filterContext,
    this.onClearSearch,
    this.onClearFilters,
    this.activeFilters = const [],
    this.suggestions,
    this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveSuggestions = suggestions ?? [
      'Search by Waybill # (e.g. NOVA-)',
      'Search by Recipient Phone',
      'Search by City or LGA',
      'Search by Product SKU',
    ];

    final effectiveClear = onClearFilters ?? onClearSearch;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Badge
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155).withValues(alpha: 0.4)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.search_off_rounded,
                    size: 36,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'No Results Found',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              // Query Highlight
              if (searchQuery != null && searchQuery!.trim().isNotEmpty) ...[
                Text(
                  'No logistics records matched "$searchQuery". Check for spelling errors or broaden your query.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ] else ...[
                Text(
                  'No logistics records match the current active filters or criteria.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],

              // Filter context badge
              if (filterContext != null && filterContext!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF37021).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF37021).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Filter: $filterContext',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF37021),
                    ),
                  ),
                ),
              ],

              // Active Filters list
              if (activeFilters.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: activeFilters.map((f) {
                    return Chip(
                      label: Text(
                        f,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),

              // Search Suggestions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEARCH SUGGESTIONS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...effectiveSuggestions.map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.arrow_right_rounded,
                              size: 16,
                              color: Color(0xFFF37021),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                s,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Clear Filters Button
              if (effectiveClear != null)
                ElevatedButton.icon(
                  onPressed: effectiveClear,
                  icon: const Icon(Icons.clear_all_rounded, size: 18, color: Colors.white),
                  label: Text(
                    'Clear All Filters',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF031632),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

