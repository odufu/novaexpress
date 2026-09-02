import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/client_portal_provider.dart';

final onboardCloserSubmittingProvider = StateProvider.autoDispose<bool>((ref) => false);

class ClientOnboardCloserModal extends ConsumerStatefulWidget {
  const ClientOnboardCloserModal({super.key});

  @override
  ConsumerState<ClientOnboardCloserModal> createState() => _ClientOnboardCloserModalState();
}

class _ClientOnboardCloserModalState extends ConsumerState<ClientOnboardCloserModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _targetController = TextEditingController(text: '50');
  final _commissionController = TextEditingController(text: '500');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _targetController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(onboardCloserSubmittingProvider.notifier).state = true;

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final target = int.tryParse(_targetController.text.trim()) ?? 50;
      final commission = double.tryParse(_commissionController.text.trim()) ?? 500.0;

      final closer = await ref.read(clientPortalProvider.notifier).createCloser(
        fullName: name,
        email: email,
        phone: phone,
        dailyCallTarget: target,
        commissionRate: commission,
      );

      if (mounted) {
        Navigator.of(context).pop();
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
                    'Closer ${closer.fullName} (${closer.closerCode}) onboarded successfully!',
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
            content: Text('Error onboarding closer: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        ref.read(onboardCloserSubmittingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(onboardCloserSubmittingProvider);
    final clientState = ref.watch(clientPortalProvider);
    final currentCount = clientState.closers.length;
    final maxLimit = clientState.clientProfile.closerLimit;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF6366F1), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Onboard Telesales Closer',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Capacity: $currentCount / $maxLimit Active Closers',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Closer Name
                Text('Full Name', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Chinelo Nwachukwu',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter closer name' : null,
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
                            hintText: 'chinelo@novacale.ng',
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

                // Daily Calls Target & Commission
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isRow = constraints.maxWidth >= 450;
                    final targetField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Calls Target', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _targetController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '50 calls/day',
                            prefixIcon: const Icon(Icons.phone_in_talk_rounded, size: 20, color: Color(0xFF94A3B8)),
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
                        Text('Commission per Delivered Order (₦)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _commissionController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '500',
                            prefixIcon: const Icon(Icons.payments_outlined, size: 20, color: Color(0xFF94A3B8)),
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
                              Expanded(child: targetField),
                              const SizedBox(width: 14),
                              Expanded(child: commissionField),
                            ],
                          )
                        : Column(
                            children: [
                              targetField,
                              const SizedBox(height: 14),
                              commissionField,
                            ],
                          );
                  },
                ),
                const SizedBox(height: 24),

                // Submit Action
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
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
                                'Provision Closer Account',
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
