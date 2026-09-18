import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../domain/entities/client_closer.dart';
import '../providers/client_portal_provider.dart';

class ClientCloserCredentialsModal extends ConsumerStatefulWidget {
  final ClientCloser closer;
  final String? initialPassword;
  final String? clientName;

  const ClientCloserCredentialsModal({
    super.key,
    required this.closer,
    this.initialPassword,
    this.clientName,
  });

  static Future<void> show(
    BuildContext context, {
    required ClientCloser closer,
    String? initialPassword,
    String? clientName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ClientCloserCredentialsModal(
        closer: closer,
        initialPassword: initialPassword,
        clientName: clientName,
      ),
    );
  }

  @override
  ConsumerState<ClientCloserCredentialsModal> createState() => _ClientCloserCredentialsModalState();
}

class _ClientCloserCredentialsModalState extends ConsumerState<ClientCloserCredentialsModal> {
  late TextEditingController _passwordController;
  bool _obscurePassword = false;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController(
      text: widget.initialPassword ?? 'Closer123!',
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
    return '''🎉 *Welcome to the $companyName Telesales Team!*

Hello ${widget.closer.fullName}, your Closer Workspace account has been created on NoveXPS.

Here are your official login credentials:
🌐 *Portal URL:* https://novexps.web.app
👤 *Name:* ${widget.closer.fullName}
🆔 *Closer Code:* ${widget.closer.closerCode}
📧 *Login Email:* ${widget.closer.email}
🔒 *Password:* $password

📲 Please log into the portal to review your assigned customer leads, place live dispatch orders, and track your closed delivery commissions.

Best regards,
$companyName Management''';
  }

  Future<void> _sendViaWhatsApp(String companyName) async {
    final phone = _formatPhoneNumber(widget.closer.phone);
    final message = _buildInviteMessage(companyName);
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$phone?text=$encoded');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await _copyInviteToClipboard(companyName);
      }
    } catch (_) {
      await _copyInviteToClipboard(companyName);
    }
  }

  Future<void> _sendViaSms(String companyName) async {
    final rawPhone = widget.closer.phone.trim();
    final message = _buildInviteMessage(companyName);
    final uri = Uri(
      scheme: 'sms',
      path: rawPhone,
      queryParameters: {'body': message},
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await _copyInviteToClipboard(companyName);
      }
    } catch (_) {
      await _copyInviteToClipboard(companyName);
    }
  }

  Future<void> _copyInviteToClipboard(String companyName) async {
    final message = _buildInviteMessage(companyName);
    await Clipboard.setData(ClipboardData(text: message));
    if (mounted) {
      setState(() => _isCopied = true);
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
                  'Login credentials copied! Ready to paste into WhatsApp, SMS, or Email.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isCopied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);
    final state = ref.watch(clientPortalProvider);
    final companyName = widget.clientName ??
        (state.clientProfile.name.isNotEmpty
            ? state.clientProfile.name
            : 'Novacare');
    final isCompact = MediaQuery.of(context).size.width < 520;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF151D36) : Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 18 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.send_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send Closer Credentials',
                            style: GoogleFonts.inter(
                              fontSize: isCompact ? 16 : 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Deliver portal login details directly to closer',
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
              const SizedBox(height: 18),

              // Closer Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B1021) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFF37021).withValues(alpha: 0.15),
                          backgroundImage: (widget.closer.avatarUrl != null && widget.closer.avatarUrl!.isNotEmpty)
                              ? NetworkImage(widget.closer.avatarUrl!)
                              : null,
                          child: (widget.closer.avatarUrl == null || widget.closer.avatarUrl!.isEmpty)
                              ? Text(
                                  widget.closer.fullName.isNotEmpty
                                      ? widget.closer.fullName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join()
                                      : 'CL',
                                  style: GoogleFonts.inter(color: const Color(0xFFF37021), fontWeight: FontWeight.w800, fontSize: 13),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.closer.fullName,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF37021).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.closer.closerCode,
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFF37021)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Telesales Closer • $companyName',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Credentials Detail Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151D36) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  children: [
                    _buildCredentialRow(
                      context: context,
                      label: 'Portal URL',
                      value: 'https://novexps.web.app',
                      icon: Icons.language_rounded,
                      isDark: isDark,
                      onCopy: () {
                        Clipboard.setData(const ClipboardData(text: 'https://novexps.web.app'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Portal link copied to clipboard!')),
                        );
                      },
                    ),
                    Divider(height: 16, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9)),
                    _buildCredentialRow(
                      context: context,
                      label: 'Login Email',
                      value: widget.closer.email,
                      icon: Icons.alternate_email_rounded,
                      isDark: isDark,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: widget.closer.email));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email copied to clipboard!')),
                        );
                      },
                    ),
                    Divider(height: 16, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9)),
                    _buildCredentialRow(
                      context: context,
                      label: 'Phone (WhatsApp)',
                      value: widget.closer.phone,
                      icon: Icons.phone_rounded,
                      isDark: isDark,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: widget.closer.phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Phone number copied!')),
                        );
                      },
                    ),
                    Divider(height: 16, color: isDark ? const Color(0xFF2E3D6B) : const Color(0xFFF1F5F9)),

                    // Password Row with Show/Hide & Edit
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF37021).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFF37021)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _obscurePassword ? '••••••••••' : _passwordController.text,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFFF37021)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _passwordController.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password copied to clipboard!')),
                            );
                          },
                          tooltip: 'Copy password',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons (WhatsApp, SMS, Copy All)
              Text(
                'DIRECT SEND CHANNELS',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFF37021), letterSpacing: 0.5),
              ),
              const SizedBox(height: 10),

              // WhatsApp Primary Action
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => _sendViaWhatsApp(companyName),
                  icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
                  label: Text(
                    'Send via WhatsApp (${widget.closer.phone})',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // SMS and Copy All Row
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () => _sendViaSms(companyName),
                        icon: const Icon(Icons.sms_outlined, size: 16, color: Color(0xFF2563EB)),
                        label: Text(
                          'Send via SMS',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () => _copyInviteToClipboard(companyName),
                        icon: Icon(
                          _isCopied ? Icons.check_circle_rounded : Icons.copy_all_rounded,
                          size: 16,
                          color: _isCopied ? const Color(0xFF10B981) : const Color(0xFFF37021),
                        ),
                        label: Text(
                          _isCopied ? 'Copied!' : 'Copy Full Invite',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isCopied ? const Color(0xFF10B981) : const Color(0xFFF37021),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _isCopied ? const Color(0xFF10B981) : const Color(0xFFFDBA74),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Done Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialRow({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    required VoidCallback onCopy,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF64748B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
          onPressed: onCopy,
          tooltip: 'Copy $label',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
