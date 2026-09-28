import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/client_portal_provider.dart';

final onboardMarketerSubmittingProvider = StateProvider.autoDispose<bool>((ref) => false);

class ClientOnboardMarketerModal extends ConsumerStatefulWidget {
  const ClientOnboardMarketerModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ClientOnboardMarketerModal(),
    );
  }

  @override
  ConsumerState<ClientOnboardMarketerModal> createState() => _ClientOnboardMarketerModalState();
}

class _ClientOnboardMarketerModalState extends ConsumerState<ClientOnboardMarketerModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _budgetController = TextEditingController(text: '50000');
  final _commissionController = TextEditingController(text: '500');
  final _passwordController = TextEditingController(text: 'Marketer123!');
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSupervisor = false;
  String? _selectedSupervisorId;
  String _commissionModel = 'per_form_submission'; // 'per_form_submission' | 'per_delivered_order'

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _budgetController.dispose();
    _commissionController.dispose();
    _passwordController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final budget = double.tryParse(_budgetController.text.trim()) ?? 50000.0;
    final commission = double.tryParse(_commissionController.text.trim()) ?? 0.0;
    final password = _passwordController.text.trim().isNotEmpty ? _passwordController.text.trim() : 'Marketer123!';
    final bankName = _bankNameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final accountName = _accountNameController.text.trim();

    ref.read(onboardMarketerSubmittingProvider.notifier).state = true;

    try {
      final marketer = await ref.read(clientPortalProvider.notifier).createMarketer(
        fullName: name,
        email: email,
        phone: phone,
        password: password,
        dailyAdSpendBudget: budget,
        commissionRate: commission,
        isCommissionEnabled: commission > 0,
        isSupervisor: _isSupervisor,
        supervisorId: _isSupervisor ? null : _selectedSupervisorId,
        commissionModel: _commissionModel,
        commissionPerFormSubmission: _commissionModel == 'per_form_submission' ? commission : 0.0,
        commissionPerDeliveredOrder: _commissionModel == 'per_delivered_order' ? commission : 0.0,
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_isSupervisor ? "Supervisor" : "Digital"} Marketer "${marketer.fullName}" onboarded successfully! Code: ${marketer.marketerCode}',
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
        var reason = e.toString();
        if (reason.startsWith('Exception: ')) {
          reason = reason.substring(11);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('⚠️ $reason'),
          ),
        );
      }
    } finally {
      if (mounted) {
        ref.read(onboardMarketerSubmittingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(onboardMarketerSubmittingProvider);
    final clientState = ref.watch(clientPortalProvider);
    final marketersCount = clientState.marketers.length;
    final isCompact = MediaQuery.of(context).size.width < 500;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 18 : 28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.campaign_rounded, color: Color(0xFF10B981), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Onboard Digital Marketer',
                                  style: GoogleFonts.inter(
                                    fontSize: isCompact ? 16 : 18,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$marketersCount Marketer${marketersCount == 1 ? "" : "s"} Active in Team',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                // Account Role
                Text('Account Role & Hierarchy', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _isSupervisor = false;
                        }),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isSupervisor ? const Color(0xFF10B981).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: !_isSupervisor ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: !_isSupervisor ? 1.5 : 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_rounded, size: 18, color: !_isSupervisor ? const Color(0xFF10B981) : const Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Standard Marketer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                    Text('Sees only own ad orders', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _isSupervisor = true;
                          _selectedSupervisorId = null;
                        }),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _isSupervisor ? const Color(0xFF6366F1).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _isSupervisor ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0), width: _isSupervisor ? 1.5 : 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.shield_rounded, size: 18, color: _isSupervisor ? const Color(0xFF6366F1) : const Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Supervisor Marketer', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                    Text('Can view supervisees', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_isSupervisor) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final supervisorMarketers = clientState.marketers.where((m) => m.isSupervisor).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reporting Supervisor (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedSupervisorId,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                                hint: Text(
                                  supervisorMarketers.isEmpty ? 'No Supervisors Available (Reports to Merchant)' : 'Select Supervising Marketer (Optional)',
                                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Direct Merchant / No Supervisor', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A))),
                                  ),
                                  ...supervisorMarketers.map((s) => DropdownMenuItem<String?>(
                                        value: s.id,
                                        child: Text('${s.fullName} (${s.marketerCode})', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                                      )),
                                ],
                                onChanged: supervisorMarketers.isEmpty
                                    ? null
                                    : (val) {
                                        setState(() {
                                          _selectedSupervisorId = val;
                                        });
                                      },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // Full Name
                Text('Full Name', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Tunde Adeyemi',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter marketer name' : null,
                ),
                const SizedBox(height: 16),

                // Email & Phone
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isRow = constraints.maxWidth >= 450;
                    final emailField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Login Email', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'marketer@company.com',
                            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                        ),
                      ],
                    );

                    final phoneField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Phone Number', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: '08012345678',
                            prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          validator: (v) => (v == null || v.trim().length < 10) ? 'Valid phone required' : null,
                        ),
                      ],
                    );

                    return isRow
                        ? Row(
                            children: [
                              Expanded(child: emailField),
                              const SizedBox(width: 14),
                              Expanded(child: phoneField),
                            ],
                          )
                        : Column(
                            children: [
                              emailField,
                              const SizedBox(height: 14),
                              phoneField,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 16),

                // Commission Model & Rate
                Text('Commission Model per Form/Order', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _commissionModel = 'per_form_submission';
                          if (_commissionController.text == '1000' || _commissionController.text.isEmpty) {
                            _commissionController.text = '500';
                          }
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _commissionModel == 'per_form_submission' ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _commissionModel == 'per_form_submission' ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                              width: _commissionModel == 'per_form_submission' ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.dynamic_form_rounded, size: 16, color: _commissionModel == 'per_form_submission' ? const Color(0xFF10B981) : const Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Pay-per-Form (Ads)',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('Earn per ad lead submitted', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _commissionModel = 'per_delivered_order';
                          if (_commissionController.text == '500' || _commissionController.text.isEmpty) {
                            _commissionController.text = '1000';
                          }
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _commissionModel == 'per_delivered_order' ? const Color(0xFF0284C7).withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _commissionModel == 'per_delivered_order' ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                              width: _commissionModel == 'per_delivered_order' ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.local_shipping_rounded, size: 16, color: _commissionModel == 'per_delivered_order' ? const Color(0xFF0284C7) : const Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Pay-per-Delivery',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('Earn per delivered order', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Daily Ad Budget & Commission Amount
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isRow = constraints.maxWidth >= 450;
                    final budgetField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Ad Budget (₦)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _budgetController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '50,000',
                            prefixIcon: const Icon(Icons.payments_outlined, size: 20, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ],
                    );

                    final commissionField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _commissionModel == 'per_form_submission'
                              ? 'Commission / Form Submission (₦)'
                              : 'Commission / Delivered Order (₦)',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _commissionController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: _commissionModel == 'per_form_submission' ? '500' : '1,000',
                            prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ],
                    );

                    return isRow
                        ? Row(
                            children: [
                              Expanded(child: budgetField),
                              const SizedBox(width: 14),
                              Expanded(child: commissionField),
                            ],
                          )
                        : Column(
                            children: [
                              budgetField,
                              const SizedBox(height: 14),
                              commissionField,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 16),

                // Bank Details (Optional)
                Text('Marketer Payout Account (Optional)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _bankNameController,
                        decoration: const InputDecoration(
                          hintText: 'Bank Name (e.g. OPay, Kuda, Zenith)',
                          prefixIcon: Icon(Icons.account_balance_rounded, size: 18, color: Color(0xFF94A3B8)),
                          isDense: true,
                          border: InputBorder.none,
                        ),
                      ),
                      const Divider(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _accountNumberController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Account Number',
                                prefixIcon: Icon(Icons.tag_rounded, size: 18, color: Color(0xFF94A3B8)),
                                isDense: true,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _accountNameController,
                              decoration: const InputDecoration(
                                hintText: 'Account Name',
                                prefixIcon: Icon(Icons.badge_rounded, size: 18, color: Color(0xFF94A3B8)),
                                isDense: true,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Initial Password
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Initial Login Password', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _passwordController.text = 'Marketer${DateTime.now().millisecond}!2026';
                            });
                          },
                          icon: const Icon(Icons.shuffle_rounded, size: 14, color: Color(0xFF10B981)),
                          label: Text('Generate', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Marketer123!',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: const Color(0xFF94A3B8)),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      validator: (v) => (v == null || v.trim().length < 6) ? 'Password must be at least 6 characters' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Provision Marketer Account',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
