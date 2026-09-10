import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/nigeria_locations.dart';
import '../../../client_portal/domain/entities/client_profile.dart';
import '../providers/dc_console_provider.dart';

final onboardClientSubmittingProvider = StateProvider.autoDispose<bool>((ref) => false);

class DCOnboardClientModal extends ConsumerStatefulWidget {
  const DCOnboardClientModal({super.key});

  @override
  ConsumerState<DCOnboardClientModal> createState() => _DCOnboardClientModalState();
}

class _DCOnboardClientModalState extends ConsumerState<DCOnboardClientModal> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _companyNameController = TextEditingController();
  final _clientCodeController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController(text: 'Abuja');
  final _closerLimitController = TextEditingController(text: '250');
  final _bankNameController = TextEditingController(text: 'Access Bank');
  final _bankAccountNumberController = TextEditingController();
  final _bankAccountNameController = TextEditingController();

  int _currentStep = 0; // 0: Company & Depot, 1: Login Credentials, 2: Tier & Settlement
  String _tier = 'enterprise'; // 'enterprise' or 'standard_merchant'
  String _selectedState = 'FCT - Abuja';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Live Email Validation state
  Timer? _debounceTimer;
  bool _isCheckingEmail = false;
  bool _emailExists = false;
  String? _emailCheckMessage;
  String _lastCheckedEmail = '';

  // Completed State
  ClientProfile? _createdClient;
  String? _createdPassword;

  @override
  void initState() {
    super.initState();
    _passwordController.text = 'ClientPass2026!';
    _confirmPasswordController.text = 'ClientPass2026!';
    _companyNameController.addListener(_onCompanyNameChanged);
    _emailController.addListener(_onEmailInputChanged);
  }

  void _onCompanyNameChanged() {
    final name = _companyNameController.text.trim();
    if (name.isNotEmpty && (_clientCodeController.text.isEmpty || _clientCodeController.text.startsWith('CLI-'))) {
      final words = name.split(RegExp(r'\s+'));
      String prefix = words.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
      if (prefix.length < 2) prefix = name.length >= 2 ? name.substring(0, 2).toUpperCase() : 'CL';
      final suffix = (DateTime.now().millisecond % 900 + 100).toString();
      _clientCodeController.text = 'CLI-$prefix-$suffix';
    }
  }

  void _onEmailInputChanged() {
    final email = _emailController.text.trim().toLowerCase();
    if (email == _lastCheckedEmail) return;

    _debounceTimer?.cancel();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      if (_emailCheckMessage != null || _emailExists) {
        setState(() {
          _isCheckingEmail = false;
          _emailExists = false;
          _emailCheckMessage = null;
        });
      }
      return;
    }

    setState(() {
      _isCheckingEmail = true;
      _emailCheckMessage = 'Verifying email uniqueness across platform...';
    });

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final exists = await ref.read(dcConsoleProvider.notifier).checkClientEmailExists(email);
      if (!mounted) return;
      setState(() {
        _isCheckingEmail = false;
        _lastCheckedEmail = email;
        _emailExists = exists;
        if (exists) {
          _emailCheckMessage =
              "Email already exists! Clients use this email to log in to their dedicated portal. Please prompt for a unique email address.";
        } else {
          _emailCheckMessage = "Unique email verified. Available for client authentication.";
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _companyNameController.removeListener(_onCompanyNameChanged);
    _emailController.removeListener(_onEmailInputChanged);
    _companyNameController.dispose();
    _clientCodeController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _closerLimitController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }

  void _generateRandomPassword() {
    final year = DateTime.now().year;
    final r = (DateTime.now().millisecondsSinceEpoch % 899 + 100);
    final gen = 'NovaClient$year#$r';
    setState(() {
      _passwordController.text = gen;
      _confirmPasswordController.text = gen;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    if (_emailExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text(
            '⚠️ Email "$email" already exists! Clients authenticate with this email, so please change it.',
          ),
        ),
      );
      return;
    }

    ref.read(onboardClientSubmittingProvider.notifier).state = true;

    try {
      final compName = _companyNameController.text.trim();
      final clientCode = _clientCodeController.text.trim().toUpperCase();
      final contactPerson = _contactPersonController.text.trim();
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();
      final address = _addressController.text.trim();
      final city = _cityController.text.trim();
      final closerLimit = int.tryParse(_closerLimitController.text.trim()) ?? 250;
      final bankName = _bankNameController.text.trim();
      final bankAccNum = _bankAccountNumberController.text.trim();
      final bankAccName = _bankAccountNameController.text.trim();

      final client = await ref.read(dcConsoleProvider.notifier).createClient(
        companyName: compName,
        clientCode: clientCode.isNotEmpty ? clientCode : null,
        contactPerson: contactPerson,
        email: email,
        phone: phone,
        password: password,
        address: address,
        city: city,
        stateName: _selectedState,
        tier: _tier,
        closerLimit: closerLimit,
        bankName: bankName.isNotEmpty ? bankName : null,
        bankAccountNumber: bankAccNum.isNotEmpty ? bankAccNum : null,
        bankAccountName: bankAccName.isNotEmpty ? bankAccName : null,
      );

      if (mounted) {
        setState(() {
          _createdClient = client;
          _createdPassword = password;
        });
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
        ref.read(onboardClientSubmittingProvider.notifier).state = false;
      }
    }
  }

  void _copyCredentials() {
    if (_createdClient == null) return;
    final text = '''
=================================================
NovaExpress Platform — Client Account Credentials
=================================================
Company: ${_createdClient!.companyName}
Client Code: ${_createdClient!.code}
Service Tier: ${_createdClient!.isEnterprise ? 'Enterprise Merchant (Multi-Closer)' : 'Standard Merchant'}
Admin Contact: ${_createdClient!.contactPerson}

LOGIN CREDENTIALS:
Portal URL: /login (Select "E-Commerce Merchant Admin" tab)
Login Email: ${_createdClient!.email}
Initial Password: ${_createdPassword ?? 'ClientPass2026!'}
=================================================
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Client portal credentials copied to clipboard! Ready to share with merchant.',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(onboardClientSubmittingProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: _createdClient != null
            ? _buildSuccessView(isDark)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Ribbon
                      _buildHeader(isDark),
                      const SizedBox(height: 20),

                      // Step Navigation Indicator
                      _buildStepSelector(isDark),
                      const SizedBox(height: 24),

                      // Step Content
                      if (_currentStep == 0) ...[
                        _buildStep1CompanyDetails(isDark),
                      ] else if (_currentStep == 1) ...[
                        _buildStep2Credentials(isDark),
                      ] else ...[
                        _buildStep3TierAndSettlement(isDark),
                      ],

                      const SizedBox(height: 26),

                      // Navigation Action Bar
                      _buildActionBar(isSubmitting, isDark),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ===========================================================================
  // Header Ribbon
  // ===========================================================================
  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.domain_add_rounded, color: Color(0xFF0D9488), size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Onboard Client Account',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Unique Auth',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Provision authenticatable merchant credentials & multi-closer permissions',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // ===========================================================================
  // Step Selector Indicator
  // ===========================================================================
  Widget _buildStepSelector(bool isDark) {
    final steps = [
      ('1', 'Company & Depot', Icons.business_rounded),
      ('2', 'Login & Auth', Icons.lock_person_rounded),
      ('3', 'Tier & Payouts', Icons.account_balance_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: List.generate(steps.length, (idx) {
          final isSelected = _currentStep == idx;
          final isPassed = _currentStep > idx;
          return Expanded(
            child: InkWell(
              onTap: () {
                if (idx < _currentStep || _formKey.currentState!.validate()) {
                  setState(() => _currentStep = idx);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0D9488)
                            : (isPassed ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: isPassed
                          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                          : Text(
                              steps[idx].$1,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        steps[idx].$2,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF0D9488)
                              : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // Step 1: Company & Depot Details
  // ===========================================================================
  Widget _buildStep1CompanyDetails(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Company / Brand Name', isDark, isRequired: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _companyNameController,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                    decoration: _inputDecoration(
                      hintText: 'e.g. Novacale Limited',
                      icon: Icons.store_rounded,
                      isDark: isDark,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Company name is required';
                      if (v.trim().length < 2) return 'Company name too short';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Client Code (ID)', isDark, isRequired: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _clientCodeController,
                    style: GoogleFonts.firaCode(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D9488),
                    ),
                    decoration: _inputDecoration(
                      hintText: 'CLI-NOV-01',
                      icon: Icons.tag_rounded,
                      isDark: isDark,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Code required' : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Operating State', isDark, isRequired: true),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: NigeriaLocations.states.contains(_selectedState) ? _selectedState : NigeriaLocations.states.first,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                    items: NigeriaLocations.states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedState = val);
                    },
                    decoration: _inputDecoration(hintText: 'Select State', icon: Icons.map_rounded, isDark: isDark),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('City / Primary Depot', isDark, isRequired: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _cityController,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                    decoration: _inputDecoration(
                      hintText: 'e.g. Abuja Municipal (AMAC)',
                      icon: Icons.location_city_rounded,
                      isDark: isDark,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'City required' : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildLabel('Physical Address / Pickup Warehouse', isDark, isRequired: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _addressController,
          maxLines: 2,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
          decoration: _inputDecoration(
            hintText: 'Plot 12, Commercial Avenue, Central Business District, Abuja',
            icon: Icons.pin_drop_rounded,
            isDark: isDark,
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Physical address required' : null,
        ),
      ],
    );
  }

  // ===========================================================================
  // Step 2: Login Credentials & Live Email Validation
  // ===========================================================================
  Widget _buildStep2Credentials(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Notice Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D9488).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.vpn_key_rounded, color: Color(0xFF0D9488), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'These credentials allow the merchant admin to sign in under the "E-Commerce Merchant Admin" portal tab at /login.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF0D9488), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Primary Contact Person (Admin)', isDark, isRequired: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _contactPersonController,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                    decoration: _inputDecoration(
                      hintText: 'Dr. Chuka Okafor',
                      icon: Icons.person_rounded,
                      isDark: isDark,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Contact person required' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Business Phone Number', isDark, isRequired: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                    decoration: _inputDecoration(
                      hintText: '08034455667',
                      icon: Icons.phone_rounded,
                      isDark: isDark,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Phone required';
                      if (v.trim().length < 10) return 'Invalid phone number';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Live Validated Business Email Field
        _buildLabel('Unique Portal Login Email', isDark, isRequired: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'client.novacale@novaexpress.ng',
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18, color: Color(0xFF94A3B8)),
            suffixIcon: _isCheckingEmail
                ? Container(
                    padding: const EdgeInsets.all(12),
                    width: 20,
                    height: 20,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
                  )
                : (_emailController.text.isNotEmpty && _lastCheckedEmail == _emailController.text.trim().toLowerCase()
                    ? Icon(
                        _emailExists ? Icons.error_rounded : Icons.check_circle_rounded,
                        color: _emailExists ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      )
                    : null),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _emailExists ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _emailExists ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _emailExists ? const Color(0xFFEF4444) : const Color(0xFF0D9488),
                width: 1.5,
              ),
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Email is required';
            if (!v.contains('@') || !v.contains('.')) return 'Valid email required';
            if (_emailExists) return 'Email already registered. Please enter a different email.';
            return null;
          },
        ),

        // Automatic Prompt when Email Already Exists
        if (_emailExists) ...[
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email Already Registered — Please Change Email',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'An account with "$_lastCheckedEmail" already exists on NovaExpress. Because clients authenticate using their unique email address, this client cannot reuse an existing login identifier.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFFB91C1C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          _emailController.clear();
                          _onEmailInputChanged();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Prompt to Change / Clear Email',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else if (!_isCheckingEmail && _emailCheckMessage != null && !_emailExists && _emailController.text.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Unique login email verified. Ready for merchant portal access.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Password & Confirm Password Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel('Initial Password', isDark, isRequired: true),
                      InkWell(
                        onTap: _generateRandomPassword,
                        child: Text(
                          '⚡ Auto-Generate',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                    decoration: _inputDecoration(
                      hintText: 'Min 6 chars',
                      icon: Icons.lock_rounded,
                      isDark: isDark,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password required';
                      if (v.length < 6) return 'At least 6 characters required';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Confirm Password', isDark, isRequired: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                    decoration: _inputDecoration(
                      hintText: 'Re-enter password',
                      icon: Icons.check_rounded,
                      isDark: isDark,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (v) {
                      if (v != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // Step 3: Tier & Financial Details
  // ===========================================================================
  Widget _buildStep3TierAndSettlement(bool isDark) {
    final isEnterprise = _tier == 'enterprise';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Client Service Tier', isDark),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tier = 'enterprise'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isEnterprise
                        ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isEnterprise ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: isEnterprise ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.workspace_premium_rounded, color: isEnterprise ? const Color(0xFF6366F1) : const Color(0xFF64748B), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Enterprise Client',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isEnterprise ? const Color(0xFF4338CA) : (isDark ? Colors.white : const Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Telesales closers team, leads dialer & live performance',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tier = 'standard_merchant'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: !isEnterprise
                        ? const Color(0xFF0D9488).withValues(alpha: 0.08)
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !isEnterprise ? const Color(0xFF0D9488) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: !isEnterprise ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storefront_rounded, color: !isEnterprise ? const Color(0xFF0D9488) : const Color(0xFF64748B), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Standard Merchant',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: !isEnterprise ? const Color(0xFF0D9488) : (isDark ? Colors.white : const Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Direct order intake and inventory depot fulfillment',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (isEnterprise) ...[
          _buildLabel('Closer Seat Limit (Telesales Agents)', isDark),
          const SizedBox(height: 6),
          TextFormField(
            controller: _closerLimitController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
            decoration: _inputDecoration(
              hintText: '250',
              icon: Icons.people_alt_rounded,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Settlement Bank Details
        _buildLabel('Settlement Bank (For COD Remittances & Payouts)', isDark),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _bankNameController,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                decoration: _inputDecoration(
                  hintText: 'e.g. Access Bank',
                  icon: Icons.account_balance_rounded,
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _bankAccountNumberController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                decoration: _inputDecoration(
                  hintText: '10-digit NUBAN',
                  icon: Icons.numbers_rounded,
                  isDark: isDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _bankAccountNameController,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
          decoration: _inputDecoration(
            hintText: 'Beneficiary Account Name (e.g. Novacale Limited)',
            icon: Icons.badge_rounded,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Action Navigation Bar
  // ===========================================================================
  Widget _buildActionBar(bool isSubmitting, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          OutlinedButton.icon(
            onPressed: isSubmitting ? null : () => setState(() => _currentStep--),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Previous Step'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          )
        else
          const SizedBox.shrink(),
        Row(
          children: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(width: 10),
            if (_currentStep < 2)
              ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _currentStep++);
                  }
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                label: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: (isSubmitting || _emailExists) ? null : _submit,
                icon: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                label: Text(
                  isSubmitting ? 'Provisioning Account...' : 'Complete & Provision Client',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // Success Confirmation & Credentials Summary View
  // ===========================================================================
  Widget _buildSuccessView(bool isDark) {
    final client = _createdClient!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 44),
          ),
          const SizedBox(height: 16),
          Text(
            'Client Account Provisioned!',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${client.companyName} (${client.code}) is now authenticated on NovaExpress',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Credentials Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: Column(
              children: [
                _buildCredentialRow('Client Portal Role', 'E-Commerce Merchant Admin', Icons.badge_rounded, isDark),
                const Divider(height: 16),
                _buildCredentialRow('Client Code', client.code, Icons.tag_rounded, isDark),
                const Divider(height: 16),
                _buildCredentialRow('Login Email', client.email, Icons.email_rounded, isDark),
                const Divider(height: 16),
                _buildCredentialRow('Initial Password', _createdPassword ?? 'ClientPass2026!', Icons.lock_rounded, isDark),
                const Divider(height: 16),
                _buildCredentialRow(
                  'Service Tier',
                  client.isEnterprise ? 'Enterprise (${client.closerLimit} Closers Max)' : 'Standard Merchant',
                  Icons.workspace_premium_rounded,
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyCredentials,
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF0D9488)),
                  label: const Text('Copy Credentials', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0D9488)),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, bool isDark, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    required bool isDark,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
      ),
    );
  }
}
