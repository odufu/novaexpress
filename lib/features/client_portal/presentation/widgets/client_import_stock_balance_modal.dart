import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/client_portal_provider.dart';

class ClientImportStockBalanceModal extends ConsumerStatefulWidget {
  const ClientImportStockBalanceModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ClientImportStockBalanceModal(),
    );
  }

  @override
  ConsumerState<ClientImportStockBalanceModal> createState() => _ClientImportStockBalanceModalState();
}

class _ClientImportStockBalanceModalState extends ConsumerState<ClientImportStockBalanceModal> {
  final _csvController = TextEditingController();
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  bool _isProcessing = false;
  int _parsedRowCount = 0;
  double _parsedTotalValuation = 0.0;
  String? _previewError;

  static const String _pangeaSampleHeader =
      'Item,Item Name,Item Group,Warehouse,Stock UOM,Balance Qty,Balance Value,Opening Qty,Opening Value,In Qty,In Value,Out Qty,Out Value,Valuation Rate,Reserved Stock,Company';

  static const String _pangeaSampleData = '''Item,Item Name,Item Group,Warehouse,Stock UOM,Balance Qty,Balance Value,Opening Qty,Opening Value,In Qty,In Value,Out Qty,Out Value,Valuation Rate,Reserved Stock,Company
Grazer Herbal Tea (20 Tea Bags),Grazer Herbal Tea (20 Tea Bags),Products,Central Abuja Hub - Grand DC,Nos,540,1030620.24,540,1030620.24,0,0,0,0,1908.556,0,Novacare Ltd
Grazer Herbal Tea (20 Tea Bags),Grazer Herbal Tea (20 Tea Bags),Products,Lagos Ikeja Main Station - DC,Nos,420,801593.52,420,801593.52,0,0,0,0,1908.556,0,Novacare Ltd
Grazer Herbal Tea (20 Tea Bags),Grazer Herbal Tea (20 Tea Bags),Products,Port Harcourt Central - Station 02,Nos,280,534395.68,280,534395.68,0,0,0,0,1908.556,0,Novacare Ltd
Ura Clear,Ura Clear,Products,Central Abuja Hub - Grand DC,Nos,310,914500.00,310,914500.00,0,0,0,0,2950.000,0,Novacare Ltd
Ura Clear,Ura Clear,Products,Kano Commercial Hub - Station 03,Nos,195,575250.00,195,575250.00,0,0,0,0,2950.000,0,Novacare Ltd
Novacare Vitality Booster,Novacare Vitality Booster,Products,Central Abuja Hub - Grand DC,Nos,650,2210000.00,650,2210000.00,0,0,0,0,3400.000,0,Novacare Ltd
Novacare Vitality Booster,Novacare Vitality Booster,Products,Lagos Ikeja Main Station - DC,Nos,480,1632000.00,480,1632000.00,0,0,0,0,3400.000,0,Novacare Ltd
Eye Care Herbal Drops,Eye Care Herbal Drops,Products,Central Abuja Hub - Grand DC,Nos,210,483000.00,210,483000.00,0,0,0,0,2300.000,0,Novacare Ltd''';

  @override
  void initState() {
    super.initState();
    _csvController.addListener(_analyzeInput);
  }

  @override
  void dispose() {
    _csvController.removeListener(_analyzeInput);
    _csvController.dispose();
    super.dispose();
  }

  void _analyzeInput() {
    final text = _csvController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parsedRowCount = 0;
        _parsedTotalValuation = 0.0;
        _previewError = null;
      });
      return;
    }

    try {
      final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) {
        setState(() {
          _parsedRowCount = 0;
          _parsedTotalValuation = 0.0;
          _previewError = 'Need header + at least 1 data row';
        });
        return;
      }

      int count = 0;
      double totalVal = 0.0;
      for (int i = 1; i < lines.length; i++) {
        final cols = lines[i].split(',');
        if (cols.length >= 7) {
          count++;
          final val = double.tryParse(cols[6].trim()) ?? 0.0;
          totalVal += val;
        }
      }

      setState(() {
        _parsedRowCount = count;
        _parsedTotalValuation = totalVal;
        _previewError = null;
      });
    } catch (e) {
      setState(() {
        _previewError = 'Invalid CSV formatting: $e';
      });
    }
  }

  void _loadSampleData() {
    _csvController.text = _pangeaSampleData;
  }

  Future<void> _import() async {
    final text = _csvController.text.trim();
    if (text.isEmpty || _parsedRowCount == 0) return;

    setState(() => _isProcessing = true);
    try {
      await ref.read(clientPortalProvider.notifier).importStockBalanceCsv(text);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Imported $_parsedRowCount warehouse balance records into Pangea-compatible ledger!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Import failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 740),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.upload_file_rounded, color: Color(0xFF0D9488), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Stock Balance Report (Pangea Suite CSV)',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Import multi-warehouse balance records, valuation rates & reserved quantities',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Paste CSV Data with Pangea Suite Headers',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _loadSampleData,
                          icon: const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF0D9488)),
                          label: Text(
                            'Load Pangea Template',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _pangeaSampleHeader,
                        style: GoogleFonts.firaCode(fontSize: 10.5, color: const Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _csvController,
                      maxLines: 12,
                      style: GoogleFonts.firaCode(
                        fontSize: 12,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Paste CSV rows here...',
                        hintStyle: GoogleFonts.firaCode(fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Parser Inspection Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _previewError != null
                            ? const Color(0xFFFEF2F2)
                            : (_parsedRowCount > 0
                                ? const Color(0xFFF0FDF4)
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _previewError != null
                              ? const Color(0xFFFCA5A5)
                              : (_parsedRowCount > 0
                                  ? const Color(0xFF86EFAC)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        ),
                      ),
                      child: _previewError != null
                          ? Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _previewError!,
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB91C1C)),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text('Detected Ledger Positions', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$_parsedRowCount Warehouse Positions',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: _parsedRowCount > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(width: 1, height: 35, color: const Color(0xFFCBD5E1)),
                                Column(
                                  children: [
                                    Text('Total Inventory Valuation', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₦${_currencyFormat.format(_parsedTotalValuation)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: _parsedRowCount > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: (_isProcessing || _parsedRowCount == 0) ? null : _import,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.file_download_done_rounded, size: 18),
                    label: Text(
                      _isProcessing ? 'Importing...' : 'Confirm Ledger Import',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
