import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo_widget.dart';

class LogRemittancePage extends StatefulWidget {
  const LogRemittancePage({super.key});

  @override
  State<LogRemittancePage> createState() => _LogRemittancePageState();
}

class _LogRemittancePageState extends State<LogRemittancePage> {
  String _selectedMethod = 'Bank Transfer'; // 'Bank Transfer' or 'Cash Deposit'
  final TextEditingController _amountController = TextEditingController(text: '45250.00');
  String _selectedBank = 'First Bank (NoveXPS Main)';
  final TextEditingController _referenceController = TextEditingController(text: 'TXN-883920194');
  
  String _selectedDc = 'Wuse Distribution Center';
  final TextEditingController _cashSlipNotesController = TextEditingController();

  final List<String> _bankOptions = [
    'First Bank (NoveXPS Main)',
    'GTBank (NoveXPS Operations)',
    'Zenith Bank (NoveXPS Escrow)',
  ];

  final List<String> _dcOptions = [
    'Wuse Distribution Center',
    'Garki Distribution Center',
    'Maitama Main Hub',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _cashSlipNotesController.dispose();
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
          'LOG REMITTANCE',
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
            // Cash-on-Hand Banner matching log_remittance/screen.png
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF031632),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CASH-ON-HAND',
                        style: TextStyle(
                          color: Color(0xFF8293B5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2B48),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'PDA-402',
                          style: TextStyle(
                            color: Color(0xFF8293B5),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₦45,250.00',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Abuja Central Route • Today',
                    style: TextStyle(
                      color: Color(0xFFE0E3E5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Remittance Method Toggle matching log_remittance/screen.png
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMethod = 'Bank Transfer'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedMethod == 'Bank Transfer'
                            ? AppColors.primary
                            : theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Bank Transfer',
                          style: TextStyle(
                            color: _selectedMethod == 'Bank Transfer' ? Colors.white : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMethod = 'Cash Deposit'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _selectedMethod == 'Cash Deposit'
                            ? AppColors.primary
                            : theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Cash Deposit',
                          style: TextStyle(
                            color: _selectedMethod == 'Cash Deposit' ? Colors.white : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Form Fields matching log_remittance/screen.png
            Text(
              'Amount to Remit (₦)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                prefixText: '₦ ',
                prefixStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.orange,
                ),
                fillColor: theme.cardColor,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedMethod == 'Bank Transfer') ...[
              Text(
                'Destination Bank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _bankOptions.contains(_selectedBank) ? _selectedBank : _bankOptions.first,
                    isExpanded: true,
                    dropdownColor: theme.cardColor,
                    style: GoogleFonts.jetBrainsMono(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                    items: _bankOptions.map((bank) {
                      return DropdownMenuItem<String>(
                        value: bank,
                        child: Text(bank),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBank = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Transfer Reference Number',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _referenceController,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  fillColor: theme.cardColor,
                  filled: true,
                ),
              ),
            ] else ...[
              Text(
                'Receiving Distribution Center (DC)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dcOptions.contains(_selectedDc) ? _selectedDc : _dcOptions.first,
                    isExpanded: true,
                    dropdownColor: theme.cardColor,
                    style: GoogleFonts.jetBrainsMono(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    ),
                    items: _dcOptions.map((dc) {
                      return DropdownMenuItem<String>(
                        value: dc,
                        child: Text(dc),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDc = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Deposit Slip Notes / Cashier Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _cashSlipNotesController,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g., Handed to Cashier Musa at Wuse DC counter',
                  fillColor: theme.cardColor,
                  filled: true,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Proof of Payment Upload Box matching log_remittance/screen.png
            Text(
              'Proof of Payment (Required)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.orange,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: AppColors.orange, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap to add receipt or slip photo',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PNG, JPG up to 10MB',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button with Arrow ➢ matching log_remittance/screen.png
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Remittance submitted successfully for Finance verification!'),
                      backgroundColor: Color(0xFF00522A),
                    ),
                  );
                  context.push('/cash/history');
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Submit for Verification',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
