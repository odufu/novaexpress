import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../domain/entities/client_accountant.dart';

class ClientAccountantCredentialsModal extends ConsumerStatefulWidget {
  final ClientAccountant accountant;
  final String? initialPassword;
  final String? clientName;

  const ClientAccountantCredentialsModal({
    super.key,
    required this.accountant,
    this.initialPassword,
    this.clientName,
  });

  static Future<void> show(
    BuildContext context, {
    required ClientAccountant accountant,
    String? initialPassword,
    String? clientName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ClientAccountantCredentialsModal(
        accountant: accountant,
        initialPassword: initialPassword,
        clientName: clientName,
      ),
    );
  }

  @override
  ConsumerState<ClientAccountantCredentialsModal> createState() =>
      _ClientAccountantCredentialsModalState();
}

class _ClientAccountantCredentialsModalState
    extends ConsumerState<ClientAccountantCredentialsModal> {
  late TextEditingController _passwordController;
  bool _obscurePassword = false;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController(
      text: widget.initialPassword ?? 'Accountant123!',
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('0') && digits.length >= 10) {
      return '234${digits.substring(1)}';
    }
    if (digits.startsWith('234')) {
      return digits;
    }
    return digits.isNotEmpty ? '234$digits' : '2348000000000';
  }

  String _buildInviteMessage(String companyName) {
    final password = _passwordController.text.trim();
    return '''🎉 *Welcome to the $companyName Finance & Accounting Team!*

Hello ${widget.accountant.fullName}, your Merchant Accountant account has been created on NoveXPS.

Here are your official login credentials:
🌐 *Settlements App URL:* https://novexps.web.app/#/merchant-settlements
👤 *Name:* ${widget.accountant.fullName}
🆔 *Accountant Code:* ${widget.accountant.accountantCode}
📧 *Login Email:* ${widget.accountant.email}
🔒 *Password:* $password

📲 Log in to the Merchant Settlements App to review live rider remittances across Distribution Centers, validate daily settlement requests, manage operational expenses, and sign off payouts.

Best regards,
$companyName Finance Team''';
  }

  Future<void> _sendViaWhatsApp(String companyName) async {
    final phone = _formatPhoneNumber(widget.accountant.phone);
    final message = _buildInviteMessage(companyName);
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$phone?text=$encoded');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: message));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp link could not open. Invite copied to clipboard!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite copied to clipboard!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  void _copyAllCredentials(String companyName) async {
    final message = _buildInviteMessage(companyName);
    await Clipboard.setData(ClipboardData(text: message));
    setState(() => _isCopied = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accountant credentials copied to clipboard!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final companyName = widget.clientName ?? 'Merchant';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F766E).withValues(alpha: 0.2)
                      : const Color(0xFF0F766E).withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Accountant Ready',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Active',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Account onboarded and provisioned for settlements',
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

              // Content Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Accountant Profile Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            label: 'Name',
                            value: widget.accountant.fullName,
                            icon: Icons.person_rounded,
                            isDark: isDark,
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            label: 'Code',
                            value: widget.accountant.accountantCode,
                            icon: Icons.badge_rounded,
                            isDark: isDark,
                            isBold: true,
                            customColor: const Color(0xFF0F766E),
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            label: 'Email',
                            value: widget.accountant.email,
                            icon: Icons.alternate_email_rounded,
                            isDark: isDark,
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            label: 'Phone',
                            value: widget.accountant.phone,
                            icon: Icons.phone_rounded,
                            isDark: isDark,
                          ),
                          const Divider(height: 16),
                          _buildDetailRow(
                            label: 'App',
                            value: 'Merchant Settlements App (/merchant-settlements)',
                            icon: Icons.phone_android_rounded,
                            isDark: isDark,
                            customColor: const Color(0xFF3B82F6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Login Password',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                child: Text(
                                  _obscurePassword ? 'Show' : 'Hide',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F766E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _obscurePassword
                                      ? '••••••••••••'
                                      : _passwordController.text,
                                  style: GoogleFonts.firaCode(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                tooltip: 'Copy Password',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _passwordController.text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Password copied!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Permissions Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (widget.accountant.canApproveSettlements)
                          _buildPermissionChip('Settlement Sign-off', Icons.verified_rounded),
                        if (widget.accountant.canManageExpenses)
                          _buildPermissionChip('Manage Expenses', Icons.receipt_long_rounded),
                        if (widget.accountant.canDisbursePayouts)
                          _buildPermissionChip('Disburse Payouts', Icons.payments_rounded),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Copy All
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyAllCredentials(companyName),
                        icon: Icon(
                          _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 16,
                          color: _isCopied ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        label: Text(
                          _isCopied ? 'Copied' : 'Copy',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isCopied ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // WhatsApp Invite
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _sendViaWhatsApp(companyName),
                        icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                        label: Text(
                          'WhatsApp',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
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

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    bool isBold = false,
    Color? customColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: customColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF0F766E).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF0F766E)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F766E),
            ),
          ),
        ],
      ),
    );
  }
}
