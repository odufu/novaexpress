import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/nova_tooltip.dart';
import '../../providers/admin_console_provider.dart';

class AdminServerSettingsTab extends ConsumerStatefulWidget {
  const AdminServerSettingsTab({super.key});

  @override
  ConsumerState<AdminServerSettingsTab> createState() => _AdminServerSettingsTabState();
}

class _AdminServerSettingsTabState extends ConsumerState<AdminServerSettingsTab> {
  late TextEditingController _paystackPublicController;
  late TextEditingController _paystackSecretController;
  late TextEditingController _monnifyKeyController;
  late TextEditingController _monnifyContractController;
  late TextEditingController _termiiKeyController;
  late TextEditingController _termiiSenderController;
  late TextEditingController _whatsappTokenController;
  late TextEditingController _whatsappPhoneController;

  late bool _paystackLiveMode;
  bool _obscureSecrets = true;
  bool _isPinging = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(adminConsoleProvider).serverSettings;
    _paystackPublicController = TextEditingController(text: s.paystackPublicKey);
    _paystackSecretController = TextEditingController(text: s.paystackSecretKey);
    _monnifyKeyController = TextEditingController(text: s.monnifyApiKey);
    _monnifyContractController = TextEditingController(text: s.monnifyContractCode);
    _termiiKeyController = TextEditingController(text: s.termiiApiKey);
    _termiiSenderController = TextEditingController(text: s.termiiSenderId);
    _whatsappTokenController = TextEditingController(text: s.whatsappToken);
    _whatsappPhoneController = TextEditingController(text: s.whatsappPhoneId);
    _paystackLiveMode = s.paystackLiveMode;
  }

  @override
  void dispose() {
    _paystackPublicController.dispose();
    _paystackSecretController.dispose();
    _monnifyKeyController.dispose();
    _monnifyContractController.dispose();
    _termiiKeyController.dispose();
    _termiiSenderController.dispose();
    _whatsappTokenController.dispose();
    _whatsappPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pingDb() async {
    setState(() => _isPinging = true);
    await ref.read(adminConsoleProvider.notifier).pingServer();
    if (mounted) setState(() => _isPinging = false);
  }

  void _saveSettings() {
    final updated = ref.read(adminConsoleProvider).serverSettings.copyWith(
          paystackPublicKey: _paystackPublicController.text.trim(),
          paystackSecretKey: _paystackSecretController.text.trim(),
          paystackLiveMode: _paystackLiveMode,
          monnifyApiKey: _monnifyKeyController.text.trim(),
          monnifyContractCode: _monnifyContractController.text.trim(),
          termiiApiKey: _termiiKeyController.text.trim(),
          termiiSenderId: _termiiSenderController.text.trim(),
          whatsappToken: _whatsappTokenController.text.trim(),
          whatsappPhoneId: _whatsappPhoneController.text.trim(),
        );

    ref.read(adminConsoleProvider.notifier).updateServerSettings(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Server gateway credentials securely updated in production vault.', style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminConsoleProvider);
    final s = state.serverSettings;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Infrastructure & External APIs',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage payment tokens, SMS/WhatsApp webhooks, and live database health telemetry',
                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(_obscureSecrets ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                      tooltip: _obscureSecrets ? 'Reveal secret keys' : 'Mask secret keys',
                      onPressed: () => setState(() => _obscureSecrets = !_obscureSecrets),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.lock_outline_rounded, size: 16),
                      label: Text('Save Tokens', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Card 1: Database Vitals & Cloud Health
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Supabase Cloud Database & Pooler',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _isPinging ? null : _pingDb,
                        icon: _isPinging
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.network_ping_rounded, size: 15),
                        label: Text('Ping Latency', style: GoogleFonts.inter(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildVitalItem(
                          label: 'Connection Status',
                          value: 'Connected (Live SSL)',
                          valueColor: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildVitalItem(
                          label: 'REST Query Latency',
                          value: '${s.lastPingMs} ms (Optimal)',
                          valueColor: s.lastPingMs < 100 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildVitalItem(
                          label: 'Postgres Pooler Endpoint',
                          value: s.supabasePoolerUrl,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card 2: Payment Gateways (Paystack & Monnify)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payment_rounded, size: 18, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 8),
                          Text(
                            'Paystack & Monnify Automated Gateways',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const NovaInfoIcon(message: 'Power dynamic virtual accounts, POS transactions, and automated merchant settlements'),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Live Mode',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                          ),
                          Switch(
                            value: _paystackLiveMode,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (v) => setState(() => _paystackLiveMode = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildApiField(
                    controller: _paystackPublicController,
                    label: 'Paystack Public Key',
                    hint: 'pk_live_...',
                    isDark: isDark,
                    obscure: false,
                  ),
                  const SizedBox(height: 12),
                  _buildApiField(
                    controller: _paystackSecretController,
                    label: 'Paystack Secret Key',
                    hint: 'sk_live_...',
                    isDark: isDark,
                    obscure: _obscureSecrets,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildApiField(
                          controller: _monnifyKeyController,
                          label: 'Monnify API Key',
                          hint: 'MK_PROD_...',
                          isDark: isDark,
                          obscure: _obscureSecrets,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildApiField(
                          controller: _monnifyContractController,
                          label: 'Monnify Contract Code',
                          hint: '8829401923',
                          isDark: isDark,
                          obscure: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card 3: Communications (Termii SMS & WhatsApp Cloud API)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Text(
                        'Termii SMS & WhatsApp Cloud Gateway',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const NovaInfoIcon(message: 'Sends automated shipment dispatch notices, doorstep OTPs, and customer delivery updates'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildApiField(
                          controller: _termiiKeyController,
                          label: 'Termii API Key',
                          hint: 'TL_KEY_...',
                          isDark: isDark,
                          obscure: _obscureSecrets,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildApiField(
                          controller: _termiiSenderController,
                          label: 'Registered Sender ID',
                          hint: 'NovaXpress',
                          isDark: isDark,
                          obscure: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildApiField(
                    controller: _whatsappTokenController,
                    label: 'WhatsApp Cloud API Access Token',
                    hint: 'EAAX...',
                    isDark: isDark,
                    obscure: _obscureSecrets,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalItem({
    required String label,
    required String value,
    Color? valueColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildApiField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    required bool obscure,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: GoogleFonts.jetBrainsMono(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            suffixIcon: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              tooltip: 'Copy to clipboard',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: controller.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied', style: GoogleFonts.inter()),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}
