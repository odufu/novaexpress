import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/helpers/formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/nova_critical_action_confirmation_modal.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/admin_models.dart';
import '../providers/admin_console_provider.dart';

class AdminOnboardProductModal extends ConsumerStatefulWidget {
  const AdminOnboardProductModal({super.key});

  @override
  ConsumerState<AdminOnboardProductModal> createState() => _AdminOnboardProductModalState();
}

class _AdminOnboardProductModalState extends ConsumerState<AdminOnboardProductModal> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController(text: 'SKU-PRD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  final _priceCtrl = TextEditingController(text: '25000');
  final _abujaShelfCtrl = TextEditingController(text: '500');
  final _lagosShelfCtrl = TextEditingController(text: '750');
  final _kanoShelfCtrl = TextEditingController(text: '100');
  final _phcShelfCtrl = TextEditingController(text: '100');
  final _nxLogisticsCtrl = TextEditingController(text: '50');
  final _gigCtrl = TextEditingController(text: '30');

  String? _selectedMerchantId;

  @override
  void initState() {
    super.initState();
    final merchants = ref.read(adminConsoleProvider).merchants;
    if (merchants.isNotEmpty) {
      _selectedMerchantId = merchants.first.id;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _abujaShelfCtrl.dispose();
    _lagosShelfCtrl.dispose();
    _kanoShelfCtrl.dispose();
    _phcShelfCtrl.dispose();
    _nxLogisticsCtrl.dispose();
    _gigCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminConsoleProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedMerchant = state.merchants.firstWhere(
      (m) => m.id == _selectedMerchantId,
      orElse: () => state.merchants.isNotEmpty
          ? state.merchants.first
          : const AdminMerchant(id: 'CLI-001', businessName: 'Novacare', contactName: '', phone: '', email: ''),
    );

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_box_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Onboard New Product SKU', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Link to Merchant Partner & Seed Multi-Hub Warehouses and Agent Custody', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. Product Identity & Pricing', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDeco('Product Commercial Name * (e.g. URA Clear Probiotic Complex)', isDark),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Product name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _skuCtrl,
                              decoration: _inputDeco('System SKU Code *', isDark),
                              style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                              validator: (v) => v == null || v.trim().isEmpty ? 'SKU is required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedMerchantId,
                              decoration: _inputDeco('Merchant / Partner *', isDark),
                              items: state.merchants.map((m) {
                                return DropdownMenuItem(
                                  value: m.id,
                                  child: Text('${m.businessName} (${m.tier})', style: GoogleFonts.inter(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedMerchantId = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _priceCtrl,
                        decoration: _inputDeco('Retail Selling Price (₦ Naira) *', isDark),
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid price' : null,
                      ),
                      const SizedBox(height: 20),

                      // Section 2: Distribution Center Shelves
                      Text('2. Initial Distribution Center Shelves', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _abujaShelfCtrl,
                              decoration: _inputDeco('Abuja Central DC (Units)', isDark),
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lagosShelfCtrl,
                              decoration: _inputDeco('Lagos Grand Hub (Units)', isDark),
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _kanoShelfCtrl,
                              decoration: _inputDeco('Kano Station DC (Units)', isDark),
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _phcShelfCtrl,
                              decoration: _inputDeco('Port Harcourt DC (Units)', isDark),
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Section 3: Initial Agent Fleet Custody
                      Text('3. Initial Agent Fleet Custody ("What They Are With")', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nxLogisticsCtrl,
                              decoration: _inputDeco('NovaXpress Logistics (Fleet Units)', isDark),
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _gigCtrl,
                              decoration: _inputDeco('GIG Logistics (3PL Units)', isDark),
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Onboard & Activate SKU', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        if (_formKey.currentState?.validate() != true) return;

                        final abuja = int.tryParse(_abujaShelfCtrl.text) ?? 0;
                        final lagos = int.tryParse(_lagosShelfCtrl.text) ?? 0;
                        final kano = int.tryParse(_kanoShelfCtrl.text) ?? 0;
                        final phc = int.tryParse(_phcShelfCtrl.text) ?? 0;
                        final nx = int.tryParse(_nxLogisticsCtrl.text) ?? 0;
                        final gig = int.tryParse(_gigCtrl.text) ?? 0;
                        final price = double.tryParse(_priceCtrl.text) ?? 25000.0;
                        final totalAdded = abuja + lagos + kano + phc + nx + gig;
                        final currentUser = ref.read(authProvider).user;

                        final confirmed = await NovaCriticalActionConfirmationModal.show(
                          context: context,
                          actionName: 'Onboard Product SKU & Initial Stock Intake',
                          operatorAccount: currentUser?.email ?? 'operations@novaxpress.ng',
                          valuesets: {
                            'Product Name': _nameCtrl.text.trim(),
                            'Product SKU': _skuCtrl.text.trim(),
                            'Merchant Partner': selectedMerchant.businessName,
                            'Unit Retail Price': CurrencyFormatter.formatNaira(price),
                            'Abuja Central DC Shelf': '$abuja units',
                            'Lagos Central DC Shelf': '$lagos units',
                            'NovaXpress Logistics Custody': '$nx units',
                            'Total Network Stock Added': '$totalAdded units',
                          },
                        );
                        if (!confirmed || !mounted) return;

                        await ref.read(adminConsoleProvider.notifier).onboardProduct(
                          name: _nameCtrl.text.trim(),
                          sku: _skuCtrl.text.trim(),
                          merchantId: selectedMerchant.id,
                          merchantName: selectedMerchant.businessName,
                          unitPrice: price,
                          abujaShelfQty: abuja,
                          lagosShelfQty: lagos,
                          kanoShelfQty: kano,
                          phcShelfQty: phc,
                          initialAgentCustody: {
                            'NovaXpress Logistics (Internal Fleet)': nx,
                            'GIG Logistics Partner': gig,
                            'Speedaf Express Logistics': 0,
                          },
                        );

                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Successfully onboarded product ${_nameCtrl.text.trim()} (${_skuCtrl.text.trim()}).'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
    );
  }
}
