import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/nova_tooltip.dart';

/// Minimalist, high-density metric card adhering to Linear/Stripe design standards.
/// Emphasizes clear numbers, intuitive icons, and zero visual clutter.
class AdminMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final String? tooltip;
  final Widget? trailingBadge;

  const AdminMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = const Color(0xFFF37021),
    this.subtitle,
    this.tooltip,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 190,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: iconColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tooltip != null) ...[
                      const SizedBox(width: 4),
                      NovaInfoIcon(message: tooltip!),
                    ],
                  ],
                ),
              ),
              if (trailingBadge != null) trailingBadge!,
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
    ),
    );
  }
}

/// Data carrier for admin metrics, supporting both compact ribbon and expanded card views.
class AdminMetricData {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final String? tooltip;
  final Widget? trailingBadge;

  const AdminMetricData({
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = const Color(0xFFF37021),
    this.subtitle,
    this.tooltip,
    this.trailingBadge,
  });
}

/// Ultra-compact, high-density metric ribbon that preserves maximum vertical space
/// for the primary data table, with an optional expand/collapse toggle for full card view.
class AdminMetricsHeader extends StatefulWidget {
  final List<AdminMetricData> metrics;
  final bool initialExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const AdminMetricsHeader({
    super.key,
    required this.metrics,
    this.initialExpanded = true, // Default to Full KPI Cards!
    this.onExpansionChanged,
  });

  @override
  State<AdminMetricsHeader> createState() => _AdminMetricsHeaderState();
}

class _AdminMetricsHeaderState extends State<AdminMetricsHeader> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    if (!_isExpanded) {
      // Ultra-Compact Ribbon Mode (~38px height)
      return Container(
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < widget.metrics.length; i++) ...[
                      if (i > 0) ...[
                        const SizedBox(width: 10),
                        Container(height: 14, width: 1, color: borderColor),
                        const SizedBox(width: 10),
                      ],
                      _buildCompactMetricItem(widget.metrics[i], isDark),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(height: 14, width: 1, color: borderColor),
            const SizedBox(width: 8),
            // Expand Toggle Button
            Tooltip(
              message: 'Show detailed metric cards',
              child: InkWell(
                onTap: () {
                  setState(() => _isExpanded = true);
                  widget.onExpansionChanged?.call(true);
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.unfold_more_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'Full KPIs',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Expanded Grid Mode
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with Collapse Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Key Performance Indicators',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            InkWell(
              onTap: () {
                setState(() => _isExpanded = false);
                widget.onExpansionChanged?.call(false);
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.unfold_less_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'Compact KPIs',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final crossAxisCount = isWide ? 4 : (constraints.maxWidth >= 600 ? 2 : 1);
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isWide ? 2.5 : 2.7,
              children: widget.metrics
                  .map((m) => AdminMetricCard(
                        title: m.title,
                        value: m.value,
                        icon: m.icon,
                        iconColor: m.iconColor,
                        subtitle: m.subtitle,
                        tooltip: m.tooltip,
                        trailingBadge: m.trailingBadge,
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompactMetricItem(AdminMetricData m, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: m.iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(m.icon, size: 12, color: m.iconColor),
        ),
        const SizedBox(width: 6),
        Text(
          m.value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          m.title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        if (m.tooltip != null) ...[
          const SizedBox(width: 4),
          NovaInfoIcon(message: m.tooltip!),
        ],
        if (m.trailingBadge != null) ...[
          const SizedBox(width: 4),
          m.trailingBadge!,
        ],
      ],
    );
  }
}
