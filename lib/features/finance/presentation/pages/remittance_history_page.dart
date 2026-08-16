import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';

class RemittanceHistoryPage extends StatefulWidget {
  const RemittanceHistoryPage({super.key});

  @override
  State<RemittanceHistoryPage> createState() => _RemittanceHistoryPageState();
}

class _RemittanceHistoryPageState extends State<RemittanceHistoryPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'REMITTANCE HISTORY',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: AppLogoWidget(
              variant: AppLogoVariant.landscape,
              height: 24,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Cards (TOTAL REMITTED & PENDING VERIFICATION) matching screen.png
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL REMITTED',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₦4.2M',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PENDING VERIFICATION',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₦150K',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar & Filter Button Row matching screen.png
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.jetBrainsMono(fontSize: 14, color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search by ID or Date...',
                      hintStyle: GoogleFonts.jetBrainsMono(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant),
                      fillColor: theme.cardColor,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.tune_rounded, color: theme.colorScheme.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Remittance Card 1: RM-8924-A (VERIFIED)
            _HistoryRemittanceCard(
              id: 'RM-8924-A',
              amount: 120500,
              statusText: 'VERIFIED',
              statusBgColor: const Color(0xFF00522A),
              statusIcon: Icons.check_circle_outline_rounded,
              date: 'Oct 24, 2023 • 14:30',
              onTap: () => context.push('/cash/remittance/RM-8924-A'),
            ),
            const SizedBox(height: 12),

            // Remittance Card 2: RM-8925-B (PENDING)
            _HistoryRemittanceCard(
              id: 'RM-8925-B',
              amount: 45000,
              statusText: 'PENDING',
              statusBgColor: AppColors.orange,
              statusIcon: Icons.schedule_rounded,
              date: 'Oct 25, 2023 • 09:15',
              onTap: () => context.push('/cash/remittance/RM-8925-B'),
            ),
            const SizedBox(height: 12),

            // Remittance Card 3: RM-8921-C (REJECTED with FIX ISSUE button)
            _HistoryRemittanceCard(
              id: 'RM-8921-C',
              amount: 85000,
              statusText: 'REJECTED',
              statusBgColor: const Color(0xFF2D3133),
              statusIcon: Icons.error_outline_rounded,
              date: 'Oct 23, 2023 • 16:45',
              warningMessage: 'Illegible receipt photo. Please re-upload a clearer image.',
              hasRedLeftAccent: true,
              isFixable: true,
              onTap: () => context.push('/cash/remittance/REM-1040'),
            ),
            const SizedBox(height: 12),

            // Remittance Card 4: RM-8910-A (VERIFIED)
            _HistoryRemittanceCard(
              id: 'RM-8910-A',
              amount: 210000,
              statusText: 'VERIFIED',
              statusBgColor: const Color(0xFF00522A),
              statusIcon: Icons.check_circle_outline_rounded,
              date: 'Oct 20, 2023 • 11:20',
              onTap: () => context.push('/cash/remittance/RM-8910-A'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRemittanceCard extends StatelessWidget {
  final String id;
  final double amount;
  final String statusText;
  final Color statusBgColor;
  final IconData statusIcon;
  final String date;
  final String? warningMessage;
  final bool hasRedLeftAccent;
  final bool isFixable;
  final VoidCallback onTap;

  const _HistoryRemittanceCard({
    required this.id,
    required this.amount,
    required this.statusText,
    required this.statusBgColor,
    required this.statusIcon,
    required this.date,
    this.warningMessage,
    this.hasRedLeftAccent = false,
    this.isFixable = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              if (hasRedLeftAccent)
                Container(
                  width: 5,
                  color: const Color(0xFFBA1A1A),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            id,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.formatNaira(amount),
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),

                      // Rejected Warning Box matching screen.png
                      if (warningMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDAD6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFF93000A), size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  warningMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFF93000A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(
                                date,
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                              ),
                            ],
                          ),
                          if (isFixable)
                            GestureDetector(
                              onTap: onTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFBA1A1A),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'FIX ISSUE',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: onTap,
                              child: Row(
                                children: [
                                  Text(
                                    'VIEW',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right_rounded, size: 16, color: theme.colorScheme.onSurface),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
