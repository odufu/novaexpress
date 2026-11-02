import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/merchant_bi_message.dart';

class MerchantBIFlowchartWidget extends StatelessWidget {
  final MerchantBIChartPayload payload;
  final bool isDark;

  const MerchantBIFlowchartWidget({
    super.key,
    required this.payload,
    required this.isDark,
  });

  IconData _resolveIcon(String? iconName) {
    switch (iconName) {
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'route':
        return Icons.alt_route_rounded;
      case 'two_wheeler':
        return Icons.two_wheeler_rounded;
      case 'verified':
        return Icons.verified_rounded;
      case 'payments':
        return Icons.payments_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'phone_missed':
        return Icons.phone_missed_rounded;
      case 'support_agent':
        return Icons.support_agent_rounded;
      case 'refresh':
        return Icons.replay_rounded;
      case 'check_circle':
        return Icons.check_circle_rounded;
      case 'warehouse':
        return Icons.warehouse_rounded;
      case 'receipt':
        return Icons.receipt_long_rounded;
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      case 'qr_code_scanner':
        return Icons.qr_code_scanner_rounded;
      case 'inventory_2':
        return Icons.inventory_2_rounded;
      case 'campaign':
        return Icons.campaign_rounded;
      case 'headset_mic':
        return Icons.headset_mic_rounded;
      case 'record_voice_over':
        return Icons.record_voice_over_rounded;
      case 'send':
        return Icons.send_rounded;
      default:
        return Icons.schema_rounded;
    }
  }

  Color _resolveNodeColor(String type) {
    switch (type) {
      case 'start':
        return const Color(0xFF3B82F6); // Blue
      case 'process':
        return const Color(0xFF0D9488); // Teal
      case 'decision':
        return const Color(0xFFF59E0B); // Amber
      case 'success':
        return const Color(0xFF10B981); // Emerald
      case 'warning':
        return const Color(0xFFEF4444); // Rose
      default:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = payload.flowchartNodes ?? [];
    final connections = payload.flowchartConnections ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payload.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (payload.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        payload.subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_tree_rounded,
                      size: 11,
                      color: Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'FLOWCHART',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0D9488),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Flowchart Pipeline Nodes
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: nodes.length,
            itemBuilder: (context, index) {
              final node = nodes[index];
              final isLast = index == nodes.length - 1;
              final nodeColor = _resolveNodeColor(node.nodeType);

              // Find connector label if any
              String? connectorLabel;
              if (!isLast && index < connections.length) {
                connectorLabel = connections[index].label;
              }

              return Column(
                children: [
                  // The Node Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: nodeColor.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step number + icon badge
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: nodeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: nodeColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _resolveIcon(node.iconName),
                              size: 18,
                              color: nodeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Node Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${node.stepNumber}. ${node.title}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  if (node.tag != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            nodeColor.withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        node.tag!,
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: nodeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                node.description,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Connecting Arrow and Line between nodes
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 1.5,
                            height: 12,
                            color: nodeColor.withValues(alpha: 0.4),
                          ),
                          if (connectorLabel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                connectorLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 1.5,
                              height: 12,
                              color: nodeColor.withValues(alpha: 0.4),
                            ),
                          ],
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 14,
                            color: nodeColor.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

