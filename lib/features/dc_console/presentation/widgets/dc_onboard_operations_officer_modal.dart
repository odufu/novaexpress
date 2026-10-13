import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/dc_operations_officer.dart';
import '../../domain/entities/distribution_center.dart';
import '../providers/dc_console_provider.dart';

class DCOnboardOperationsOfficerModal extends ConsumerStatefulWidget {
  final DistributionCenter? preselectedDc;

  const DCOnboardOperationsOfficerModal({
    super.key,
    this.preselectedDc,
  });

  @override
  ConsumerState<DCOnboardOperationsOfficerModal> createState() =>
      _DCOnboardOperationsOfficerModalState();
}

class _DCOnboardOperationsOfficerModalState
    extends ConsumerState<DCOnboardOperationsOfficerModal> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _staffCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _assignedZoneController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _selectedDcId;
  DCOperationsOfficer? _createdOfficer;

  @override
  void initState() {
    super.initState();
    final dcState = ref.read(dcConsoleProvider);
    _selectedDcId = widget.preselectedDc?.id ?? dcState.activeHubId;

    // Generate strong default password
    _generatePassword();

    // Auto-generate staff code based on active hub code
    _generateStaffCode(dcState.activeHubCode);
  }

  void _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%*';
    final rand = math.Random();
    final pass = List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
    _passwordController.text = pass;
    setState(() {});
  }

  void _generateStaffCode([String? hubCode]) {
    final prefix = (hubCode != null && hubCode.isNotEmpty)
        ? hubCode.replaceAll('DC-', 'OPS-')
        : 'OPS';
    final rand = 100 + math.Random().nextInt(899);
    _staffCodeController.text = '$prefix-$rand';
    setState(() {});
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _staffCodeController.dispose();
    _passwordController.dispose();
    _assignedZoneController.dispose();
    super.dispose();
  }

  DistributionCenter? _getSelectedDc() {
    final dcState = ref.read(dcConsoleProvider);
    final targetId = _selectedDcId ?? dcState.activeHubId;
    return dcState.distributionCenters.where((d) => d.id == targetId).firstOrNull ??
        dcState.distributionCenters.where((d) => d.isGrandDc).firstOrNull ??
        dcState.distributionCenters.firstOrNull;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final fullName = '$firstName $lastName'.trim();
      final email = _emailController.text.trim().toLowerCase();
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();
      final staffCode = _staffCodeController.text.trim().toUpperCase();
      final selectedDc = _getSelectedDc();
      final dcId = selectedDc?.id ?? ref.read(dcConsoleProvider).activeHubId;
      final assignedZone = _assignedZoneController.text.trim().isNotEmpty
          ? _assignedZoneController.text.trim()
          : (selectedDc?.name ?? 'Main Terminal');

      final officer = await ref.read(dcConsoleProvider.notifier).addOperationsOfficer(
            name: fullName,
            email: email,
            phone: phone,
            password: password,
            staffCode: staffCode,
            distributionCenterId: dcId,
            assignedZone: assignedZone,
          );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _createdOfficer = officer;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        var msg = e.toString();
        if (msg.startsWith('Exception: ')) msg = msg.substring(11);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $msg'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sendViaWhatsApp(DCOperationsOfficer officer) async {
    final cleanPhone = officer.phone.replaceAll(RegExp(r'[^0-9]'), '');
    String intlPhone = cleanPhone;
    if (intlPhone.startsWith('0')) {
      intlPhone = '234${intlPhone.substring(1)}';
    } else if (!intlPhone.startsWith('234')) {
      intlPhone = '234$intlPhone';
    }

    final targetDc = _getSelectedDc();
    final message = '''*NovaXpress DC Operations Portal - Login Credentials*
----------------------------------------
Hello ${officer.name},
You have been onboarded as a *Distribution Center Operations Officer* at *${targetDc?.name ?? 'NovaXpress DC'}*.

*Your Login Details:*
📱 *Mobile Portal:* Access from your smartphone browser or mobile app
👤 *Staff Code:* ${officer.staffCode}
📧 *Email:* ${officer.email}
🔑 *Password:* ${officer.rawPassword ?? 'Provided by your DC Supervisor'}
🏢 *Assigned DC:* ${targetDc?.name ?? 'Terminal Hub'}

*Access Scope:*
• Live incoming DC order monitoring
• Direct rider order dispatching
• DC-to-DC order rerouting

_Please login immediately and change your password upon first entry._
----------------------------------------
*NovaXpress Logistics Hub*''';

    final uri = Uri.parse(
        'https://wa.me/$intlPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _copyCredentials(DCOperationsOfficer officer) {
    final targetDc = _getSelectedDc();
    final text = '''NovaXpress DC Operations Officer Credentials
----------------------------------------
Officer Name: ${officer.name}
Staff Code: ${officer.staffCode}
Email: ${officer.email}
Password: ${officer.rawPassword ?? ''}
Assigned DC: ${targetDc?.name ?? 'Assigned Station'}
Portal Route: /ops (Strictly Mobile)
Scope: Incoming Order Routing & Dispatch Only
----------------------------------------''';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Credentials copied to clipboard!'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dcState = ref.watch(dcConsoleProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (_createdOfficer != null) {
      return _buildCredentialsSuccessSlip(isDark, _createdOfficer!);
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 680,
        constraints: const BoxConstraints(maxWidth: 680),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Color(0xFF0D9488),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Onboard Operations Officer',
                          style: GoogleFonts.inter(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF031632),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assign dedicated mobile dispatch staff for this DC to manage and reroute incoming orders.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Strictly Mobile Policy Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android_rounded, color: Color(0xFF3B82F6), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Operations Portal is strictly mobile (/ops). Officers only view and route orders assigned to this Distribution Center.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Fields
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _firstNameController,
                            label: 'First Name',
                            hint: 'e.g. Ibrahim',
                            icon: Icons.person_outline_rounded,
                            isDark: isDark,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildTextField(
                            controller: _lastNameController,
                            label: 'Last Name',
                            hint: 'e.g. Garba',
                            icon: Icons.person_outline_rounded,
                            isDark: isDark,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                            hint: 'ops.officer@novaxpress.ng',
                            icon: Icons.alternate_email_rounded,
                            isDark: isDark,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email is required';
                              if (!v.contains('@') || !v.contains('.')) return 'Invalid email';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildTextField(
                            controller: _phoneController,
                            label: 'Phone (WhatsApp)',
                            hint: '08012345678',
                            icon: Icons.phone_outlined,
                            isDark: isDark,
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Phone required';
                              if (v.trim().length < 10) return 'Invalid phone number';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Staff Code & Distribution Center
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _staffCodeController,
                            label: 'Staff Code',
                            hint: 'OPS-WUSE-01',
                            icon: Icons.badge_outlined,
                            isDark: isDark,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              tooltip: 'Regenerate Code',
                              onPressed: () {
                                final selectedDc = _getSelectedDc();
                                _generateStaffCode(selectedDc?.code);
                              },
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Staff code required' : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Distribution Center',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedDcId,
                                    isExpanded: true,
                                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    items: dcState.distributionCenters.map((dc) {
                                      return DropdownMenuItem<String>(
                                        value: dc.id,
                                        child: Row(
                                          children: [
                                            Icon(
                                              dc.isGrand ? Icons.domain_rounded : Icons.warehouse_rounded,
                                              size: 16,
                                              color: dc.isGrand ? const Color(0xFFF37021) : const Color(0xFF0D9488),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${dc.name} (${dc.code})',
                                                style: GoogleFonts.inter(fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedDcId = val;
                                          final dc = dcState.distributionCenters.where((d) => d.id == val).firstOrNull;
                                          if (dc != null) {
                                            _generateStaffCode(dc.code);
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Password Field
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Temporary Login Password',
                      hint: 'Enter strong password',
                      icon: Icons.lock_outline_rounded,
                      isDark: isDark,
                      obscureText: _obscurePassword,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          IconButton(
                            icon: const Icon(Icons.vpn_key_rounded, size: 18),
                            tooltip: 'Generate Strong Password',
                            onPressed: _generatePassword,
                          ),
                        ],
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Submit & Cancel Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitForm,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                          label: Text(
                            _isSubmitting ? 'Onboarding...' : 'Onboard Operations Officer',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF0D9488)),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialsSuccessSlip(bool isDark, DCOperationsOfficer officer) {
    final targetDc = _getSelectedDc();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Success
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operations Officer Onboarded!',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF031632),
                          ),
                        ),
                        Text(
                          'Credentials successfully issued for ${officer.name}',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // Slip Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSlipRow('Officer Name:', officer.name, isBold: true),
                    _buildSlipRow('Staff / Officer Code:', officer.staffCode, isCode: true),
                    _buildSlipRow('Distribution Center:', targetDc?.name ?? 'Assigned Station'),
                    _buildSlipRow('Operational Scope:', 'Live Orders & Rider Routing (Strictly Mobile)'),
                    const Divider(height: 20),
                    _buildSlipRow('Mobile Login Email:', officer.email, isCode: true),
                    _buildSlipRow('Temporary Password:', officer.rawPassword ?? '********', isCode: true, isHighlight: true),
                    _buildSlipRow('Direct Route:', '/ops', isCode: true),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons: Copy, WhatsApp, Close
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _copyCredentials(officer),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Login Details'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _sendViaWhatsApp(officer),
                    icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Send via WhatsApp',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    label: const Text('Done', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF031632),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlipRow(
    String label,
    String val, {
    bool isBold = false,
    bool isCode = false,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              val,
              style: isCode
                  ? GoogleFonts.firaCode(
                      fontSize: 13,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                      color: isHighlight
                          ? const Color(0xFFF37021)
                          : const Color(0xFF0D9488),
                    )
                  : GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                      color: isHighlight ? const Color(0xFFF37021) : null,
                    ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
