import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';

class RemittanceDetailsPage extends StatefulWidget {
  final String remittanceId;

  const RemittanceDetailsPage({
    super.key,
    required this.remittanceId,
  });

  @override
  State<RemittanceDetailsPage> createState() => _RemittanceDetailsPageState();
}

class _RemittanceDetailsPageState extends State<RemittanceDetailsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Mock details based on ID matching remittance_details/screen.png
    final isRejected = widget.remittanceId == 'REM-1040' || widget.remittanceId == 'RM-8921-C';
    final isVerified = widget.remittanceId == 'RM-8924-A' || widget.remittanceId == 'RM-8910-A';
    
    final displayId = widget.remittanceId.startsWith('RM') ? widget.remittanceId : 'REM-1042';
    final double amount = isRejected ? 85000.0 : (isVerified ? 120500.0 : 45250.0);

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
          'REMITTANCE DETAILS',
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
            // Back to History navigation button matching screen.png
            GestureDetector(
              onTap: () => context.pop(),
              child: Row(
                children: [
                  Icon(Icons.arrow_back_rounded, size: 16, color: theme.colorScheme.onSurface),
                  const SizedBox(width: 6),
                  Text(
                    'BACK TO HISTORY',
                    style: GoogleFonts.jetBrainsMono(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Hero Status Container matching remittance_details/screen.png
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isRejected
                    ? const Color(0xFF311300)
                    : (isVerified ? const Color(0xFF003318) : const Color(0xFF422000)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isRejected
                              ? const Color(0xFFBA1A1A)
                              : (isVerified ? const Color(0xFF00522A) : AppColors.orange),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isRejected
                              ? 'REJECTED'
                              : (isVerified ? 'VERIFIED' : 'PENDING VERIFICATION'),
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        displayId,
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF8293B5),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    CurrencyFormatter.formatNaira(amount),
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bank Transfer • First Bank (NoveXPS Main)',
                    style: TextStyle(
                      color: Color(0xFFE0E3E5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Remittance Info Card matching screen.png
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2), width: 1),
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'Submitted Date', value: 'Oct 24, 2023 • 14:30'),
                  const Divider(height: 1),
                  _DetailRow(label: 'Destination Bank', value: 'First Bank of Nigeria'),
                  const Divider(height: 1),
                  _DetailRow(label: 'Account Number', value: '3049281092 (NoveXPS Main)'),
                  const Divider(height: 1),
                  _DetailRow(label: 'Transfer Reference', value: 'TXN-883920194'),
                  const Divider(height: 1),
                  _DetailRow(label: 'Agent ID', value: 'PDA-402 (Babatunde Lawal)'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Proof of Payment Photo Card matching screen.png
            Text(
              'Proof of Payment Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      color: theme.colorScheme.surfaceContainer,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_rounded, color: AppColors.orange, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              'Receipt Photo Attached',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap to expand full screen',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Audit Trail Timeline matching screen.png
            Text(
              'Audit Trail',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _TimelineItem(
              title: 'Submitted by Agent',
              subtitle: 'Oct 24, 2023 • 14:30',
              isCompleted: true,
            ),
            _TimelineItem(
              title: 'Pending Finance Verification',
              subtitle: 'Assigned to Finance Desk',
              isCompleted: !isRejected,
            ),
            _TimelineItem(
              title: isVerified ? 'Verified & Approved' : (isRejected ? 'Rejected by Finance' : 'Final Reconciliation'),
              subtitle: isVerified ? 'Oct 24, 2023 • 15:10' : (isRejected ? 'Illegible receipt photo' : 'Pending review'),
              isCompleted: isVerified,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isLast;

  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF00522A) : theme.colorScheme.surfaceContainer,
                shape: BoxShape.circle,
                border: Border.all(color: isCompleted ? const Color(0xFF00522A) : theme.colorScheme.onSurfaceVariant),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 10)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: theme.colorScheme.surfaceContainer,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
