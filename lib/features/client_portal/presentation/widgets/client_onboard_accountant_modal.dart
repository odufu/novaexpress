import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_provider.dart';
import '../providers/client_portal_provider.dart';
import 'client_accountant_credentials_modal.dart';

final onboardAccountantSubmittingProvider =
    StateProvider.autoDispose<bool>((ref) => false);

class ClientOnboardAccountantModal extends ConsumerStatefulWidget {
  const ClientOnboardAccountantModal({super.key});

  @override
  ConsumerState<ClientOnboardAccountantModal> createState() =>
      _ClientOnboardAccountantModalState();
}

class _ClientOnboardAccountantModalState
    extends ConsumerState<ClientOnboardAccountantModal> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _canApproveSettlements = true;
  bool _canManageExpenses = true;
  bool _canDisbursePayouts = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _generateAccountantCode();
    _passwordController.text = 'Accountant123!';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _generateAccountantCode() {
    final client = ref.read(clientPortalProvider).clientProfile;
    final prefix = client.companyName.trim().isNotEmpty
        ? (client.companyName.trim().length >= 4
            ? client.companyName.trim().substring(0, 4).toUpperCase()
            : client.companyName.trim().toUpperCase())
        : 'NOVA';
    final existing = ref.read(clientPortalProvider).accountants;
    final nextNum = 101 + existing.length;
    _codeController.text = 'ACC-$prefix-$nextNum';
  }

  void _generatePassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#%*';
    final rand = math.Random.secure();
    final pwd = List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
    setState(() {
      _passwordController.text = 'Acc@$pwd';
      _obscurePassword = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = '$firstName $lastName'.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    final password = _passwordController.text.trim().isNotEmpty
        ? _passwordController.text.trim()
        : 'Accountant123!';

    // Duplicate checks
    final existingAccountants = ref.read(clientPortalProvider).accountants;
    if (existingAccountants.any((a) => a.email.toLowerCase() == email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Email '$email' is already registered to an accountant."),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    ref.read(onboardAccountantSubmittingProvider.notifier).state = true;

    try {
      final newAccountant =
          await ref.read(clientPortalProvider.notifier).createAccountant(
                fullName: fullName,
                email: email,
                phone: phone,
                password: password,
                accountantCode: code,
                canApproveSettlements: _canApproveSettlements,
                canManageExpenses: _canManageExpenses,
                canDisbursePayouts: _canDisbursePayouts,
              );

      if (mounted) {
        Navigator.of(context).pop();
        ClientAccountantCredentialsModal.show(
          context,
          accountant: newAccountant,
          initialPassword: password,
          clientName: ref.read(clientPortalProvider).clientProfile.companyName,
        );
      }
    } catch (e) {
      if (mounted) {
        var msg = e.toString();
        if (msg.startsWith('Exception: ')) msg = msg.substring(11);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      ref.read(onboardAccountantSubmittingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final isSubmitting = ref.watch(onboardAccountantSubmittingProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F766E).withValues(alpha: 0.18)
                        : const Color(0xFF0F766E).withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.manage_accounts_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Onboard Accountant',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Assign dedicated merchant finance staff to manage DC settlements',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),

                // Info Scope Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.phone_android_rounded,
                          size: 18,
                          color: Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Accountants log into the Merchant Settlements App (/merchant-settlements) to track live DC remittances, validate settlement requests, and sign off disbursements.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              height: 1.4,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Form Fields
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First Name & Last Name
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _firstNameController,
                                label: 'First Name',
                                hint: 'e.g. Ibrahim',
                                icon: Icons.person_rounded,
                                isDark: isDark,
                                validator: (val) => val == null || val.trim().isEmpty
                                    ? 'First name required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _lastNameController,
                                label: 'Last Name',
                                hint: 'e.g. Garba',
                                icon: Icons.person_outline_rounded,
                                isDark: isDark,
                                validator: (val) => val == null || val.trim().isEmpty
                                    ? 'Last name required'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Email & Phone
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _emailController,
                                label: 'Official Email',
                                hint: 'accountant@brand.ng',
                                icon: Icons.alternate_email_rounded,
                                isDark: isDark,
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Email required';
                                  if (!val.contains('@') || !val.contains('.')) {
                                    return 'Invalid email address';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _phoneController,
                                label: 'Phone (WhatsApp)',
                                hint: '08012345678',
                                icon: Icons.phone_rounded,
                                isDark: isDark,
                                keyboardType: TextInputType.phone,
                                validator: (val) => val == null || val.trim().isEmpty
                                    ? 'Phone required'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Accountant Code & Generate Button
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _codeController,
                                label: 'Staff Code',
                                hint: 'ACC-NOVA-101',
                                icon: Icons.badge_rounded,
                                isDark: isDark,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  tooltip: 'Generate Code',
                                  onPressed: _generateAccountantCode,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: 'Accountant123!',
                                icon: Icons.lock_outline_rounded,
                                isDark: isDark,
                                obscureText: _obscurePassword,
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        size: 18,
                                      ),
                                      tooltip: _obscurePassword ? 'Show' : 'Hide',
                                      onPressed: () =>
                                          setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.key_rounded, size: 18),
                                      tooltip: 'Randomize',
                                      onPressed: _generatePassword,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Permissions Section
                        Text(
                          'Finance Permissions',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildPermissionToggle(
                                title: 'Settlement Sign-off',
                                subtitle: 'Authorize and validate daily DC remittance requests',
                                icon: Icons.verified_rounded,
                                value: _canApproveSettlements,
                                onChanged: (v) => setState(() => _canApproveSettlements = v),
                                isDark: isDark,
                              ),
                              const Divider(height: 1),
                              _buildPermissionToggle(
                                title: 'Manage Expenses',
                                subtitle: 'Record and review operating expenses and disbursements',
                                icon: Icons.receipt_long_rounded,
                                value: _canManageExpenses,
                                onChanged: (v) => setState(() => _canManageExpenses = v),
                                isDark: isDark,
                              ),
                              const Divider(height: 1),
                              _buildPermissionToggle(
                                title: 'Disburse Payouts',
                                subtitle: 'Sign off closer and digital marketer commission payouts',
                                icon: Icons.payments_rounded,
                                value: _canDisbursePayouts,
                                onChanged: (v) => setState(() => _canDisbursePayouts = v),
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer Actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: isSubmitting ? null : _submit,
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                        label: Text(
                          isSubmitting ? 'Onboarding...' : 'Onboard',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            prefixIcon: Icon(
              icon,
              size: 16,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF0F766E),
      secondary: Icon(
        icon,
        size: 18,
        color: value
            ? const Color(0xFF0F766E)
            : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }
}

