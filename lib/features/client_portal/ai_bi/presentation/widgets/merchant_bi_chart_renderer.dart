import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/merchant_bi_message.dart';
import 'merchant_bi_donut_chart.dart';
import 'merchant_bi_flowchart_widget.dart';
import 'merchant_bi_mermaid_widget.dart';
import 'merchant_bi_trend_chart.dart';

class MerchantBIChartRenderer extends StatelessWidget {
  final MerchantBIChartPayload payload;
  final bool isDark;

  const MerchantBIChartRenderer({
    super.key,
    required this.payload,
    required this.isDark,
  });

  IconData _resolveMetricIcon(String name) {
    switch (name) {
      case 'monetization_on':
      case 'payments':
        return Icons.monetization_on_rounded;
      case 'check_circle':
      case 'task_alt':
      case 'verified':
        return Icons.check_circle_rounded;
      case 'inventory':
      case 'warehouse':
        return Icons.warehouse_rounded;
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      case 'savings':
      case 'account_balance':
        return Icons.savings_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'calendar_today':
        return Icons.calendar_today_rounded;
      case 'speed':
        return Icons.speed_rounded;
      case 'fingerprint':
        return Icons.fingerprint_rounded;
      case 'security':
        return Icons.shield_rounded;
      case 'verified_user':
        return Icons.verified_user_rounded;
      default:
        return Icons.insights_rounded;
    }
  }

  Widget _buildMetricBadges(List<MetricBadgeItem> badges) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 400;

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges.map((m) {
              final width = isNarrow
                  ? (constraints.maxWidth - 8) / 2
                  : (constraints.maxWidth - 16) / 3;

              final isPositive = m.isPositive;
              final accentColor = isPositive == true
                  ? const Color(0xFF10B981)
                  : (isPositive == false
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF6366F1));

              return Container(
                width: width,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            m.label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          _resolveMetricIcon(m.iconName),
                          size: 14,
                          color: accentColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.value,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (m.changeLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        m.changeLabel!,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget? mainVisual;

    switch (payload.type) {
      case BIChartType.donut:
        mainVisual = MerchantBIDonutChart(payload: payload, isDark: isDark);
        break;
      case BIChartType.trend:
        mainVisual = MerchantBITrendChart(payload: payload, isDark: isDark);
        break;
      case BIChartType.flowchart:
        mainVisual = MerchantBIFlowchartWidget(payload: payload, isDark: isDark);
        break;
      case BIChartType.metricCards:
        mainVisual = null;
        break;
      case BIChartType.mermaid:
        mainVisual = MerchantBIMermaidWidget(payload: payload, isDark: isDark);
        break;
    }

    final hasBadges = payload.metricBadges != null && payload.metricBadges!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mainVisual != null) mainVisual,
        if (hasBadges) _buildMetricBadges(payload.metricBadges!),
      ],
    );
  }
}

