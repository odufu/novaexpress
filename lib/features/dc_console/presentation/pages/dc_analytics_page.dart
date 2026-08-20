import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class DCAnalyticsPage extends ConsumerWidget {
  const DCAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Analytics & Hub SLA Reports', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Historical delivery throughput, SLA performance curves and official reconciliation audits', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📄 Generated Daily Operations Report PDF.')),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
                    label: const Text('Export PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B192C)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📊 Exported Ledger CSV.')),
                      );
                    },
                    icon: const Icon(Icons.table_chart_rounded, size: 16),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // SLA Metrics Grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: [
              _buildMetricCard('First-Attempt Success Rate', '94.2%', '+2.1% vs Target', const Color(0xFF10B981), isDark),
              _buildMetricCard('Average Hub Fulfillment SLA', '24.5 min', 'Target: 25.0 min', const Color(0xFF2563EB), isDark),
              _buildMetricCard('Damaged / QC Write-Off Rate', '0.4%', '-0.1% vs Benchmark', const Color(0xFF8B5CF6), isDark),
            ],
          ),

          const SizedBox(height: 20),

          // Zone Turnaround Time Analysis Table
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Zone Performance & Turnaround Velocity', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                _buildZoneRow('Wuse Zone II & IV', '21.2 min', '98.5% Success', '4 Active Units'),
                const Divider(height: 1, color: Color(0xFF334155)),
                _buildZoneRow('Maitama & Ministers Hill', '24.0 min', '94.0% Success', '3 Active Units'),
                const Divider(height: 1, color: Color(0xFF334155)),
                _buildZoneRow('Garki I & II', '28.1 min', '91.8% Success', '3 Active Units'),
                const Divider(height: 1, color: Color(0xFF334155)),
                _buildZoneRow('Asokoro & Guzape', '26.4 min', '96.2% Success', '2 Active Units'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, String sub, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          Text(val, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(sub, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildZoneRow(String zone, String avgTime, String success, String fleet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(zone, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(avgTime, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
          Text(success, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
          Text(fleet, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
